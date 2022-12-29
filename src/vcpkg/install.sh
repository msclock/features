#!/bin/sh
#-------------------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://github.com/devcontainers/features/blob/main/LICENSE for license information.
#-------------------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/msclock/features/blob/main/src/vcpkg
# Maintainer: msclock

set -e

SETCOLOR_FAILURE="echo -en \\E[1;31m"
SETCOLOR_NORMAL="echo  -en \\E[0;39m"

USERNAME="${USERNAME:-"root"}"

if [ "$(id -u)" -ne 0 ]; then
    $SETCOLOR_FAILURE && echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.' && $SETCOLOR_NORMAL
    exit 1
fi

# If we're using Alpine, install bash before executing
# shellcheck source=/dev/null
. /etc/os-release
if [ "${ID}" = "alpine" ]; then
    apk add --no-cache bash
fi

exec /bin/bash "$(dirname "$0")/main.sh" "$@"
exit $?
