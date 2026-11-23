#!/sbin/sh
# 探测当前 system 分区大小，供扩容页显示"当前分区大小"。
# 由 fox_resize_system 页的 ftls action 调用，结果 twrp xset 到 UI 变量。

NODE=/dev/block/bootdevice/by-name/system
[ -e "$NODE" ] || NODE=/dev/block/by-name/system

BYTES=0
if [ -e "$NODE" ]; then
    BYTES=$(blockdev --getsize64 "$NODE" 2>/dev/null)
fi

if [ -n "$BYTES" ] && [ "$BYTES" -gt 0 ] 2>/dev/null; then
    # 字节 -> GiB，保留一位小数（awk 浮点，避开 shell 32 位溢出）
    GB=$(awk -v b="$BYTES" 'BEGIN { printf "%.1f", b / 1073741824 }')
    twrp xset fox_sys_cur_gb="$GB"
else
    twrp xset fox_sys_cur_gb="未知"
fi
