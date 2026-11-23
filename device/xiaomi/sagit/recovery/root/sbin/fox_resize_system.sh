#!/sbin/sh
# OrangeFox - 新建 / 调整 System 分区
#
# 做法：清理历史上残留的 system / cust，从 cache 之后重新排布：
#   system   = N GB          （N: 5 ~ 12，5 为原厂 5120 MB）
#   cust     = 沿用原厂大小   （/vendor 实际落在这里）
#   userdata = 剩余全部       （到磁盘末尾）
#
# 破坏性操作：userdata 会被格式化，system / cust 内容清空。
# 执行后必须重刷 ROM。
#
# 用法：
#   fox_resize_system.sh plan 8          只打印计划，不改任何东西
#   fox_resize_system.sh run  8 [ext4]   执行（默认 ext4，可传 f2fs）
#
# 日志：/tmp/fox_resize_system.log
# 失败：内部存储根目录 fox_resize_error.txt

SGDISK=/sbin/sgdisk
MKE2FS=/sbin/mke2fs
MAKEF2FS=/sbin/make_f2fs

MODE="${1:-plan}"
GB="${2:-0}"
FSTYPE="${3:-ext4}"
LOG=/tmp/fox_resize_system.log
ERRLOG=/tmp/fox_resize_error.txt

# 找一个用户能在「文件管理器」里直接看到的目录，用于存放日志副本
SDCARD=""
for d in /sdcard /data/media/0 /storage/emulated/0; do
    if [ -d "$d" ] && [ -w "$d" ]; then
        SDCARD="$d"
        break
    fi
done

: > "$LOG" 2>/dev/null

log() {
    echo "$@"
    echo "$@" >> "$LOG" 2>/dev/null
}

die() {
    log ""
    log "!! 失败：$1"
    log "!! 详细日志：$LOG"
    cp "$LOG" "$ERRLOG" 2>/dev/null
    if [ -n "$SDCARD" ]; then
        if cp "$LOG" "$SDCARD/fox_resize_error.txt" 2>/dev/null; then
            log "!! 日志已存到：$SDCARD/fox_resize_error.txt"
        fi
    fi
    exit 1
}

# 格式化阶段的失败不中止：三个分区必须全部建成文件系统，
# 否则设备会因为 data 不可挂载而开不了机
FAILED=0
warn() {
    FAILED=$(( FAILED + 1 ))
    log ""
    log "!! 失败（第 $FAILED 步）：$1"
}

log "=============================================="
log " OrangeFox  System 分区重建"
log "=============================================="
log "模式: $MODE   容量: ${GB}GB   文件系统: $FSTYPE"
[ -n "$SDCARD" ] && log "日志副本目录: $SDCARD"
log ""

case "$MODE" in
    plan|run) ;;
    *) log "用法: $0 plan|run <GB 5-12> [ext4|f2fs]"; exit 1 ;;
esac

case "$GB" in
    ''|*[!0-9]*) log "!! 容量必须是 5 到 12 之间的整数"; exit 1 ;;
esac
if [ "$GB" -lt 5 ] || [ "$GB" -gt 12 ]; then
    log "!! 容量必须是 5 到 12 之间的整数，当前：$GB"
    exit 1
fi

# ---------- 定位工具 ----------
for p in /sbin/sgdisk /system/bin/sgdisk /sbin/sgdisk_static; do
    [ -x "$p" ] && SGDISK="$p" && break
done
[ -x "$SGDISK" ] || die "镜像内缺少可执行的 sgdisk"

# mke2fs 默认读 /etc/mke2fs.conf，而 /etc -> /system/etc。
# system 分区被挂载后这个软链就指向空分区，mke2fs 会直接 exit 1。
# 强制用 ramdisk 里的副本，同时优先用 /sbin 下的二进制（不受挂载影响）。
MKE2FS_CONFIG=/sbin/mke2fs.conf
export MKE2FS_CONFIG

for p in /sbin/mke2fs /system/bin/mke2fs /sbin/mkfs.ext4 /system/bin/mkfs.ext4; do
    [ -x "$p" ] && MKE2FS="$p" && break
