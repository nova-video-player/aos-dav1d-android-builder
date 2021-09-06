#!/bin/bash

while getopts "a:c:" opt; do
  case $opt in
    a)
      ARCH=$OPTARG ;;
    c)
      FLAVOR=$OPTARG ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ARCH}" ]] ; then
  echo 'You need to input arch with -a ARCH.'
  echo 'Supported archs are:'
  echo -e '\tarm arm64 x86 x86_64'
  exit 1
fi


case `uname` in
  Linux)
    READLINK=readlink
    SED=sed
  ;;
  Darwin)
    # assumes brew install coreutils in order to support readlink -f on macOS
    READLINK=greadlink
    SED=gsed
  ;;
esac

LOCAL_PATH=$($READLINK -f .)

# android sdk directory is changing
[ -n "${ANDROID_HOME}" ] && androidSdk=${ANDROID_HOME}
[ -n "${ANDROID_SDK_ROOT}" ] && androidSdk=${ANDROID_SDK_ROOT}
# multiple sdkmanager paths
export PATH=${androidSdk}/cmdline-tools/tools/bin:${androidSdk}/tools/bin:$PATH
[ ! -d "${androidSdk}/ndk-bundle" -a ! -d "${androidSdk}/ndk" ] && sdkmanager ndk-bundle
[ -d "${androidSdk}/ndk" ] && NDK_PATH=$(ls -d ${androidSdk}/ndk/* | sort -V | tail -n 1)
[ -d "${androidSdk}/ndk-bundle" ] && NDK_PATH=${androidSdk}/ndk-bundle
echo NDK_PATH is ${NDK_PATH}

ANDROID_API=21

ARCH_CONFIG_OPT=

case "${ARCH}" in
  'arm')
    ARCH_TRIPLET='arm-linux-androideabi'
    ARCH_TRIPLET_VARIANT='armv7a-linux-androideabi'
    ABI='armeabi-v7a'
    CPU_FAMILY='arm'
    ARCH_CFLAGS='-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mthumb'
    ARCH_LDFLAGS='-march=armv7-a -Wl,--fix-cortex-a8'
    B_ARCH='arm'
    B_ADDRESS_MODEL=32 ;;
  'arm64')
    ARCH_TRIPLET='aarch64-linux-android'
    ARCH_TRIPLET_VARIANT=$ARCH_TRIPLET
    ABI='arm64-v8a'
    CPU_FAMILY='aarch64'
    B_ARCH='arm'
    B_ADDRESS_MODEL=64 ;;
  'x86')
    ARCH_TRIPLET='i686-linux-android'
    ARCH_TRIPLET_VARIANT=$ARCH_TRIPLET
    ARCH_CONFIG_OPT='--disable-asm'
    ARCH_CFLAGS='-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32'
    ABI='x86'
    CPU_FAMILY='x86'
    B_ARCH='x86'
    B_ADDRESS_MODEL=32 ;;
  'x86_64')
    ARCH_TRIPLET='x86_64-linux-android'
    ARCH_TRIPLET_VARIANT=$ARCH_TRIPLET
    ABI='x86_64'
    CPU_FAMILY='x86_64'
    ARCH_CFLAGS='-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel'
    B_ARCH='x86'
    B_ADDRESS_MODEL=64 ;;
  *)
    echo "Arch ${ARCH} is not supported."
    exit 1 ;;
esac

os=$(uname -s | tr '[:upper:]' '[:lower:]')
CROSS_PREFIX="${NDK_PATH}"/toolchains/llvm/prebuilt/${os}-x86_64/bin

set -eu

dir_name=build

echo "Generating toolchain description..."
user_config=android_cross_${ABI}.txt
rm -f $user_config
cat <<EOF > $user_config
[binaries]
name = 'android'
c     = '${CROSS_PREFIX}/${ARCH_TRIPLET_VARIANT}${ANDROID_API}-clang'
cpp   = '${CROSS_PREFIX}/${ARCH_TRIPLET_VARIANT}${ANDROID_API}-clang++'
ar    = '${CROSS_PREFIX}/${ARCH_TRIPLET}-ar'
ld    = '${CROSS_PREFIX}/${ARCH_TRIPLET}-ld'
strip = '${CROSS_PREFIX}/${ARCH_TRIPLET}-strip'

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'linux'
cpu_family = '${CPU_FAMILY}'
cpu = '${CPU_FAMILY}'
endian = 'little'

EOF

if [ ! -d "${dir_name}-${ABI}" ]; then
  mkdir ${dir_name}-${ABI}
else
  echo "Already built for ${ABI}"
  exit 0
fi

if [ ! -d dav1d ]; then
  git clone https://code.videolan.org/videolan/dav1d -b 0.9.2
fi

cd dav1d
#git checkout 191f79d5a914c647fa941ee8c72f807ca2bd1fcb

echo "Build: calling meson..."
meson --buildtype release --cross-file ../android_cross_${ABI}.txt -Denable_tools=false -Denable_tests=false ../${dir_name}-${ABI}

echo "Building with Ninja"
#cd ${dir_name}-${ABI}
ninja -C  ../${dir_name}-${ABI}
$SED -i 's:libdav1d\.so\.[0-9]:libdav1d\.so\x0\x0:' $($READLINK -f ../${dir_name}-${ABI}/src/libdav1d.so)

echo "Done!"
