#!/bin/bash

# Set your MCP token
export MCPR_TOKEN="mcpr_y3uOMhJ90dxOElA27o23a5BKb_W5-jxC"

# Run the MCP connection with verbose output
echo "Starting MCP connection test..."
npx -y mcpr-cli@latest connect --debug

# Capture the exit code
EXIT_CODE=$?
echo "MCP connection test exited with code: $EXIT_CODE"