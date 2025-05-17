# NixOS Testing Strategy

This document outlines our tiered approach to testing NixOS configurations, providing options for different levels of validation depth and execution speed.

## Testing Approaches

We provide several test scripts with different tradeoffs between thoroughness and execution speed:

### 1. Direct Configuration Test (Fastest)

**Script:** `./scripts/direct-test-runner.sh [system_name]`

**Description:** Performs a direct build test of NixOS configurations without booting a VM. This is the fastest validation approach, ensuring configuration validity without the overhead of booting a virtual machine.

**Use when:**
- You need a quick sanity check of configuration changes
- You're making small iterative changes and want immediate validation
- You're in CI/CD pipeline pre-check phase

**Execution time:** ~2-5 minutes depending on system complexity

### 2. Minimal VM Test (Fast)

**Script:** `./scripts/run-minimal-test.sh [timeout_seconds]`

**Description:** Runs an ultra-minimal VM test with basic system boot validation. This test boots a lightweight NixOS VM configuration with minimal services enabled to quickly verify that the system can boot successfully.

**Use when:**
- You need to validate bootability of the system
- You want to ensure core services come up correctly
- You need basic system validation beyond configuration parsing

**Execution time:** ~2-10 minutes

### 3. Component-Specific VM Tests (Medium)

**Script:** `./scripts/run-single-test.sh [timeout_seconds] [test-name]`

**Description:** Runs a specific test that focuses on a particular component or subsystem. These tests are modular and targeted to validate specific functionality.

**Available test modules:**
- `nix-ws-core` - Basic system functionality
- `nix-ws-network` - Network functionality
- `nix-ws-gui` - GUI subsystems
- `nix-ws-integration` - Multi-component integration tests

**Use when:**
- You've modified a specific subsystem
- You want targeted validation of a component
- You're developing new features for a specific area

**Execution time:** ~5-15 minutes per test

### 4. Full E2E VM Tests (Slow)

**Script:** `./scripts/run-vm-tests.sh [timeout_seconds]`

**Description:** Comprehensive end-to-end testing with a complete system VM. This validates the entire system from boot to operation, including all services, networking, and user interfaces.

**Use when:**
- Before releases or major version changes
- When making significant architectural changes
- For full system validation before deployment

**Execution time:** ~30-60 minutes

### 5. Parallel Test Execution (Scalable)

**Script:** `./scripts/run-tests-parallel.sh [timeout_seconds] [concurrency]`

**Description:** Runs multiple VM tests in parallel for faster execution on systems with adequate resources. This approach can significantly reduce overall testing time when multiple cores are available.

**Use when:**
- You have sufficient system resources for parallel execution
- You need to run multiple or all tests
- Time is critical and parallel execution can be tolerated

**Execution time:** Varies based on concurrency and resource availability

## Best Practices

1. **Iterative Development:** Use the direct test runner during development for quick feedback
2. **Component Testing:** Run specific component tests after changing related code
3. **Pre-Commit:** Run the minimal test before committing changes
4. **Pre-Release:** Run full E2E tests before releases or major changes
5. **CI Pipeline:** Configure a graduated approach in CI:
   - Direct configuration test for all PRs
   - Component-specific tests based on changed files
   - Full E2E tests for release branches

## Architecture

Our test system leverages NixOS's native VM testing capabilities but adds:

1. Granular test definitions in `flake.nix` under the `checks` attribute
2. Custom timeout handling to prevent hung tests
3. Various levels of system service activation for different test depths
4. Tailscale disabling for faster tests (when network testing isn't required)
5. Fast-build module optimization for quicker VM provisioning

## Environmental Variables

- `NIXPKGS_ALLOW_UNFREE=1` - Required for testing configurations with unfree packages
- `BUILD_TIMEOUT` - Can be set to override default timeout values