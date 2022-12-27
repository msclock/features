#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

set -e

SETCOLOR_SUCCESS="echo -en \\E[1;32m"
SETCOLOR_FAILURE="echo -en \\E[1;31m"
SETCOLOR_WARNING="echo -en \\E[1;33m"
# SETCOLOR_NORMAL="echo  -en \\E[0;39m"

USERNAME=${USERNAME:-"vscode"}
VCPKG_ROOT="${VCPKGROOT:-"automatic"}"
VCPKG_DOWNLOADS="${VCPKGDOWNLOADS:-"automatic"}"
VERSION="${VERSION:-"stable"}"

# Set vcpkg root on automatic
if [ "${USERNAME}" = "none" ] || [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME="root"
fi

# Set vcpkg root on automatic
if [ "${VCPKG_ROOT}" = "auto" ] || [ "${VCPKG_ROOT}" = "automatic" ]; then
    VCPKG_ROOT="/usr/local/vcpkg"
fi

# Set vcpkg download on automatic
if [ "${VCPKG_DOWNLOADS}" = "auto" ] || [ "${VCPKG_DOWNLOADS}" = "automatic" ]; then
    VCPKG_DOWNLOADS="/usr/local/vcpkg-downloads"
fi

# bionic and stretch pkg repos install cmake version < 3.15 which is required to run bootstrap-vcpkg.sh on ARM64
VCPKG_UNSUPPORTED_ARM64_VERSION_CODENAMES="stretch bionic"

# If we're using Alpine, install bash before executing
# shellcheck source=/dev/null
. /etc/os-release
if [ "${ID}" = "alpine" ]; then
    $SETCOLOR_FAILURE && echo -e 'Script only is compatibility with debain/ubuntu-like.'
    exit 1
fi

# Exit early if ARM64 OS does not have cmake version required to build Vcpkg
if [ "$(dpkg --print-architecture)" = "arm64" ] && [[ "${VCPKG_UNSUPPORTED_ARM64_VERSION_CODENAMES}" = *"${VERSION_CODENAME}"* ]]; then
    $SETCOLOR_WARNING && echo "OS ${VERSION_CODENAME} ARM64 pkg repo installs cmake version < 3.15, which is required to build Vcpkg."
    exit 0
fi

# Add to bashrc/zshrc files for all users.
updaterc() {
    echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
    if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
        echo -e "$1" >>/etc/bash.bashrc
    fi
    if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
        echo -e "$1" >>/etc/zsh/zshrc
    fi
}

# Run apt-get if needed.
apt_get_update_if_needed() {
    if [ ! -d "/var/lib/apt/lists" ] || [ "$(find /var/lib/apt/lists/* -prune -print | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update
    else
        echo "Skipping apt-get update."
    fi
}

# Check if packages are installed and installs them if not.
check_packages() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        apt_get_update_if_needed
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install additional packages needed by vcpkg: https://github.com/microsoft/vcpkg/blob/master/README.md#installing-linux-developer-tools
check_packages build-essential tar curl zip unzip pkg-config bash-completion ninja-build git

# Setup group and add user
umask 0002
if ! grep </etc/group -e "^vcpkg:" >/dev/null 2>&1; then
    groupadd -r "vcpkg"
fi
usermod -a -G "vcpkg" "${USERNAME}"

# Start Installation
# Clone repository with ports and installer
if [ -d "${VCPKG_ROOT}" ]; then
    $SETCOLOR_WARNING && echo -e "Found a vcpkg distribution folder ${VCPKG_ROOT}. Removing it..."
    rm -rf "${VCPKG_ROOT}"
fi
mkdir -p "${VCPKG_DOWNLOADS}"
mkdir -p "${VCPKG_ROOT}"

clone_args=(--depth=1
    -c core.eol=lf
    -c core.autocrlf=false
    -c fsck.zeroPaddedFilemode=ignore
    -c fetch.fsck.zeroPaddedFilemode=ignore
    -c receive.fsck.zeroPaddedFilemode=ignore
    https://github.com/microsoft/vcpkg "${VCPKG_ROOT}")

# Setup vcpkg actual version
if [ "${VERSION}" = "stable" ]; then
    api_info=$(curl -sX GET https://api.github.com/repos/microsoft/vcpkg/releases/latest)
    vcpkg_actual_version=$(echo "$api_info" | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||')
    git clone -b "$vcpkg_actual_version" "${clone_args[@]}"
elif [ "${VERSION}" = "latest" ]; then
    git clone "${clone_args[@]}"
else
    tags=$(git ls-remote --tags https://github.com/microsoft/vcpkg | awk '{ print $2 }' | sed -e 's|refs/tags/||g')
    if echo "$tags" | grep "${VERSION}" >/dev/null 2>&1; then
        echo "Get valid tag" "${VRESION}"
        git clone -b "${VERSION}" "${clone_args[@]}"
    else
        $SETCOLOR_FAILURE && echo -e 'Need a valid vcpkg tag to install !!! Please see https://github.com/microsoft/vcpkg/tags.'
    fi
fi
## Run installer to get latest stable vcpkg binary
## https://github.com/microsoft/vcpkg/blob/7e7dad5fe20cdc085731343e0e197a7ae655555b/scripts/bootstrap.sh#L126-L144
"${VCPKG_ROOT}"/bootstrap-vcpkg.sh

# Add vcpkg to PATH
updaterc "$(
    cat <<EOF
export VCPKG_ROOT="${VCPKG_ROOT}"
if [[ "\${PATH}" != *"\${VCPKG_ROOT}"* ]]; then export PATH="\${VCPKG_ROOT}:\${PATH}"; fi
EOF
)"

# Give read/write permissions to the user group.
chown -R ":vcpkg" "${VCPKG_ROOT}" "${VCPKG_DOWNLOADS}"
chmod g+r+w+s "${VCPKG_ROOT}" "${VCPKG_DOWNLOADS}"
chmod -R g+r+w "${VCPKG_ROOT}" "${VCPKG_DOWNLOADS}"

# Enable tab completion for bash and zsh
VCPKG_FORCE_SYSTEM_BINARIES=1 su "${USERNAME}" -c "${VCPKG_ROOT}/vcpkg integrate bash"
VCPKG_FORCE_SYSTEM_BINARIES=1 su "${USERNAME}" -c "${VCPKG_ROOT}/vcpkg integrate zsh"

$SETCOLOR_SUCCESS && echo -e "Install vcpkg successfully."
