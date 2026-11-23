#!/bin/bash
# 编译 OrangeFox recovery（sagit）
#
#   FOX_DIR=~/fox_12.1 bash build/build.sh
#   JOBS=8 FOX_DIR=~/fox_12.1 bash build/build.sh
#
# 产物：$FOX_DIR/out/target/product/sagit/OrangeFox-R12.0-Unofficial-sagit.img
set -o pipefail

FOX_DIR="${FOX_DIR:-$HOME/fox_12.1}"
JOBS="${JOBS:-$(nproc)}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=sagit
export LC_ALL=C

if [ ! -f "$FOX_DIR/build/envsetup.sh" ]; then
    echo "找不到源码树：$FOX_DIR（用 FOX_DIR=... 指定）" >&2
    exit 1
fi

cd "$FOX_DIR" || exit 1

echo "== 源码树 : $FOX_DIR"
echo "== JDK    : $JAVA_HOME"
echo "== 并行   : $JOBS"

# shellcheck disable=SC1091
source build/envsetup.sh

lunch twrp_sagit-eng || { echo "lunch 失败：设备树是否放在 device/xiaomi/sagit？" >&2; exit 1; }

START=$(date +%s)
mka recoveryimage -j"$JOBS"
RC=$?
END=$(date +%s)

OUT="$FOX_DIR/out/target/product/sagit"
if [ $RC -ne 0 ]; then
    echo "编译失败（用了 $((END-START)) 秒）" >&2
    exit $RC
fi

echo "编译完成，用时 $((END-START)) 秒"
ls -lh "$OUT"/OrangeFox-*.img 2>/dev/null
echo
echo "校验：python3 scripts/verify_img.py check \"$OUT/OrangeFox-R12.0-Unofficial-sagit.img\""
