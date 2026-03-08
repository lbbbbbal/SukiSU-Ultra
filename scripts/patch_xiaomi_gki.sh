#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "用法: $0 <boot.img> <init_boot.img> [输出目录]"
  exit 1
fi

BOOT_IMG=$(realpath "$1")
INIT_BOOT_IMG=$(realpath "$2")
OUT_DIR=${3:-./out}
OUT_DIR=$(realpath -m "$OUT_DIR")

if [[ ! -f "$BOOT_IMG" ]]; then
  echo "错误: boot.img 不存在: $BOOT_IMG"
  exit 1
fi

if [[ ! -f "$INIT_BOOT_IMG" ]]; then
  echo "错误: init_boot.img 不存在: $INIT_BOOT_IMG"
  exit 1
fi

mkdir -p "$OUT_DIR"

if command -v ksud >/dev/null 2>&1; then
  KSUD_BIN=$(command -v ksud)
else
  echo "未检测到 ksud，尝试从源码构建 userspace/ksud ..."
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
  (cd "$REPO_ROOT/userspace/ksud" && cargo build --release)
  KSUD_BIN="$REPO_ROOT/userspace/ksud/target/release/ksud"
fi

if [[ ! -x "$KSUD_BIN" ]]; then
  echo "错误: ksud 不可执行: $KSUD_BIN"
  exit 1
fi

echo "[1/2] 补丁 boot.img"
"$KSUD_BIN" boot-patch -b "$BOOT_IMG" -o "$OUT_DIR" --out-name "boot_patched.img"

echo "[2/2] 补丁 init_boot.img"
"$KSUD_BIN" boot-patch -b "$INIT_BOOT_IMG" -o "$OUT_DIR" --out-name "init_boot_patched.img"

cat <<MSG

补丁完成，输出目录: $OUT_DIR
  - $OUT_DIR/boot_patched.img
  - $OUT_DIR/init_boot_patched.img

请在 fastbootd/bootloader 下刷入：
  fastboot flash boot $OUT_DIR/boot_patched.img
  fastboot flash init_boot $OUT_DIR/init_boot_patched.img
  fastboot reboot

刷机前请确认设备已解 BL、并备份原始镜像。
MSG
