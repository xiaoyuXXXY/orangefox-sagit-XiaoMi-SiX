#!/bin/bash
# 强制重新打包 ramdisk（改了主题 / 设备树里的 sbin 脚本之后用）
#
#   FOX_DIR=~/fox_12.1 bash build/clean-rebuild.sh
#
# 说明：只删 sagit 的产物，不动整个 out/，下次编译只重打 ramdisk 和镜像，通常 3 分钟内完成。
set -e

FOX_DIR="${FOX_DIR:-$HOME/fox_12.1}"
OUT="$FOX_DIR/out/target/product/sagit"

if [ ! -d "$OUT" ]; then
    echo "没有产物目录：$OUT"
    exit 0
fi

cd "$OUT"
for f in ramdisk ramdisk.img debug_ramdisk recovery recovery.img \
         OrangeFox-R12.0-Unofficial-sagit.img \
         OrangeFox-R12.0-Unofficial-sagit.img.md5; do
    [ -e "$f" ] && rm -f "$f" && echo "删除 $f"
done

echo "完成。重新执行 build/build.sh 即可。"
