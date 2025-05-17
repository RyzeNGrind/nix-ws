# modules/ai-inference.nix
# Intelligent AI Inference Cost Optimization
# Implements API routing between Venice VCU and OpenRouter
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ai-inference;

  # Helper for creating directory structure
  mkAiDirs = dirs: concatStringsSep "\n" (map (dir: "mkdir -p ${dir}") dirs);
  
  # Python package for the router
  veniceRouterPkg = pkgs.python3Packages.buildPythonPackage {
    pname = "venice-router";
    version = "0.2.0";
    src = pkgs.writeTextDir "venice_router/__init__.py" ''
      """Venice Router: Intelligent API cost optimization between Venice VCU and OpenRouter."""
      __version__ = "0.2.0"
    '';
    propagatedBuildInputs = with pkgs.python3Packages; [
      requests
      python-dotenv
      fastapi
      uvicorn
      numpy
      pydantic
      tiktoken  # OpenAI-compatible tokenizer
      prometheus-client
      colorlog
    ];
    doCheck = false;
  };

  # Create the router service
  routerScript = pkgs.writeText "venice_router.py" ''
    #!/usr/bin/env python3
    """
    Venice Router: Intelligent API router that optimizes between Venice VCU and OpenRouter.
    
    This service routes requests based on complexity, token count, and credit availability
    to maximize the use of free VCU compute while falling back to OpenRouter for
    mission-critical or complex AI inference tasks.
    """
    import os
    import json
    import time
    import logging
    import numpy as np
    import tiktoken
    import requests
    import threading
    import asyncio
    import colorlog
    from pydantic import BaseModel, Field
    from typing import Dict, List, Optional, Any, Union
    from fastapi import FastAPI, HTTPException, Request, Response, status
    from fastapi.responses import JSONResponse
    from prometheus_client import Counter, Gauge, Histogram, generate_latest
    from datetime import datetime, timezone
    from dotenv import load_dotenv

    # Load environment variables
    load_dotenv()

    # Configure logging
    handler = colorlog.StreamHandler()
    handler.setFormatter(colorlog.ColoredFormatter(
        '%(log_color)s%(asctime)s [%(levelname)s] %(message)s',
        log_colors={
            'DEBUG': 'cyan',
            'INFO': 'green',
            'WARNING': 'yellow',
            'ERROR': 'red',
            'CRITICAL': 'red,bg_white',
        }
    ))
    
    logger = colorlog.getLogger('venice-router')
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

    # Configuration
    VENICE_API_KEY = os.environ.get("VENICE_API_KEY", "")
    OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
    VENICE_ENDPOINT = os.environ.get("VENICE_API_ENDPOINT", "https://api.venice.ai/v1")
    OPENROUTER_ENDPOINT = os.environ.get("OPENROUTER_API_ENDPOINT", "https://openrouter.ai/api/v1")
    
    # Target ratio (97.3% Venice, 2.7% OpenRouter)
    TARGET_RATIO = float(os.environ.get("TARGET_RATIO", 97.3))
    
    # Router port
    ROUTER_PORT = int(os.environ.get("ROUTER_PORT", 8765))
    
    # Constants for complexity calculation
    MAX_COMPLEXITY = 100
    COMPLEXITY_THRESHOLD = int(os.environ.get("COMPLEXITY_THRESHOLD", 25))

    # Token counters and metrics
    total_venice_tokens = Gauge('venice_total_tokens', 'Total tokens processed by Venice')
    total_openrouter_tokens = Gauge('openrouter_total_tokens', 'Total tokens processed by OpenRouter')
    
    request_latency = Histogram(
        'request_latency_seconds', 
        'Request latency in seconds',
        ['endpoint', 'model']
    )
    
    model_usage = Counter(
        'model_usage_total', 
        'Number of times each model was used',
        ['model', 'provider']
    )
    
    inference_failures = Counter(
        'inference_failures_total',
        'Number of inference failures',
        ['model', 'provider', 'error_type']
    )

    # Stateful counters for credit balancing
    class CreditState:
        def __init__(self):
            self.venice_tokens = 0
            self.openrouter_tokens = 0
            self.last_update = time.time()
            self.lock = threading.Lock()
            
        def add_venice_tokens(self, tokens):
            with self.lock:
                self.venice_tokens += tokens
                total_venice_tokens.set(self.venice_tokens)
                
        def add_openrouter_tokens(self, tokens):
            with self.lock:
                self.openrouter_tokens += tokens
                total_openrouter_tokens.set(self.openrouter_tokens)
                
        def get_current_ratio(self):
            with self.lock:
                if self.openrouter_tokens == 0:
                    return 100.0
                return (self.venice_tokens / (self.venice_tokens + self.openrouter_tokens * 100)) * 100
                
        def should_use_venice(self, complexity, token_count):
            with self.lock:
                # Always use Venice for simple queries if within token limit
                if complexity < COMPLEXITY_THRESHOLD and token_count < 8192:
                    return True
                    
                # Check if we're meeting our target ratio
                current_ratio = self.get_current_ratio()
                
                # Apply leaky bucket algorithm (tokens expire over time)
                current_time = time.time()
                time_diff = current_time - self.last_update
                
                # Tokens expire at 5% per hour
                if time_diff > 60:  # Only apply decay after a minute
                    decay_factor = 1.0 - (time_diff / 3600 * 0.05)
                    self.venice_tokens *= max(0, decay_factor)
                    self.openrouter_tokens *= max(0, decay_factor)
                    self.last_update = current_time
                    
                logger.debug(f"Current ratio: {current_ratio:.2f}% (target: {TARGET_RATIO:.2f}%)")
                
                # If we're significantly under our target ratio, prefer Venice
                if current_ratio < TARGET_RATIO - 5:
                    return complexity < COMPLEXITY_THRESHOLD * 1.5
                    
                # Otherwise use the standard complexity threshold
                return complexity < COMPLEXITY_THRESHOLD
                
    # Global state
    state = CreditState()
    
    # Initialize tokenizer
    tokenizer = tiktoken.get_encoding("cl100k_base")
    
    def count_tokens(text):
        """Count tokens in text using tiktoken."""
        return len(tokenizer.encode(text))
        
    def calculate_complexity(prompt):
        """
        Calculate complexity score for a prompt.
        
        Uses a combination of:
        1. Token count
        2. Special tokens density (code blocks, math, etc.)
        3. Syntax depth (nested code, JSON, etc.)
        4. Amount of context required
        
        Returns a score 0-100 where higher means more complex.
        """
        score = 0
        
        # Base complexity from token length
        tokens = count_tokens(prompt)
        score += min(25, tokens / 400)
        
        # Code detection (markdown code blocks, brackets, braces)
        code_markers = prompt.count("```")
        bracket_ratio = (prompt.count("{") + prompt.count("[")) / max(1, len(prompt)) * 1000
        score += min(25, code_markers * 2.5 + bracket_ratio * 5)
        
        # Specific terms that indicate complex requirements
        complex_terms = [
            "recursive", "recursion", "algorithm", "optimization",
            "mathematics", "proof", "theorem", "Nix", "flake", "derivation",
            "nixpkgs", "module", "configuration", "systemd", "debug", "trace"
        ]
        
        complex_terms_count = sum(prompt.lower().count(term.lower()) for term in complex_terms)
        score += min(20, complex_terms_count * 2)
        
        # Context density (number of concepts/entities)
        words = prompt.split()
        unique_words = set(w.lower() for w in words if len(w) > 4)
        context_density = len(unique_words) / max(1, len(words)) * 100
        score += min(15, context_density / 2)
        
        # Query clarity/ambiguity
        question_marks = prompt.count("?")
        directives = sum(1 for w in words if w.lower() in ["explain", "how", "why", "what", "when", "describe"])
        clarity_score = min(15, question_marks * 2 + directives)
        score += clarity_score
        
        # Cap at 100
        return min(100, score)

    # Initialize FastAPI app
    app = FastAPI(title="Venice Router", description="Intelligent cost-optimized AI inference router")

    # Completion request model
    class CompletionRequest(BaseModel):
        model: str
        prompt: str
        temperature: Optional[float] = 0.7
        max_tokens: Optional[int] = 1024
        stop: Optional[Union[str, List[str]]] = None
        stream: Optional[bool] = False
        
    # Helper functions for API calls
    async def call_venice_api(request_data):
        """Call Venice API with the given request data."""
        start_time = time.time()
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {VENICE_API_KEY}"
        }
        
        # Map to appropriate model (Venice naming may differ)
        model = request_data["model"]
        venice_models = {
            "gpt-3.5-turbo": "qwen-3-4b",
            "gpt-4": "llama-3-3-70b",
            "claude-3-5-sonnet": "qwen-3-32b",
            "claude-3-7-sonnet": "llama-3-3-70b",
        }
        
        # Use mapped model or default to original if not found
        venice_model = venice_models.get(model, model)
        request_data["model"] = venice_model
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{VENICE_ENDPOINT}/completions",
                    headers=headers,
                    json=request_data,
                    timeout=30.0
                ) as response:
                    elapsed = time.time() - start_time
                    request_latency.labels(endpoint="venice", model=venice_model).observe(elapsed)
                    
                    if response.status == 200:
                        result = await response.json()
                        model_usage.labels(model=venice_model, provider="venice").inc()
                        
                        # Estimate tokens (Venice might not report them directly)
                        prompt_tokens = count_tokens(request_data["prompt"]) 
                        completion_tokens = count_tokens(result.get("choices", [{}])[0].get("text", ""))
                        total_tokens = prompt_tokens + completion_tokens
                        
                        # Record token usage
                        state.add_venice_tokens(total_tokens)
                        
                        return result
                    else:
                        error_text = await response.text()
                        logger.error(f"Venice API error ({response.status}): {error_text}")
                        inference_failures.labels(
                            model=venice_model,
                            provider="venice",
                            error_type=f"http_{response.status}"
                        ).inc()
                        raise HTTPException(status_code=response.status, detail=error_text)
        except Exception as e:
            logger.error(f"Venice API exception: {str(e)}")
            inference_failures.labels(
                model=venice_model,
                provider="venice",
                error_type="connection_error"
            ).inc()
            raise HTTPException(status_code=500, detail=f"Venice API error: {str(e)}")

    async def call_openrouter_api(request_data):
        """Call OpenRouter API with the given request data."""
        start_time = time.time()
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "HTTP-Referer": "https://ryzengrind.xyz"  # Your site for OpenRouter tracking
        }
        
        # Ensure correct model format for OpenRouter
        model = request_data["model"]
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{OPENROUTER_ENDPOINT}/completions",
                    headers=headers,
                    json=request_data,
                    timeout=60.0
                ) as response:
                    elapsed = time.time() - start_time
                    request_latency.labels(endpoint="openrouter", model=model).observe(elapsed)
                    
                    if response.status == 200:
                        result = await response.json()
                        model_usage.labels(model=model, provider="openrouter").inc()
                        
                        # Get token usage from OpenRouter response
                        usage = result.get("usage", {})
                        total_tokens = usage.get("total_tokens", 0)
                        
                        # Record token usage (weighted by cost factor)
                        state.add_openrouter_tokens(total_tokens)
                        
                        return result
                    else:
                        error_text = await response.text()
                        logger.error(f"OpenRouter API error ({response.status}): {error_text}")
                        inference_failures.labels(
                            model=model,
                            provider="openrouter",
                            error_type=f"http_{response.status}"
                        ).inc()
                        raise HTTPException(status_code=response.status, detail=error_text)
        except Exception as e:
            logger.error(f"OpenRouter API exception: {str(e)}")
            inference_failures.labels(
                model=model,
                provider="openrouter",
                error_type="connection_error"
            ).inc()
            raise HTTPException(status_code=500, detail=f"OpenRouter API error: {str(e)}")

    # API Routes
    @app.post("/v1/completions")
    async def route_completion(request: CompletionRequest):
        """Route completion requests based on complexity and credit availability."""
        prompt = request.prompt
        complexity = calculate_complexity(prompt)
        token_count = count_tokens(prompt) + request.max_tokens
        
        logger.info(f"Routing request: complexity={complexity:.1f}, tokens={token_count}, model={request.model}")
        
        # Route based on complexity, token count, and credit state
        use_venice = state.should_use_venice(complexity, token_count)
        
        if use_venice:
            logger.info(f"Using Venice AI (complexity: {complexity:.1f})")
            result = await call_venice_api(request.dict())
            return result
        else:
            logger.info(f"Using OpenRouter (complexity: {complexity:.1f})")
            result = await call_openrouter_api(request.dict())
            return result
            
    @app.get("/metrics")
    async def get_metrics():
        """Expose Prometheus metrics."""
        return Response(content=generate_latest(), media_type="text/plain")
        
    @app.get("/status")
    async def get_status():
        """Get router status and statistics."""
        current_ratio = state.get_current_ratio()
        return {
            "status": "healthy",
            "version": "0.2.0",
            "stats": {
                "venice_tokens": state.venice_tokens,
                "openrouter_tokens": state.openrouter_tokens,
                "current_ratio": current_ratio,
                "target_ratio": TARGET_RATIO,
                "last_update": datetime.fromtimestamp(state.last_update, tz=timezone.utc).isoformat()
            }
        }

    if __name__ == "__main__":
        import uvicorn
        logger.info(f"Starting Venice Router on port {ROUTER_PORT}")
        uvicorn.run(app, host="0.0.0.0", port=ROUTER_PORT)
  '';
  
  # Script to initialize the router service
  setupScript = pkgs.writeScriptBin "setup-ai-inference" ''
    #!/bin/sh
    set -e
    
    # Create required directories
    ${mkAiDirs [
      "/var/lib/ai-inference"
      "/var/lib/ai-inference/cache"
      "/var/log/ai-inference"
    ]}
    
    # Set up environment file
    if [ ! -f "/var/lib/ai-inference/.env" ]; then
      cat > /var/lib/ai-inference/.env << EOF
    # Venice API configuration
    VENICE_API_KEY=${cfg.veniceApiKey}
    VENICE_API_ENDPOINT=${cfg.veniceApiEndpoint}
    
    # OpenRouter configuration
    OPENROUTER_API_KEY=${cfg.openRouterApiKey}
    OPENROUTER_API_ENDPOINT=${cfg.openRouterApiEndpoint}
    
    # Router configuration
    TARGET_RATIO=${toString cfg.targetRatio}
    ROUTER_PORT=${toString cfg.port}
    COMPLEXITY_THRESHOLD=${toString cfg.complexityThreshold}
    EOF
    fi
    
    # Set permissions
    chmod 600 /var/lib/ai-inference/.env
    chown -R ${cfg.user}:${cfg.group} /var/lib/ai-inference
    chown -R ${cfg.user}:${cfg.group} /var/log/ai-inference
    
    echo "AI Inference service setup complete."
  '';
  
  # Python client package
  pyClient = pkgs.python3Packages.buildPythonPackage {
    pname = "venice-router-client";
    version = "0.1.0";
    src = pkgs.writeTextDir "setup.py" ''
      from setuptools import setup
      
      setup(
          name="venice-router-client",
          version="0.1.0",
          py_modules=["venice_client"],
          install_requires=["requests"],
      )
    '';
    
    # Add the client module
    postBuild = ''
      cat > $out/lib/python${pkgs.python3.pythonVersion}/site-packages/venice_client.py << EOF
      """Venice Router client library for easy integration."""
      import os
      import json
      import requests
      
      class VeniceClient:
          def __init__(self, api_key=None, base_url="http://localhost:${toString cfg.port}"):
              self.api_key = api_key or os.environ.get("VENICE_ROUTER_API_KEY")
              self.base_url = base_url
              
          def completion(self, prompt, model="qwen-3-4b", max_tokens=1024, temperature=0.7):
              """Send a completion request to the Venice Router."""
              headers = {}
              if self.api_key:
                  headers["Authorization"] = f"Bearer {self.api_key}"
                  
              response = requests.post(
                  f"{self.base_url}/v1/completions",
                  headers=headers,
                  json={
                      "model": model,
                      "prompt": prompt,
                      "max_tokens": max_tokens,
                      "temperature": temperature
                  }
              )
              
              if response.status_code == 200:
                  return response.json()
              else:
                  response.raise_for_status()
                  
          def status(self):
              """Get the status of the Venice Router."""
              response = requests.get(f"{self.base_url}/status")
              if response.status_code == 200:
                  return response.json()
              else:
                  response.raise_for_status()
      EOF
    '';
    
    doCheck = false;
  };