done
[ -x "$MKE2FS" ] || die "镜像内缺少可执行的 mke2fs"

for p in /sbin/make_f2fs /system/bin/make_f2fs; do
    [ -x "$p" ] && MAKEF2FS="$p" && break
done

log "sgdisk : $SGDISK"
log "mke2fs : $MKE2FS  （配置 $MKE2FS_CONFIG）"
log "f2fs   : ${MAKEF2FS:-无}"
log ""

# ---------- 定位 by-name ----------
BYNAME=""
for d in /dev/block/bootdevice/by-name /dev/block/by-name \
         /dev/block/platform/soc/*/by-name /dev/block/platform/*/by-name; do
    if [ -e "$d/userdata" ]; then
        BYNAME="$d"
        break
    fi
done
[ -n "$BYNAME" ] || die "找不到 userdata 分区节点（by-name 目录不存在）"

log "by-name: $BYNAME"

DATA_REAL=$(readlink -f "$BYNAME/userdata")
log "userdata 节点: $DATA_REAL"
case "$DATA_REAL" in
    *mmcblk*p[0-9]*) DISK=$(echo "$DATA_REAL" | sed 's/p[0-9]*$//') ;;
    *)               DISK=$(echo "$DATA_REAL" | sed 's/[0-9]*$//') ;;
esac
[ -b "$DISK" ] || die "无法定位整盘设备：$DISK"

SEC=$(blockdev --getss "$DISK" 2>/dev/null | tr -d ' \r\n')
case "$SEC" in
    ''|*[!0-9]*) SEC=4096 ;;
esac
[ "$SEC" -gt 0 ] 2>/dev/null || SEC=4096

# 每 MB 多少扇区。先做除法再做乘法，避免 8 GB 这类数值在 32 位算术里溢出
SEC_PER_MB=$(( 1048576 / SEC ))
[ "$SEC_PER_MB" -gt 0 ] || SEC_PER_MB=256

log "整盘设备:   $DISK"
log "扇区大小:   $SEC 字节（每 MB $SEC_PER_MB 扇区）"
log ""

# ---------- 读分区表 ----------
GPT=/tmp/fox_gpt_before.txt
"$SGDISK" --print "$DISK" > "$GPT" 2>&1
if [ $? -ne 0 ]; then
    log "---- sgdisk 输出 ----"
    cat "$GPT"
    cat "$GPT" >> "$LOG"
    die "读取分区表失败"
fi
log "---- 当前分区表 ----"
cat "$GPT"
cat "$GPT" >> "$LOG"
log "--------------------"

# 取一行：编号 起始 结束 名字
FIELD() { awk -v n="$1" 'NR>1 && $1==n {print $2; exit}' "$GPT"; }

LINE=$(awk '$NF=="userdata"{print; exit}' "$GPT")
[ -n "$LINE" ] || die "分区表中没有 userdata"

N_DATA=$(echo "$LINE" | awk '{print $1}')
START_DATA_OLD=$(echo "$LINE" | awk '{print $2}')
END_DATA=$(echo "$LINE" | awk '{print $3}')

log ""
log "userdata: 编号 $N_DATA, 扇区 $START_DATA_OLD - $END_DATA"

# ---------- 起点：cache 之后 ----------
CACHE_END=$(awk '$NF=="cache"{print $3; exit}' "$GPT")
if [ -n "$CACHE_END" ]; then
    BASE=$(echo "$CACHE_END" | tr -d ',')
    BASE=$(( BASE + 1 ))
else
    BASE=$(awk '/First usable sector/{print $5; exit}' "$GPT" | tr -d ',')
    case "$BASE" in ''|*[!0-9]*) BASE=114688 ;; esac
fi

# ---------- 待清理的分区 ----------
# 历次失败可能留下多组 system / cust，全部删掉，从 cache 之后重排
DEL_LIST=$(awk 'NR>1 && ($NF=="system" || $NF=="cust" || $NF=="userdata") {print $1}' "$GPT")
[ -n "$DEL_LIST" ] || die "分区表里找不到 system / cust / userdata"

