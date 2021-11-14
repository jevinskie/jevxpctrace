#!/usr/bin/env zsh


set -o errexit
set -o nounset
set -o pipefail

# set -o xtrace

# FRIDA_ROOT_MACOS_ARM64
# FRIDA_SDK_ROOT_MACOS_ARM64

CFLAGS=$(pkg-config frida-gumpp-1.0 --static --cflags --define-variable=frida_sdk_prefix=${FRIDA_SDK_ROOT_MACOS_ARM64})
LDFLAGS=$(pkg-config frida-gumpp-1.0 --static --libs --define-variable=frida_sdk_prefix=${FRIDA_SDK_ROOT_MACOS_ARM64})

echo "OTHER_CFLAGS = \$(inherited) ${CFLAGS}"
echo "OTHER_LDFLAGS = \$(inherited) ${LDFLAGS}"
