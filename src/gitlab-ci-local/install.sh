#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# shellcheck disable=SC1091
#
# Docs: https://github.com/msclock/features/blob/main/src/gitlab-ci-local
# Maintainer: msclock

set -e

# log with color
_log() {
    local level=$1
    local msg=${*:2}

    _preset="clear"
    case "$level" in
    "red" | "r" | "error")
        _preset='\033[31m'
        ;;
    "green" | "g" | "success")
        _preset='\033[32m'
        ;;
    "yellow" | "y" | "warning" | "warn")
        _preset='\033[33m'
        ;;
    "blue" | "b" | "info")
        _preset='\033[34m'
        ;;
    "clear" | "c")
        _preset='\033[0m'
        ;;
    esac

    echo -e "$_preset["${level^^}"]:\033[0m $msg" 1>&2
}

if [ "$(id -u)" -ne 0 ]; then
    _log "error" "Script must be run as root. Use sudo, su, or add 'USER root' to your Dockerfile before running this script."
    exit 1
fi

GCL_VERSION="${VERSION:-"latest"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" >/dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
    USERNAME=root
fi

USERHOME="/home/$USERNAME"
if [ "$USERNAME" = "root" ]; then
    USERHOME="/root"
fi

# Install additional packages needed by vcpkg: https://github.com/microsoft/vcpkg/blob/master/README.md#installing-linux-developer-tools
# Check if packages are installed and installs them if not.

# Debian / Ubuntu packages

# Run apt-get if needed.
apt_get_update_if_needed() {
    if [ ! -d "/var/lib/apt/lists" ] || [ "$(find /var/lib/apt/lists/* -prune -print | wc -l)" = "0" ]; then
        _log "info" "Running apt-get update..."
        apt-get update
    else
        _log "info" "Skipping apt-get update."
    fi
}

install_debian_packages() {

    export DEBIAN_FRONTEND=noninteractive

    local package_list=(curl
        ca-certificates
        git)

    if ! dpkg -s "${package_list[@]}" >/dev/null 2>&1; then
        apt_get_update_if_needed
        apt-get -y install --no-install-recommends "${package_list[@]}"
    fi

    unset DEBIAN_FRONTEND
}

# RedHat / RockyLinux / CentOS / Fedora packages
install_redhat_packages() {
    local install_cmd=dnf
    if ! type dnf >/dev/null 2>&1; then
        install_cmd=yum
    fi

    # Get to latest versions of all packages
    if [ "${UPGRADE_PACKAGES}" = "true" ]; then
        ${install_cmd} upgrade -y
    fi

    local package_list=(ca-certificates)

    # rockylinux:9 installs 'curl-minimal' which clashes with 'curl'
    # Install 'curl' for every OS except this rockylinux:9
    if [[ "${ID}" = "rocky" ]] && [[ "${VERSION}" != *"9."* ]]; then
        package_list+=(curl)
    fi

    # Install git if not already installed (may be more recent than distro version)
    if ! type git >/dev/null 2>&1; then
        package_list+=(git)
    fi
    ${install_cmd} -y install "${package_list[@]}"
}

# Alpine Linux packages
install_alpine_packages() {
    apk update

    apk add --no-cache \
        curl \
        ca-certificates
    # Install git if not already installed (may be more recent than distro version)
    if ! type git >/dev/null 2>&1; then
        apk add --no-cache git
    fi
}

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independant of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    _log "error" "Linux distro ${ID} not supported."
    exit 1
fi

# Install packages for appropriate OS
if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ]; then
    case "${ADJUSTED_ID}" in
    "debian")
        install_debian_packages
        ;;
    "rhel")
        install_redhat_packages
        ;;
    "alpine")
        install_alpine_packages
        ;;
    esac
    PACKAGES_ALREADY_INSTALLED="true"
fi

# ******************
# ** Main section **
# ******************

if [ "$GCL_VERSION" == "latest" ]; then
    api_info="$(curl -sX GET https://api.github.com/repos/firecow/gitlab-ci-local/releases/latest)"
    GCL_VERSION=$(echo "$api_info" | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||')
fi

_log "info" GCL_VERSION "$GCL_VERSION"

# Function to compare versions
# Returns 0 if version1 >= version2, 1 otherwise
version_ge() {
    local ver1="$1"
    local ver2="$2"
    local arr1 arr2

    # Split versions into arrays
    IFS='.' read -ra arr1 <<< "$ver1"
    IFS='.' read -ra arr2 <<< "$ver2"

    # Compare each part numerically
    local i
    for ((i = 0; i < ${#arr1[@]} || i < ${#arr2[@]}; i++)); do
        local num1=${arr1[i]:-0}
        local num2=${arr2[i]:-0}

        # Remove leading zeros for numeric comparison
        num1=$((10#$num1))
        num2=$((10#$num2))

        if ((num1 > num2)); then
            return 0
        elif ((num1 < num2)); then
            return 1
        fi
    done

    # Versions are equal
    return 0
}

cd /tmp

# Version 4.66.0 and later use new archive format: gitlab-ci-local-linux-{arch}.tar.gz
# Earlier versions use the old format: linux.gz
if version_ge "$GCL_VERSION" "4.66.0"; then
    # Detect CPU architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            GCL_ARCH="amd64"
            ;;
        aarch64)
            GCL_ARCH="arm64"
            ;;
        *)
            _log "error" "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    filename="gitlab-ci-local-linux-${GCL_ARCH}.tar.gz"
    curl -sSL -o "$filename" "https://github.com/firecow/gitlab-ci-local/releases/download/${GCL_VERSION}/${filename}"
    tar -xzf "$filename" && rm "$filename"
    mv gitlab-ci-local /usr/local/bin/gitlab-ci-local
    chmod 0755 /usr/local/bin/gitlab-ci-local
else
    # Old format for versions before 4.66.0
    curl -sSL -o linux.gz "https://github.com/firecow/gitlab-ci-local/releases/download/${GCL_VERSION}/linux.gz"
    gzip -dc linux.gz >/usr/local/bin/gitlab-ci-local && rm linux.gz
    chmod 0755 /usr/local/bin/gitlab-ci-local
fi

# gcl bash completion
if [ ! -d "/etc/bash_completion.d" ]; then
    mkdir /etc/bash_completion.d
fi

gitlab-ci-local --completion >/etc/bash_completion.d/gitlab-ci-local

# gcl zsh completion
if [ -e "${USERHOME}/.oh_my_zsh" ]; then
    mkdir -p "${USERHOME}/.oh_my_zsh/completions"
    gitlab-ci-local --completion >"${USERHOME}/.oh-my-zsh/completions/_gitlab-ci-local"
    chown -R "${USERNAME}" "${USERHOME}/.oh-my-zsh"
fi

_log "success" "Install gitlab-ci-local successfully."