DEL_COUNT=$(echo "$DEL_LIST" | wc -l | tr -d ' ')
log ""
log "将清理 $DEL_COUNT 个分区（含历史残留的 system/cust）："
for n in $DEL_LIST; do
    nm=$(awk -v n="$n" 'NR>1 && $1==n {print $NF}' "$GPT")
    st=$(awk -v n="$n" 'NR>1 && $1==n {print $2}' "$GPT")
    en=$(awk -v n="$n" 'NR>1 && $1==n {print $3}' "$GPT")
    log "  $n  $nm  $st - $en"
done

# ---------- 新编号：剩余分区最大号 + 1 ----------
# 注意：DEL_LIST 是多行，直接塞进 awk -v 会让 busybox awk 报
# "newline in string"，导致 MAX_KEEP 为空、编号退化成 1/2/3，
# 从而把 switch / ssd / bk1 这些底层分区覆盖掉。必须先压成一行。
DEL_ONELINE=$(echo $DEL_LIST)

MAX_KEEP=$(awk -v list="$DEL_ONELINE" '
    BEGIN { n=split(list,a," "); for (i=1;i<=n;i++) del[a[i]]=1 }
    NR>1 && $1 ~ /^[0-9]+$/ && !($1 in del) { if ($1+0 > m) m=$1+0 }
    END { print m+0 }' "$GPT")

case "$MAX_KEEP" in
    ''|*[!0-9]*) die "内部错误：分区编号计算失败（结果为「$MAX_KEEP」），已中止" ;;
esac
[ "$MAX_KEEP" -ge 16 ] \
    || die "内部错误：新分区编号异常（起始号 $MAX_KEEP，应不小于 16），已中止"

N_SYS=$(( MAX_KEEP + 1 ))
N_CUST=$(( MAX_KEEP + 2 ))
N_DATA_NEW=$(( MAX_KEEP + 3 ))

# ---------- 计算新布局（全部先除后乘，防溢出） ----------
if [ "$GB" = "5" ]; then
    SYS_SEC=$(( 5120 * SEC_PER_MB ))
    SYS_LABEL="5120 MB（原厂）"
else
    SYS_SEC=$(( GB * 1024 * SEC_PER_MB ))
    SYS_LABEL="${GB} GB"
fi
# cust 大小：直接沿用当前表里 cust 的实际扇区数。切小了 vendor 会刷不进去，
# 所以宁可跟原厂一样，也不再用写死的估算值。
CUST_SEC=0
for n in $DEL_LIST; do
    [ "$(awk -v n="$n" 'NR>1 && $1==n {print $NF}' "$GPT")" = "cust" ] || continue
    st=$(awk -v n="$n" 'NR>1 && $1==n {print $2}' "$GPT" | tr -d ',')
    en=$(awk -v n="$n" 'NR>1 && $1==n {print $3}' "$GPT" | tr -d ',')
    case "${st}${en}" in ''|*[!0-9]*) continue ;; esac
    sz=$(( en - st + 1 ))
    [ "$sz" -gt "$CUST_SEC" ] && CUST_SEC=$sz
done
CUST_MAX=$(( 4096 * SEC_PER_MB ))
# 832 是这台机器原厂 cust（= vendor）的实测大小，是硬下限。
# 原厂 system/cust 在另一块 LUN 上，新盘探测不到，必须靠这个下限兜住，
# 否则会退回老版本写死的 656，vendor 一旦超过就刷不进去。
CUST_FLOOR=$(( 832 * SEC_PER_MB ))
if [ "$CUST_SEC" -lt "$CUST_FLOOR" ] || [ "$CUST_SEC" -gt "$CUST_MAX" ]; then
    CUST_SEC=$CUST_FLOOR
    CUST_LABEL="832 MB（原厂）"
else
    CUST_LABEL="$(( CUST_SEC / SEC_PER_MB )) MB"
fi
MIN_DATA_SEC=$(( 8 * 1024 * SEC_PER_MB ))

