#!/usr/bin/env bash

# VM Tests Parallel Runner
# Runs specific VM tests in parallel with configurable timeouts
# Usage: ./scripts/run-tests-parallel.sh [category1 category2 ...]

set -euo pipefail

# Project root directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Default timeout (seconds)
DEFAULT_TIMEOUT=120

# Default concurrency
MAX_CONCURRENT=2

# Test categories with their specific timeouts
declare -A TEST_CATEGORIES=(
  ["core"]="60"        # Core system functionality tests
  ["network"]="120"    # Network-related tests
  ["gui"]="180"        # GUI/Desktop tests
  ["integration"]="240" # End-to-end integration tests
  ["min"]="60"          # Minimal system tests
  ["e2e"]="240"         # End-to-end tests
)

# Parse arguments
SELECTED_CATEGORIES=()
if [ $# -eq 0 ]; then
  # If no arguments, run all categories
  for category in "${!TEST_CATEGORIES[@]}"; do
    SELECTED_CATEGORIES+=("$category")
  done
else
  # Otherwise, run only selected categories
  for category in "$@"; do
    if [[ -v "TEST_CATEGORIES[$category]" ]]; then
      SELECTED_CATEGORIES+=("$category")
    else
      echo "Warning: Unknown test category '$category', skipping" >&2
    fi
  done
fi

# Print test plan
echo "Test Plan:"
echo "  Project root: $PROJECT_ROOT"
echo "  Max concurrent tests: $MAX_CONCURRENT"

for category in "${SELECTED_CATEGORIES[@]}"; do
  echo "  • nix-ws-$category (timeout: ${TEST_CATEGORIES[$category]}s)"
done
echo

# Function to run a single test with timeout
run_test() {
  local category=$1
  local timeout=${TEST_CATEGORIES[$category]}
  local log_file="$PROJECT_ROOT/test-$category.log"
  
  echo "[$(date +%H:%M:%S)] Starting test: nix-ws-$category (timeout: ${timeout}s)"
  
  # Run the test with timeout, capturing output to log file
  if "$PROJECT_ROOT/scripts/run-single-test.sh" "$category" "$timeout" > "$log_file" 2>&1; then
    echo "[$(date +%H:%M:%S)] ✅ Test nix-ws-$category completed successfully"
    return 0
  else
    local exit_code=$?
    echo "[$(date +%H:%M:%S)] ❌ Test nix-ws-$category failed with exit code $exit_code"
    echo "Last 10 lines of log:"
    tail -n 10 "$log_file"
    echo "See $log_file for full logs"
    return $exit_code
  fi
}

# Run tests in parallel with limited concurrency
pids=()
failed=0

for category in "${SELECTED_CATEGORIES[@]}"; do
  # If we've reached max concurrent tests, wait for one to finish
  if [[ ${#pids[@]} -ge $MAX_CONCURRENT ]]; then
    wait -n || failed=1
    # Remove completed processes from pids array
    for i in "${!pids[@]}"; do
      if ! kill -0 ${pids[i]} 2>/dev/null; then
        unset pids[i]
      fi
    done
    # Re-index array
    pids=("${pids[@]}")
  fi
  
  # Start the test as a background process
  run_test "$category" &
  pids+=($!)
done

# Wait for all remaining tests to complete
for pid in "${pids[@]}"; do
  wait $pid || failed=1
done

# Final status
if [ $failed -eq 0 ]; then
  echo "All tests completed successfully!"
  exit 0
else
  echo "Some tests failed, check logs for details"
  exit 1
fi