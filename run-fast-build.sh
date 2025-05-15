#!/usr/bin/env bash
# Helper script to run nix-fast-build with proper configuration

# Determine current system
SYSTEM=$(nix eval --raw --impure --expr builtins.currentSystem)
echo "🚀 Building for system: $SYSTEM"

# Default settings
SKIP_CACHED="--skip-cached"
RESULT_FORMAT="junit"
RESULT_FILE="result.xml"
FLAKE_PATH=".#checks.$SYSTEM"
NO_NOM=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all-systems)
      SYSTEM="all"
      shift
      ;;
    --no-skip-cached)
      SKIP_CACHED=""
      shift
      ;;
    --flake)
      FLAKE_PATH="$2"
      shift 2
      ;;
    --json)
      RESULT_FORMAT="json"
      RESULT_FILE="result.json"
      shift
      ;;
    --no-result)
      RESULT_FORMAT=""
      RESULT_FILE=""
      shift
      ;;
    --ci)
      NO_NOM="--no-nom"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --all-systems       Build for all systems, not just current"
      echo "  --no-skip-cached    Don't skip cached builds"
      echo "  --flake PATH        Specify a custom flake path (default: .#checks.\$SYSTEM)"
      echo "  --json              Output results in JSON format instead of JUnit"
      echo "  --no-result         Don't output a result file"
      echo "  --ci                Use CI-friendly output (no nix output monitor)"
      echo "  --help              Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Build the command
CMD="nix run github:Mic92/nix-fast-build --"

# Add options
if [[ -n "$SKIP_CACHED" ]]; then
  CMD="$CMD $SKIP_CACHED"
fi

if [[ "$SYSTEM" != "all" ]]; then
  CMD="$CMD --systems \"$SYSTEM\""
fi

if [[ -n "$RESULT_FORMAT" && -n "$RESULT_FILE" ]]; then
  CMD="$CMD --result-format $RESULT_FORMAT --result-file $RESULT_FILE"
fi

if [[ -n "$NO_NOM" ]]; then
  CMD="$CMD $NO_NOM"
fi

# Add flake path
CMD="$CMD --flake \"$FLAKE_PATH\""

# Print and execute
echo "Executing: $CMD"
echo "=============================================="
eval $CMD

# Check exit status
EXIT_STATUS=$?
if [ $EXIT_STATUS -eq 0 ]; then
  echo "✅ Build completed successfully"
  
  # Show results summary if available
  if [[ "$RESULT_FORMAT" == "junit" && -f "$RESULT_FILE" ]]; then
    echo "=============================================="
    echo "📊 Test Results Summary:"
    grep -o 'tests="[0-9]*" errors="[0-9]*" failures="[0-9]*" skipped="[0-9]*"' "$RESULT_FILE" | \
      sed 's/tests="\([0-9]*\)" errors="\([0-9]*\)" failures="\([0-9]*\)" skipped="\([0-9]*\)"/Total: \1, Errors: \2, Failures: \3, Skipped: \4/'
  elif [[ "$RESULT_FORMAT" == "json" && -f "$RESULT_FILE" ]]; then
    echo "=============================================="
    echo "📊 Results written to $RESULT_FILE"
    echo "Run 'jq . $RESULT_FILE' to examine the results"
  fi
else
  echo "❌ Build failed with status $EXIT_STATUS"
fi

exit $EXIT_STATUS