START_SYS=$BASE
END_SYS=$(( START_SYS + SYS_SEC - 1 ))
START_CUST=$(( END_SYS + 1 ))
END_CUST=$(( START_CUST + CUST_SEC - 1 ))
START_DATA_NEW=$(( END_CUST + 1 ))

[ "$END_SYS" -gt "$START_SYS" ] || die "内部计算异常：system 扇区数为 $SYS_SEC"

if [ "$START_DATA_NEW" -gt "$END_DATA" ]; then
    die "空间不足：cache 之后放不下 system($SYS_LABEL) + cust($CUST_LABEL)"
fi

REST=$(( END_DATA - START_DATA_NEW + 1 ))
REST_MB=$(( REST / SEC_PER_MB ))
REST_GB=$(( REST_MB / 1024 ))

[ "$REST" -ge "$MIN_DATA_SEC" ] \
    || die "空间不足：按 $SYS_LABEL 划分后 data 只剩 ${REST_GB} GB（至少需要 8 GB）"

log ""
log "---- 新布局 ----"
log "  $N_SYS  system    $START_SYS - $END_SYS      $SYS_LABEL"
log "  $N_CUST  cust      $START_CUST - $END_CUST      $CUST_LABEL"
log "  $N_DATA_NEW  userdata  $START_DATA_NEW - $END_DATA     ${REST_GB} GB"
log "----------------"

if [ "$MODE" = "plan" ]; then
    log ""
    log "仅预览，未做任何修改。"
    exit 0
fi

# ---------- 执行 ----------
log ""
log "5 秒后开始写分区表，请勿断电..."
sleep 5

BK=/tmp/fox_gpt_backup.bin
"$SGDISK" --backup="$BK" "$DISK" > /tmp/fox_sgdisk_bk.txt 2>&1
if [ $? -ne 0 ] || [ ! -s "$BK" ]; then
    log "---- sgdisk 备份输出 ----"
    cat /tmp/fox_sgdisk_bk.txt
    cat /tmp/fox_sgdisk_bk.txt >> "$LOG"
    die "GPT 备份失败，已中止"
fi
log "GPT 已备份到 $BK"

umount /data 2>/dev/null
umount /sdcard 2>/dev/null
umount /system 2>/dev/null
umount /vendor 2>/dev/null
umount /cust 2>/dev/null
sync
sleep 1

# 第一步：逐个删除（不用一次带多个 --delete，精简版 sgdisk 会错位）
log ""
log "第 1 步：删除旧的 system / cust / userdata"
for n in $DEL_LIST; do
    OUT=$("$SGDISK" --delete="$n" "$DISK" 2>&1)
    if [ $? -ne 0 ]; then
        echo "$OUT" >> "$LOG"
        log "$OUT"
        "$SGDISK" --load-backup="$BK" "$DISK" >> "$LOG" 2>&1
        sync
        blockdev --rereadpt "$DISK" 2>/dev/null
        die "删除分区 $n 失败，已回滚原分区表"
    fi
    log "  已删除 $n"
done
sync
sleep 1

# 第二步：逐个新建（一次一个 --new，避免 partNum 错位）
log ""
log "第 2 步：创建新分区"

make_part() {
    n="$1"; s="$2"; e="$3"; nm="$4"
    OUT=$("$SGDISK" --new="$n:$s:$e" --typecode="$n:8300" --change-name="$n:$nm" "$DISK" 2>&1)
    if [ $? -ne 0 ]; then
        echo "$OUT" >> "$LOG"
        log "$OUT"
        log "!! 创建 $nm（$n）失败，正在回滚..."
        "$SGDISK" --load-backup="$BK" "$DISK" >> "$LOG" 2>&1
        sync
        blockdev --rereadpt "$DISK" 2>/dev/null
        die "创建分区 $nm 失败，已回滚原分区表；原 data 未格式化"
    fi
    log "  $n  $nm  $s - $e"
}

make_part "$N_SYS" "$START_SYS" "$END_SYS" system
make_part "$N_CUST" "$START_CUST" "$END_CUST" cust
make_part "$N_DATA_NEW" "$START_DATA_NEW" "$END_DATA" userdata

