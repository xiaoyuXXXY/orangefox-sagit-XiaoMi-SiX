#!/usr/bin/env python3
"""
OrangeFox boot image inspector (no external tools required).

用法:
    verify_img.py info  <img>                 # 头部信息 + MD5
    verify_img.py ls    <img> [prefix]        # 列出 ramdisk 条目
    verify_img.py cat   <img> <path>          # 打印 ramdisk 内某个文件
    verify_img.py check <img>                 # 检查本项目关键文件是否在镜像里

支持 Android boot image v0（OrangeFox / TWRP 12.1 用的就是这种），
ramdisk 可以是 gzip 压缩的 cpio newc。
"""
import sys
import os
import gzip
import struct
import hashlib

MAGIC = b'ANDROID!'
BOOT_NAME_SIZE = 16
BOOT_ARGS_SIZE = 512


def read_img(path):
    raw = open(path, 'rb').read()
    if raw[:8] != MAGIC:
        sys.exit(f'不是 Android boot image（magic={raw[:8]!r}）')
    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr) = struct.unpack_from('<4I', raw, 8)
    second_size, second_addr, tags_addr, page_size = struct.unpack_from('<4I', raw, 24)
    # v0 头：36 page_size / 44 os_version / 48 name[16] / 64 cmdline[512]
    os_version, name, cmdline = struct.unpack_from('<I16s512s', raw, 44)
    name = name.rstrip(b'\x00').decode('utf-8', 'replace')
    cmdline = cmdline.rstrip(b'\x00').decode('utf-8', 'replace')
    return {
        'raw': raw, 'kernel_size': kernel_size, 'ramdisk_size': ramdisk_size,
        'second_size': second_size, 'page_size': page_size, 'name': name,
        'cmdline': cmdline, 'os_version': os_version,
        'kernel_addr': kernel_addr, 'ramdisk_addr': ramdisk_addr,
    }


def align(n, p):
    return (n + p - 1) // p * p


def get_ramdisk(info):
    p = info['page_size']
    if p == 0:
        p = 2048
    off = align(p, p) + align(info['kernel_size'], p) + align(info['second_size'], p)
    rd = info['raw'][off:off + info['ramdisk_size']]
    if rd[:2] == b'\x1f\x8b':
        rd = gzip.decompress(rd)
    return rd


def parse_cpio(rd):
    """返回 [(name, mode, data)]，按镜像内顺序。"""
    entries = []
    pos = 0
    while pos + 110 <= len(rd):
        if rd[pos:pos + 6] not in (b'070701', b'070702'):
            break

        def h(i):
            return int(rd[pos + 6 + i * 8: pos + 6 + (i + 1) * 8], 16)

        mode = h(1)
        filesize = h(6)
        namesize = h(11)
        name_off = pos + 110
        name = rd[name_off:name_off + namesize - 1].decode('utf-8', 'replace')
        data_off = align(name_off + namesize, 4)
        data = rd[data_off:data_off + filesize]
        if name == 'TRAILER!!!':
            break
        entries.append((name, mode, data))
        pos = align(data_off + filesize, 4)
    return entries


def cmd_info(path):
    info = read_img(path)
    raw = info['raw']
    print(f'文件      : {path}')
    print(f'大小      : {len(raw):,} 字节 ({len(raw)/1048576:.2f} MB)')
    print(f'MD5       : {hashlib.md5(raw).hexdigest()}')
    print(f'board     : {info["name"]}')
    print(f'page_size : {info["page_size"]}')
    print(f'kernel    : {info["kernel_size"]:,} 字节')
    print(f'ramdisk   : {info["ramdisk_size"]:,} 字节')
    print(f'cmdline   : {info["cmdline"][:160]}')
    try:
        rd = get_ramdisk(info)
        entries = parse_cpio(rd)
        print(f'ramdisk   : 解压后 {len(rd):,} 字节，{len(entries)} 个条目')
    except Exception as e:  # noqa: BLE001
        print(f'ramdisk   : 解析失败 {e}')


def cmd_ls(path, prefix=''):
    info = read_img(path)
    entries = parse_cpio(get_ramdisk(info))
    hits = [e for e in entries if prefix in e[0]] if prefix else entries
    for name, mode, data in hits:
        kind = 'd' if (mode & 0o170000) == 0o040000 else ('l' if (mode & 0o170000) == 0o120000 else '-')
        print(f'{kind} {oct(mode & 0o7777)[2:]:>4} {len(data):>9,}  {name}')
    print(f'-- {len(hits)} / {len(entries)} 条')


def find(entries, path):
    for name, mode, data in entries:
        if name == path or name.endswith('/' + path):
            return name, mode, data
    return None, None, None


def cmd_cat(path, target):
    info = read_img(path)
    entries = parse_cpio(get_ramdisk(info))
    name, mode, data = find(entries, target)
    if name is None:
        sys.exit(f'未找到 {target}')
    print(f'=== {name}  mode={oct(mode)} size={len(data)} ===')
    sys.stdout.write(data.decode('utf-8', 'replace'))


# 本项目里「一定要在镜像里」的东西
REQUIRED = [
    'twres/pages/advanced.xml',
    'twres/pages/fox.xml',
    'twres/resources/images.xml',
    'twres/resources/vars.xml',
    'twres/languages/zh_CN.xml',
    'sbin/fox_resize_system.sh',
    'sbin/fox_sysinfo.sh',
]

# 不该出现的（删掉的功能）
FORBIDDEN = [
    'twres/pages/fox_addons.xml',   # 已并入 advanced
]


def cmd_check(path):
    info = read_img(path)
    entries = parse_cpio(get_ramdisk(info))
    names = {n for n, _, _ in entries}
    ok = True
    print(f'== {os.path.basename(path)} ==')
    for r in REQUIRED:
        if r in names:
            print(f'  [OK]   {r}')
        else:
            print(f'  [MISS] {r}')
            ok = False
    for f in FORBIDDEN:
        if f in names:
            print(f'  [BAD]  {f} 不应存在')
            ok = False

    # 关键内容抽查
    checks = [
        ('twres/pages/advanced.xml', ['晓宇插件', 'NoksuEXT4.zip', 'NoksuEROFS.zip']),
        ('twres/pages/fox.xml', ['重启 Recovery', '%btn_raised_left_x%']),
        ('sbin/fox_resize_system.sh', ['ACTUAL_FSTYPE', '832']),
    ]
    for target, needles in checks:
        name, _, data = find(entries, target)
        if not name:
            continue
        txt = data.decode('utf-8', 'replace')
        for needle in needles:
            if needle in txt:
                print(f'  [OK]   {target} 含 "{needle}"')
            else:
                print(f'  [MISS] {target} 缺 "{needle}"')
                ok = False

    print('结果:', 'PASS' if ok else 'FAIL')
    return 0 if ok else 1


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    cmd, img = sys.argv[1], sys.argv[2]
    if cmd == 'info':
        cmd_info(img)
    elif cmd == 'ls':
        cmd_ls(img, sys.argv[3] if len(sys.argv) > 3 else '')
    elif cmd == 'cat':
        if len(sys.argv) < 4:
            sys.exit('需要 <path>')
        cmd_cat(img, sys.argv[3])
    elif cmd == 'check':
        sys.exit(cmd_check(img))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
