#!/bin/bash

# shellcheck disable=SC1091

# This test can be run with the following command (from the root of this repo)
#    devcontainer features test \
#               --features vcpkg \
#               --base-image mcr.microsoft.com/devcontainers/base:ubuntu .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "vcpkg is installed" vcpkg --version
check "cmake is installed" cmake --version
check "write permission" bash -c "test -w /usr/local/vcpkg"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