sync

# ---------- 第 2.5 步：清掉其它 LUN 上的同名 system / cust ----------
# 原厂把 system(5 GiB) / cust(832 MiB) 放在另一块 LUN（sde）上。新分区建在
# sda 之后，内核里就有两个都叫 system 的分区，ueventd 建 by-name 软链时
# 可能仍指向旧的那个 —— 结果 ROM 刷进 8 GiB 的新分区，系统却从 5 GiB 的
# 旧分区启动，怎么刷都起不来。所以必须把旧的那份删掉。
log ""
log "第 2.5 步：清理其它磁盘上的同名 system / cust"

for d in /dev/block/sd?; do
    [ -b "$d" ] || continue
    [ "$d" = "$DISK" ] && continue
    CONFLICT=$("$SGDISK" --print "$d" 2>/dev/null | awk 'NR>1 && ($NF=="system" || $NF=="cust") {print $1, $NF}')
    [ -n "$CONFLICT" ] || continue

    BK2="/tmp/fox_gpt_$(basename "$d").bin"
    "$SGDISK" --backup="$BK2" "$d" >> "$LOG" 2>&1 \
        || log "  警告：$d 分区表备份失败，仍继续"

    echo "$CONFLICT" | while read -r num nm; do
        [ -n "$num" ] || continue
        log "  $d 上发现旧的 $nm（编号 $num），删除"
        "$SGDISK" --delete="$num" "$d" >> "$LOG" 2>&1 \
            || log "  !! 删除 $d 的 $num 号分区失败（可忽略，重启后可再清）"
    done
    sync
    blockdev --rereadpt "$d" 2>/dev/null
    log "  $d 已处理"
done
sync
sleep 2

# 第三步：核对新表
CHECK=$("$SGDISK" --print "$DISK" 2>&1)
echo "$CHECK" >> "$LOG"
if ! echo "$CHECK" | awk '{for(i=1;i<=NF;i++){if($i=="system")s=1;if($i=="cust")c=1;if($i=="userdata")d=1}} END{exit !(s&&c&&d)}'; then
    log ""
    log "!! 新分区表不完整，正在回滚原分区表..."
    "$SGDISK" --load-backup="$BK" "$DISK" >> "$LOG" 2>&1
    sync
    blockdev --rereadpt "$DISK" 2>/dev/null
    sleep 1
    die "分区表写入不完整，已恢复原分区表；原 data 未格式化"
fi
log "新分区表校验通过"

log ""
log "重新读取分区表..."
blockdev --rereadpt "$DISK" 2>/dev/null || log "警告：rereadpt 返回非 0"
sleep 2

log ""
log "---- 新分区表 ----"
"$SGDISK" --print "$DISK"
"$SGDISK" --print "$DISK" >> "$LOG" 2>&1
log "------------------"

# 等节点出现
i=0
while [ $i -lt 15 ]; do
    [ -e "$BYNAME/system" ] && [ -e "$BYNAME/cust" ] && [ -e "$BYNAME/userdata" ] && break
    i=$(( i + 1 ))
    sleep 1
done

if [ ! -e "$BYNAME/system" ] || [ ! -e "$BYNAME/cust" ] || [ ! -e "$BYNAME/userdata" ]; then
    log ""
    log "!! 分区表已改好，但内核没有刷新出新的分区节点。"
    log "!! 本机的 data 目前处于未格式化状态，必须重启 Recovery"
    log "!! 后再进「清除」格式化 System / Cust / Data，否则无法开机。"
    cp "$LOG" "$ERRLOG" 2>/dev/null
    [ -n "$SDCARD" ] && cp "$LOG" "$SDCARD/fox_resize_error.txt" 2>/dev/null
    exit 2
fi

# ---------- 核对 by-name 指向 ----------
# 软链如果还指着旧分区的设备节点，ROM 就会刷到错的地方，必须先停下
SYS_NODE="${DISK}${N_SYS}"
[ -e "$SYS_NODE" ] || SYS_NODE="${DISK}p${N_SYS}"
CUST_NODE="${DISK}${N_CUST}"
[ -e "$CUST_NODE" ] || CUST_NODE="${DISK}p${N_CUST}"

