#!/bin/sh
#-------------------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://github.com/devcontainers/features/blob/main/LICENSE for license information.
#-------------------------------------------------------------------------------------------------------------------------
#
# shellcheck disable=SC1091
#
# Docs: https://github.com/msclock/features/blob/main/src/vcpkg
# Maintainer: msclock

set -e

USERNAME="${USERNAME:-"root"}"

if [ "$(id -u)" -ne 0 ]; then
    printf "\033[31mERROR:\033[0m Script must be run as root. Use sudo, su, or add 'USER root' to your Dockerfile before running this script.\n"
    exit 1
fi

# If we're using Alpine, install bash before executing
. /etc/os-release
if [ "${ID}" = "alpine" ]; then
    apk add --no-cache bash
fi

exec /bin/bash "$(dirname "$0")/main.sh" "$@"
exit $?
