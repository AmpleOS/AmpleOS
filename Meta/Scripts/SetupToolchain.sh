CACHE_DIR=$TARGET_DIR/Cache
BUILD_DIR=$TARGET_DIR/Build
CROSS_DIR=$TARGET_DIR/Cross

BUILDROOT_VERSION=2022.11.1
BUILDROOT_PACKAGE=buildroot-$BUILDROOT_VERSION
BUILDROOT_ARCHIVE=${BUILDROOT_PACKAGE}.tar.gz
BUILDROOT_MD5SUM="57d88d1f977ad6bee4a8e2821443296b"

BUILDROOT_OUTPUT_VERSION=${TARGET}
BUILDROOT_OUTPUT_PACKAGE="${BUILDROOT_OUTPUT_VERSION}_sdk-buildroot"
BUILDROOT_OUTPUT_ARCHIVE=${BUILDROOT_OUTPUT_PACKAGE}.tar.gz

OUTPUT_DIR=${BUILD_DIR}/${BUILDROOT_PACKAGE}/output/images

MIRROR=https://buildroot.org/downloads

mkdir -p ${CACHE_DIR}
cd ${CACHE_DIR}

md5=""
if [ -e "$BUILDROOT_ARCHIVE" ]; then
    md5="$(md5sum $BUILDROOT_ARCHIVE | cut -f1 -d' ')"
    echo "Buildroot MD5='$md5'"
fi

if [ "$md5" != ${BUILDROOT_MD5SUM} ] ; then
    rm -f ${BUILDROOT_ARCHIVE}
    curl -LO "${MIRROR}/${BUILDROOT_ARCHIVE}"
else
    echo "Skipped buildroot download"
fi

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

if [ ! -d "${BUILDROOT_PACKAGE}" ]; then
    if [ -d ${BUILDROOT_PACKAGE} ]; then
        rm -rf "${BUILDROOT_PACKAGE}"
    fi
    echo "Extracting buildroot"
    tar -xf ${CACHE_DIR}/${BUILDROOT_ARCHIVE}
else
    echo "Using buildroot from existing source directory"
fi

cd ${BUILD_DIR}/${BUILDROOT_PACKAGE}
cp ${SOURCE_DIR}/Meta/Scripts/Configs/${ARCH}-toolchain.config .config
make source
make sdk

cd ${BUILD_DIR}
tar -xf ${OUTPUT_DIR}/${BUILDROOT_OUTPUT_ARCHIVE}

rsync -aH --inplace --update ${BUILD_DIR}/${BUILDROOT_OUTPUT_PACKAGE}/ ${CROSS_DIR}/
rsync -aH --inplace --update ${BUILD_DIR}/${BUILDROOT_OUTPUT_PACKAGE}/${BUILDROOT_OUTPUT_VERSION}/sysroot/ ${SYSROOT_DIR}/
