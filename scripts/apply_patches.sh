#!/bin/bash
# 按顺序应用本项目全部补丁
#
#   REC_DIR=~/fox_12.1/bootable/recovery bash scripts/apply_patches.sh
#   REC_DIR=... bash scripts/apply_patches.sh --check   # 只检查，不落地
#
# 补丁来自 fox_12.1 的 bootable/recovery（2026-11 上游）。若上游更新，
# 先 git log 对齐，必要时手工 rebase。
set -u

REC_DIR="${REC_DIR:-$HOME/fox_12.1/bootable/recovery}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="$HERE/patches"
CHECK_ONLY=0

[ "${1:-}" = "--check" ] && CHECK_ONLY=1

if [ ! -d "$REC_DIR/gui" ]; then
    echo "不是 recovery 源码目录：$REC_DIR" >&2
    exit 1
fi

cd "$REC_DIR" || exit 1

fail=0
for p in "$PATCH_DIR"/*.patch; do
    name="$(basename "$p")"
    if [ "$CHECK_ONLY" = 1 ]; then
        if git apply --check "$p" 2>/dev/null; then
            echo "[OK]   $name"
        else
            echo "[FAIL] $name"
            fail=1
        fi
    else
        if git apply "$p"; then
            echo "[APPLY] $name"
        else
            echo "[FAIL]  $name（可能已应用，或上游已变更）"
            fail=1
        fi
    fi
done

exit $fail
