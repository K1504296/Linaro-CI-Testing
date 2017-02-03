# Early test
if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

# Clean android-patchsets and repositories in device
rm -rf build/out build/android-patchsets build/device
mkdir -p build

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

# Copy dtb mlo uboot to out location
cp /home/buildslave/srv/${BUILD_DIR}/u-boot/MLO /home/buildslave/srv/${BUILD_DIR}/u-boot/u-boot /home/buildslave/srv/${BUILD_DIR}/linux/arch/arm/boot/dts/*.dtb /home/buildslave/srv/${BUILD_DIR}/build/out/


if [ ${JOB_NAME} == "android-lcr-member-x15-n" ]; then
  wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/x15/build-info/template.txt -O build/out/BUILD-INFO.txt
fi

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/build/out
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
PUB_EXTRA_INC="^[^/]+[._](u-boot|MLO|dtb)$"
EOF

# Construct post-build-lava parameters
source build-configs/${BUILD_CONFIG_FILENAME}
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=${LAVA_DEVICE_TYPE:-${TARGET_PRODUCT}}
TARGET_PRODUCT=${TARGET_PRODUCT}
MAKE_TARGETS=${MAKE_TARGETS}
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
IMAGE_EXTENSION=img
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/x15/template.json
SKIP_REPORT=false
EOF
