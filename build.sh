#!/bin/sh

set -eu

case "${1:-}" in
    a52q|a72q)
        DEVICE_NAME="$1"
        ;;
    *)
        echo "Usage: $0 <a52q|a72q>"
        exit 1
        ;;
esac

ROOT_DIR="$PWD"
OUT_DIR="$ROOT_DIR/out"

readonly DEFCONFIG="vendor/atoll-sec-perf_defconfig"
readonly LLVM_BIN="$ROOT_DIR/llvm-aosp/bin"
readonly MKBOOTIMG="$ROOT_DIR/mkbootimg/mkbootimg.py"

log() {
    echo
    echo "-----------------------------------------------"
    echo "$1"
    echo "-----------------------------------------------"
}

build_kernel() {
    log "Beginning kernel compilation..."

    export ARCH=arm64
    export PATH="$LLVM_BIN:$PATH"

    mkdir -p "$OUT_DIR"

    make \
        -j"$(nproc)" \
        ARCH=arm64 \
        O="$OUT_DIR" \
        LLVM=1 \
        "$DEFCONFIG" \
        "vendor/samsung/${DEVICE_NAME}.config" \
        all
}

build_dtbo() {
    log "Building dtbo.img..."

    DTBO_FILES=$(find \
        "$OUT_DIR/arch/arm64/boot/dts/samsung" \
        -name "atoll-sec-${DEVICE_NAME}-eur-overlay-*.dtbo")

    [ -n "$DTBO_FILES" ] || {
        echo "No DTBO files found!"
        exit 1
    }

    "$ROOT_DIR/tools/mkdtimg" create \
        "$OUT_DIR/dtbo.img" \
        --page_size=4096 \
        $DTBO_FILES

    mv "$OUT_DIR/dtbo.img" "dtbo-${DEVICE_NAME}.img"
}

build_boot() {
    log "Building boot.img..."

    readonly HEADER_VERSION="2"
    readonly OS_VERSION="16.0.0"
    readonly OS_SPL="$(date +%Y-%m)"

    readonly KERNEL_OUT="$OUT_DIR/arch/arm64/boot/Image"
    readonly RAMDISK="$ROOT_DIR/boot/ramdisk-${DEVICE_NAME}"
    readonly DTB_OUT="$OUT_DIR/arch/arm64/boot/dts/qcom/atoll-ab-idp.dtb"

    readonly PAGESIZE="4096"
    readonly BASE="0x00000000"
    readonly KERNEL_OFFSET="0x00008000"
    readonly RAMDISK_OFFSET="0x02000000"
    readonly SECOND_OFFSET="0x00000000"
    readonly TAGS_OFFSET="0x01e00000"
    readonly DTB_OFFSET="0x01f00000"

    readonly CMDLINE="console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=1 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image"

    case "$DEVICE_NAME" in
        a52q)
            BOARD_NAME="SRPTH31C002"
            ;;
        a72q)
            BOARD_NAME="SRPTJ06B011"
            ;;
    esac

    python3 "$MKBOOTIMG" \
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
        --output "boot-${DEVICE_NAME}.img"
}

build_kernel
build_dtbo
build_boot

log "Build completed successfully!"
echo "Kernel : boot-${DEVICE_NAME}.img"
echo "DTBO   : dtbo-${DEVICE_NAME}.img"
