#!/bin/bash

case `uname` in
  Linux)
    READLINK=readlink
    SED=sed
    export CORES=$((`nproc`+1))
  ;;
  Darwin)
    # assumes brew install coreutils in order to support readlink -f on macOS
    READLINK=greadlink
    SED=gsed
    export CORES=$((`sysctl -n hw.logicalcpu`+1))
  ;;
esac

# android sdk directory is changing
[ -n "${ANDROID_HOME}" ] && androidSdk=${ANDROID_HOME}
[ -n "${ANDROID_SDK}" ] && androidSdk=${ANDROID_SDK}
[ -n "${ANDROID_SDK_ROOT}" ] && androidSdk=${ANDROID_SDK_ROOT}
# java8/java11 paths
case `uname` in
  Linux)
    JAVA8=$(update-alternatives --list java | sed -nE -e 's/(.*java-8[^/]*).*/\1/p')
    [ -z "$JAVA8" ] && JAVA8=$(update-alternatives --list java | sed -nE -e 's/(.*jdk-8[^/]*).*/\1/p')
    JAVA11=$(update-alternatives --list java | sed -nE -e 's/(.*java-11[^/]*).*/\1/p')
    [ -z "$JAVA11" ] && JAVA8=$(update-alternatives --list java | sed -nE -e 's/(.*jdk-11[^/]*).*/\1/p')
  ;;
  Darwin)
    JAVA8=$(/usr/libexec/java_home -v 1.8)
    JAVA11=$(/usr/libexec/java_home -v 11)
  ;;
esac
[ -n "$JAVA11" ] && export PATH=${JAVA11}/bin:$PATH
# multiple sdkmanager paths
export PATH=${androidSdk}/cmdline-tools/latest/bin:${androidSdk}/cmdline-tools/bin:${androidSdk}/tools/bin:$PATH
WHICHSDKMANAGER=`which sdkmanager`
[ "$WHICHSDKMANAGER" == "${androidSdk}/tools/bin/sdkmanager" ] && SDKMANAGER="yes | JAVA_HOME=${JAVA8} ${androidSdk}/tools/bin/sdkmanager"
[ "$WHICHSDKMANAGER" == "${androidSdk}/cmdline-tools/bin/sdkmanager" ] && SDKMANAGER="yes | JAVA_HOME=${JAVA11} ${androidSdk}/cmdline-tools/bin/sdkmanager --sdk_root=${androidSdk}"
[ "$WHICHSDKMANAGER" == "${androidSdk}/cmdline-tools/latest/bin/sdkmanager" ] && SDKMANAGER="yes | JAVA_HOME=${JAVA11} ${androidSdk}/cmdline-tools/latest/bin/sdkmanager"
NDKVER=23
# retrieve first the java11 latest sdkmanager from cmdline-tools
eval $SDKMANAGER \'cmdline-tools\;latest\'
# install other necessary packages: ndk, cmake etc.
if [ ! -d "${androidSdk}/ndk" ]
then
  ndk=$(pkg="ndk;$NDKVER"; sdkmanager --list | grep ${pkg} | sed "s/^.*\($pkg\.[0-9\.]*\) .*$/\1/g" | tail -n 1)
  yes | sdkmanager "${ndk}" > /dev/null
  echo NDK $ndk installed
fi
[ -d "${androidSdk}/ndk" ] && NDK_PATH=$(ls -d ${androidSdk}/ndk/* | sort -V | tail -n 1)
echo NDK_PATH is ${NDK_PATH}
export ANDROID_NDK_HOME=${NDK_PATH}
export ANDROID_NDK_ROOT=${NDK_PATH}
if [ ! -d "${androidSdk}/cmake" ]
then
  cmake=$(pkg="cmake"; sdkmanager --list | grep ${pkg} | sed "s/^.*\($pkg;[0-9\.]*\).*$/\1/g" | head -n 1)
  sdkmanager "${cmake}"
fi
# latest cmake
[ -d "${androidSdk}/cmake" ] && CMAKE_PATH=$(ls -d ${androidSdk}/cmake/* | sort -V | tail -n 1)
echo CMAKE_PATH is ${CMAKE_PATH}