SYS_REAL=$(readlink -f "$BYNAME/system" 2>/dev/null)
CUST_REAL=$(readlink -f "$BYNAME/cust" 2>/dev/null)
SYS_WANT=$(readlink -f "$SYS_NODE" 2>/dev/null)
CUST_WANT=$(readlink -f "$CUST_NODE" 2>/dev/null)

log ""
log "by-name/system -> $SYS_REAL（应为 $SYS_WANT）"
log "by-name/cust   -> $CUST_REAL（应为 $CUST_WANT）"

if [ "$SYS_REAL" != "$SYS_WANT" ] || [ "$CUST_REAL" != "$CUST_WANT" ]; then
    log ""
    log "!! by-name 仍指向别的分区，新分区没被内核接管。"
    log "!! 请重启 Recovery，再进「清除」格式化 System / Cust / Data，"
    log "!! 然后刷 ROM。此时不要刷 ROM，否则会写进旧分区。"
    cp "$LOG" "$ERRLOG" 2>/dev/null
    [ -n "$SDCARD" ] && cp "$LOG" "$SDCARD/fox_resize_error.txt" 2>/dev/null
    exit 4
fi
log "by-name 校验通过"

# ---------- 格式化前：彻底释放挂载 ----------
# /data 至少会被挂三次：/data、/sdcard、/storage（bind mount）。
# 只按挂载点卸容易漏，这里改成「按设备找挂载点」，逐个卸干净。
umount_dev() {
    _dev="$1"
    _try=0
    while [ $_try -lt 5 ]; do
        _mps=$(awk -v d="$_dev" '$1==d {print $2}' /proc/mounts 2>/dev/null)
        [ -z "$_mps" ] && return 0
        for _mp in $_mps; do
            umount "$_mp" 2>/dev/null || umount -l "$_mp" 2>/dev/null
        done
        _try=$(( _try + 1 ))
        sleep 1
    done
    _mps=$(awk -v d="$_dev" '$1==d {print $2}' /proc/mounts 2>/dev/null)
    [ -z "$_mps" ] && return 0
    UNMOUNT_LEFT="$_mps"
    return 1
}

log ""
log "卸载已挂载的分区..."
# 先按常见挂载点粗卸一遍（/storage、/mnt/* 这些 bind mount 容易被漏掉）
for mp in /sdcard /storage /data /system /system_root /vendor /cust /cache /persist \
          /mnt/media_rw /mnt/runtime/default /mnt/runtime/read /mnt/runtime/write \
          /emmc /external_sd; do
    grep -q " $mp " /proc/mounts 2>/dev/null || continue
    umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null
done

# 再按设备精卸：凡是挂在 system / cust / userdata 上的，全部卸掉
BAD=0
for dev in "$(readlink -f "$BYNAME/system" 2>/dev/null)" \
           "$(readlink -f "$BYNAME/cust" 2>/dev/null)" \
           "$(readlink -f "$BYNAME/userdata" 2>/dev/null)"; do
    [ -n "$dev" ] && [ -e "$dev" ] || continue
    if ! umount_dev "$dev"; then
        log "!! 设备 $dev 仍被挂载在：$UNMOUNT_LEFT"
        BAD=1
    fi
done

if [ "$BAD" = "1" ]; then
    log ""
    log "!! 有分区卸不下来，此时格式化会破坏正在使用的数据，已停止。"
    log "!! 请重启 Recovery，进入后不要打开「挂载」页勾选任何分区，再重试。"
    cp "$LOG" "$ERRLOG" 2>/dev/null
    [ -n "$SDCARD" ] && cp "$LOG" "$SDCARD/fox_resize_error.txt" 2>/dev/null
    exit 5
fi
log "  已全部卸载"

# 统一的 ext4 格式化：失败时把错误末尾直接打到屏幕上，
# 不用再回头翻日志文件
fmt_ext4() {
    _label="$1"
    _dev="$2"
    if "$MKE2FS" -F -t ext4 -L "$_label" -m 0 "$_dev" >> "$LOG" 2>&1; then
        log "  $_label 格式化完成"
        return 0
    fi
    log "  $_label 格式化失败，输出末尾："
    tail -n 8 "$LOG"
    return 1
}

