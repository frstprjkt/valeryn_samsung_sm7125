#!/bin/sh

DEVICE_NAME="$1"

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation..."
    echo "-----------------------------------------------"

    export ARCH=arm64
    mkdir out

    export PATH=$(pwd)/llvm-aosp/bin:$PATH

    BUILD_VAR="-j$(nproc --all) ARCH=arm64 O=out LLVM=1"

    make $BUILD_VAR vendor/atoll-sec-perf_defconfig vendor/samsung/$DEVICE_NAME.config all
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find $(pwd)/out/arch/arm64/boot/dts/samsung/ -name atoll-sec-$DEVICE_NAME-eur-overlay-*.dtbo)
    $(pwd)/tools/mkdtimg create $(pwd)/out/dtbo.img --page_size=4096 $DTBO_FILES

    mv $(pwd)/out/dtbo.img dtbo-$DEVICE_NAME.img
}

build_boot() {
    echo "-----------------------------------------------"
    echo "Building boot.img..."
    echo "-----------------------------------------------"
    MKBOOTIMG="$(pwd)/mkbootimg/mkbootimg.py"
    HEADER_VERSION="2"
    OS_VERSION="16.0.0"
    OS_SPL="$(date +%Y-%m)"
    KERNEL_OUT="$(pwd)/out/arch/arm64/boot/Image"
    RAMDISK="$(pwd)/boot/ramdisk-$DEVICE_NAME"
    DTB_OUT="$(pwd)/out/arch/arm64/boot/dts/qcom/atoll-ab-idp.dtb"
    PAGESIZE="4096"
    BASE="0x00000000"
    KERNEL_OFFSET="0x00008000"
    RAMDISK_OFFSET="0x02000000"
    SECOND_OFFSET="0x00000000"
    TAGS_OFFSET="0x01e00000"
    DTB_OFFSET="0x01f00000"
    CMDLINE="console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=1 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image"

    if [ "$DEVICE_NAME" = "a52q" ]; then
        BOARD_NAME=SRPTH31C002
    elif [ "$DEVICE_NAME" = "a72q" ]; then
        BOARD_NAME=SRPTJ06B011
    fi

    $MKBOOTIMG \
        --header_version "$HEADER_VERSION" \
        --os_version "$OS_VERSION" \
        --os_patch_level "$OS_SPL" \
        --kernel "$KERNEL_OUT" \
        --ramdisk "$RAMDISK" \
        --dtb "$DTB_OUT" \
        --pagesize "$PAGESIZE" \
        --base "$BASE" \
        --kernel_offset "$KERNEL_OFFSET" \
        --ramdisk_offset "$RAMDISK_OFFSET" \
        --second_offset "$SECOND_OFFSET" \
        --tags_offset "$TAGS_OFFSET" \
        --dtb_offset "$DTB_OFFSET" \
        --board "$BOARD_NAME" \
        --cmdline "$CMDLINE" \
        --output boot-"$DEVICE_NAME".img
}

build_kernel
build_dtbo
build_boot
