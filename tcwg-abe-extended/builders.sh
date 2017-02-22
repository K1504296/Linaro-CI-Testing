#!/bin/bash

if [ "x$label" = "xtcwg-x86_64-cam" ]; then
  schroot_arch=amd64
  schroot_image="tcwg-build-${schroot_arch}-trusty"

  session_id=$(schroot -b -c chroot:$schroot_image --preserve-environment)
  BUILD_SHELL="schroot -r -c session:$session_id --preserve-environment -- bash"
  $BUILD_SHELL -c "echo \"Build session is up; ulimit config:\"; ulimit -a"

  # Remove schroot session on exit.
  trap "schroot -f -e -c session:$session_id" 0 SIGHUP SIGINT SIGQUIT SIGTRAP SIGPIPE SIGTERM
else
  BUILD_SHELL=bash
fi

git clone -b $scripts_branch --depth 1 https://git-us.linaro.org/toolchain/jenkins-scripts

gcc4_9ver=gcc=gcc.git~linaro-4.9-2016.02
gcc5ver=gcc=gcc.git~linaro-5.3-2016.05
gcc6ver=gcc=gcc.git~linaro-6.1-2016.08

gccnum=$(echo ${testname} | sed 's/.*_gcc//') # eg 6
gccversionname=gcc${gccnum}ver                # eg gccversionname=gcc6ver
gccversion=$(eval echo \$$gccversionname)     # eg gccversion=gcc=gcc.git~linaro-6.1-2016.08

case "$testname" in
  canadian_cross_build_gcc*)
    # Configure git user info to make git stash happy. It
    # is used during the second build, because the sources
    # are already present.
    git config --global user.email "tcwg-buildslave@linaro.org"
    git config --global user.name "TCWG BuildSlave"
    mkdir _build
    cd _build
    target=arm-linux-gnueabihf
    ${BUILD_SHELL} ../configure --with-git-reference-dir=~tcwg-buildslave/snapshots-ref
    ret=$?
    if test ${ret} -ne 0; then
      echo "Configure error: ${ret}"
      exit $ret
    fi
    ${BUILD_SHELL} ${WORKSPACE}/abe.sh --target ${target} --extraconfigdir ../config/gcc${gccnum} --build all $gccversion
    ret=$?
    if test ${ret} -ne 0; then
      echo "First build error: ${ret}"
      exit $ret
    fi
    ${BUILD_SHELL} ${WORKSPACE}/abe.sh --target ${target} --extraconfigdir ../config/gcc${gccnum} --build all $gccversion --host i686-w64-mingw32
    ret=$?
    if test ${ret} -ne 0; then
      echo "Second build error: ${ret}"
      exit $ret
    fi
    #FIXME: check what was actually built
    #FIXME: validate the manifest
    ;;
  *_build_check_gcc*)
    bootstrap=
    case ${testname} in
      cross_linux_*)
        target=arm-linux-gnueabihf
        ;;
      cross_bare_*)
        target=aarch64-none-elf
        ;;
      cross_qemu_*)
        target=armeb-linux-gnueabihf
        ;;
      native_*)
        target=native
        bootstrap=--bootstrap
        ;;
    esac

    # Build and check a linux target
    ${BUILD_SHELL} -x ${WORKSPACE}/jenkins-scripts/jenkins.sh --abedir `pwd` --target ${target} ${bootstrap} --runtests --excludecheck gdb --override "--extraconfigdir ../config/gcc${gccnum} $gccversion"
    ret=$?
    #FIXME: check validation results (against a known baseline)
    #FIXME: validate the manifest
    ;;
  abe-testsuite)
    ${BUILD_SHELL} -c "set -ex; ./configure; make check"
    ret=$?
    ;;
  abe-tests-checkout)
    ${BUILD_SHELL} -c "set -ex; git clone https://git.linaro.org/toolchain/abe-tests.git; cd abe-tests; ./test-checkout.sh --clean-snapshots --abe-path `pwd` --ref-snapshots /home/tcwg-buildslave/snapshots-ref"
    ret=$?
    ;;
  abe-tests-*)
    target=$(echo ${testname} | sed 's/abe-tests-//')
    ${BUILD_SHELL} -c "set -ex; git clone https://git.linaro.org/toolchain/abe-tests.git; cd abe-tests; ./test-manifest2.sh --abe-path `pwd` --ref-snapshots /home/tcwg-buildslave/snapshots-ref --quiet --display-report --target ${target}"
    ret=$?
    ;;
esac

exit $ret