log ""
log "格式化 system（ext4）..."
fmt_ext4 system "$BYNAME/system" || warn "system 格式化失败"

log "格式化 cust（ext4）..."
fmt_ext4 cust "$BYNAME/cust" || warn "cust 格式化失败"

log "格式化 userdata（$FSTYPE）..."
ACTUAL_FSTYPE="$FSTYPE"
DEGRADED=""
if [ "$FSTYPE" = "f2fs" ] && [ -n "$MAKEF2FS" ] && [ -x "$MAKEF2FS" ]; then
    # 不传分区大小：让 make_f2fs 自己按整设备算，避免 TWRP 那套 size 参数在
    # 4K 扇区设备上算错。特性也从多到少逐层退，总有一档能被内核接受。
    if "$MAKEF2FS" -f -O encrypt,extra_attr "$BYNAME/userdata" >> "$LOG" 2>&1; then
        log "  f2fs 完成（encrypt,extra_attr）"
    else
        log "  第一次失败，去掉附加特性重试..."
        if "$MAKEF2FS" -f "$BYNAME/userdata" >> "$LOG" 2>&1; then
            log "  f2fs 完成（默认特性）"
        else
            log "  f2fs 输出末尾："
            tail -n 8 "$LOG"
            # 降级到 ext4 属于「有兜底」，不算失败，但要明确告知
            if fmt_ext4 data "$BYNAME/userdata"; then
                ACTUAL_FSTYPE=ext4
                DEGRADED="f2fs 不可用，已降级为 ext4"
                log "  !! $DEGRADED"
            else
                warn "userdata 格式化为 f2fs / ext4 均失败"
            fi
        fi
    fi
else
    fmt_ext4 data "$BYNAME/userdata" || warn "userdata 格式化失败"
fi

log "重建内部存储目录..."
# data 分区刚格式化，必须重新挂载后 media 目录才会真正落盘
if ! grep -q " /data " /proc/mounts; then
    mount -t "$ACTUAL_FSTYPE" "$BYNAME/userdata" /data 2>/dev/null \
        || mount -t ext4 "$BYNAME/userdata" /data 2>/dev/null
fi
mkdir -p /data/media/0 2>/dev/null
chown -R media_rw:media_rw /data/media 2>/dev/null
chmod 0770 /data /data/media /data/media/0 2>/dev/null
restorecon -R /data/media 2>/dev/null

sync

if [ "$FAILED" -gt 0 ]; then
    log ""
    log "=============================================="
    log " 分区表已改好，但有 $FAILED 步失败"
    log " 请重启 Recovery，在「清除」里逐个格式化"
    log " System / Cust / Data，完成后再刷 ROM。"
    log "=============================================="
    cp "$LOG" "$ERRLOG" 2>/dev/null
    for d in /data/media/0 "$SDCARD"; do
        [ -n "$d" ] && [ -d "$d" ] && cp "$LOG" "$d/fox_resize_error.txt" 2>/dev/null && break
    done
    exit 3
fi

log ""
log "=============================================="
log " 完成"
log " system   : $SYS_LABEL"
log " cust     : $CUST_LABEL"
log " userdata : ${REST_GB} GB ($ACTUAL_FSTYPE)"
if [ -n "$DEGRADED" ]; then
    log " 注意：$DEGRADED"
    log " 刷 ROM 后若卡在解密，请重启 Recovery，用 f2fs 重格 data 再刷。"
fi
log " 三个分区都是空的，请立即重刷 ROM。"
log "=============================================="

# 成功后也留一份日志，方便事后核对
for d in /data/media/0 "$SDCARD"; do
    [ -n "$d" ] && [ -d "$d" ] && cp "$LOG" "$d/fox_resize_done.txt" 2>/dev/null && \
        log "日志已存到：$d/fox_resize_done.txt" && break
done

exit 0