in {
  options.services.ai-inference = {
    enable = mkEnableOption "Enable AI inference cost optimization service";
    
    veniceApiKey = mkOption {
      type = types.str;
      default = "";
      description = "API key for Venice AI";
    };
    
    veniceApiEndpoint = mkOption {
      type = types.str;
      default = "https://api.venice.ai/v1";
      description = "Venice AI API endpoint";
    };
    
    openRouterApiKey = mkOption {
      type = types.str;
      default = "";
      description = "API key for OpenRouter";
    };
    
    openRouterApiEndpoint = mkOption {
      type = types.str;
      default = "https://openrouter.ai/api/v1";
      description = "OpenRouter API endpoint";
    };
    
    targetRatio = mkOption {
      type = types.float;
      default = 97.3;
      description = "Target usage ratio for Venice (97.3 means 97.3% Venice, 2.7% OpenRouter)";
    };
    
    complexityThreshold = mkOption {
      type = types.int;
      default = 25;
      description = "Complexity threshold (0-100) for routing to Venice vs OpenRouter";
    };
    
    port = mkOption {
      type = types.int;
      default = 8765;
      description = "Port for the AI inference router service";
    };
    
    user = mkOption {
      type = types.str;
      default = "ai-inference";
      description = "User to run the AI inference service";
    };
    
    group = mkOption {
      type = types.str;
      default = "ai-inference";
      description = "Group to run the AI inference service";
    };
    
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall for the AI inference router port";
    };
    
    prometheus = {
      enable = mkEnableOption "Enable Prometheus metrics for AI inference";
      port = mkOption {
        type = types.int;
        default = 9090;
        description = "Port for Prometheus metrics scraping";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "AI inference service user";
      home = "/var/lib/ai-inference";
      createHome = true;
    };
    
    users.groups.${cfg.group} = {};
    
    # Install packages
    environment.systemPackages = [
      setupScript
      pyClient
      pkgs.python3
    ];
    
    # Configure and start the service
    systemd.services.ai-inference = {
      description = "AI Inference Router Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/ai-inference";
        ExecStart = "${pkgs.python3}/bin/python3 ${routerScript}";
        Restart = "always";
        RestartSec = "10s";
        
        # Security hardening
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/ai-inference" "/var/log/ai-inference" ];
      };
      
      preStart = ''
        ${setupScript}/bin/setup-ai-inference
      '';
      
      environment = {
        PYTHONPATH = "${veniceRouterPkg}/lib/python${pkgs.python3.pythonVersion}/site-packages";
        DOTENV_PATH = "/var/lib/ai-inference/.env";
      };
    };
    
    # Open firewall if requested
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
    
    # Prometheus configuration if enabled
    services.prometheus = mkIf cfg.prometheus.enable {
      scrapeConfigs = [{
        job_name = "ai-inference";
        static_configs = [{
          targets = [ "localhost:${toString cfg.port}" ];
        }];
      }];
    };
    
    # Documentation
    environment.etc."ai-inference/README.md" = {
      text = ''
        # AI Inference Cost Optimization Service
        
        This service provides intelligent routing between Venice AI and OpenRouter APIs
        to optimize cost while maintaining quality. The system automatically routes requests
        based on:
        
        1. Query complexity (syntax depth, token count, special requirements)
        2. Credit availability and usage ratio
        3. Model capabilities
        
        ## Usage
        
        ### Python Client
        
        The system provides a Python client for easy integration:
        
        ```python
        from venice_client import VeniceClient
        
        client = VeniceClient()
        response = client.completion(
            prompt="Explain how to optimize a Nix flake",
            model="qwen-3-4b",
            max_tokens=512
        )
        print(response["choices"][0]["text"])
        ```
        
        ### Direct API
        
        You can also access the API directly at http://localhost:${toString cfg.port}:
        
        ```bash
        curl -X POST http://localhost:${toString cfg.port}/v1/completions \
          -H "Content-Type: application/json" \
          -d '{"model": "qwen-3-4b", "prompt": "Explain Nix flakes", "max_tokens": 512}'
        ```
        
        ### Status and Metrics
        
        - Status information: http://localhost:${toString cfg.port}/status
        - Prometheus metrics: http://localhost:${toString cfg.port}/metrics
        
        ## Configuration
        
        Edit /var/lib/ai-inference/.env to adjust:
        
        - API keys
        - Endpoints
        - Target usage ratio
        - Complexity thresholds
        
        ## Restart Service
        
        ```bash
        sudo systemctl restart ai-inference
        ```
      '';
      mode = "0444";
    };
  };
}