#!/bin/bash

sudo apt-get -q=2 update
sudo apt-get -q=2 -y install ccache cmake g++-multilib gcc-arm-none-eabi git libc6-dev-i386 python-requests python3-ply python3-yaml rsync

set -ex

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 https://git.linaro.org/lite/linaro-aeolus.git ${WORKSPACE}
git-retry submodule sync --recursive
git-retry submodule update --init --recursive --checkout
git clean -fdx
echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters

# Toolchains are pre-installed and come from:
# https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/6-2016q4/gcc-arm-none-eabi-6_2-2016q4-20161216-linux.tar.bz2
# https://nexus.zephyrproject.org/content/repositories/releases/org/zephyrproject/zephyr-sdk/0.9/zephyr-sdk-0.9-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.9-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.9"

case "${ZEPHYR_GCC_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-6_2-2016q4"
  ;;
  zephyr)
    mkdir -p ${HOME}/opt
    ln -sf ${HOME}/srv/toolchain/zephyr-sdk-0.9 ${HOME}/opt/zephyr-sdk-0.9
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/opt/zephyr-sdk-0.9"
  ;;
esac

# Set build environment variables
LANG=C
ZEPHYR_BASE=${WORKSPACE}
PATH=${ZEPHYR_BASE}/scripts:${PATH}
export LANG ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'

echo ""
echo "########################################################################"
echo "    Build"
echo "########################################################################"

make_wrapper=zmake
[ "${PROJECT}" = "zephyr.js" ] && make_wrapper=zmake-z.js
bash -x ${make_wrapper} ${PROJECT} BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
mv ${PROJECT}-${PLATFORM}-*.bin ${PROJECT}-${PLATFORM}-*.elf out/${PLATFORM}/

CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
CCACHE_DIR=${CCACHE_DIR} ccache -s
