# 补丁说明

5 个补丁，作用于 OrangeFox `fox_12.1` 的 `bootable/recovery`。

## 顺序

`0001` → `0005` 顺序应用即可。补丁之间文件不重叠，理论上任意顺序都行，但按编号来最稳。

```bash
cd ~/fox_12.1/bootable/recovery
bash /path/to/repo/scripts/apply_patches.sh
```

只检查不落地：

```bash
bash /path/to/repo/scripts/apply_patches.sh --check
```

## 清单

| 文件 | 行数 | 涉及文件 | 主题 |
|---|---|---|---|
| `0001-scroll-list.patch` | 258 | `gui/scrolllist.cpp` `gui/listbox.cpp` `gui/objects.hpp` `gui/fileselector.cpp` | 列表回弹 / 进页面被拉到底 |
| `0002-partition-expand.patch` | 511 | `partition.cpp` `partitions.hpp` `partitionmanager.cpp` | 扩容、格式化 Data、F2FS、强制卸载 |
| `0003-recovery-core.patch` | 358 | `recovery_main.cpp` `twrp.cpp` `twrp-functions.cpp` `data.cpp` `gui/gui.cpp` `orangefox.mk` `sepolicy/twrp.te` | BCB 重启、时区、手电筒、f2fs 开关 |
| `0004-theme-ui.patch` | 20118 | `gui/theme/portrait_hdpi/**` | 页面布局、字体、坐标、图片 |
| `0005-languages.patch` | 930 | `gui/theme/common/languages/**` `extra-languages/**` | 词条改名 |

`0004` 体积大是因为包含 PNG（关于页整屏插画、启动图）。

## 基线

基于 `fox_12.1` 的 `bootable/recovery`：

```
commit 8cd9df2b4  Fix thermal sensor reading/unsigned integer wrap for cpu temperature
```

上游若已前进，`git apply --3way` 通常能合；冲突集中在：

- `gui/theme/portrait_hdpi/pages/advanced.xml`（本项目重写了整页）
- `partition.cpp`（上游改动频繁）
- `orangefox.mk`

冲突时以「本项目的行为」为准，参考 `docs/技术细节.md` 里每处改动的目的。

## 与设备树的关系

有些改动**不在补丁里**，在 `device/xiaomi/sagit/`：

- 扩容脚本 `recovery/root/sbin/fox_resize_system.sh`
- 分区表 `recovery.fstab`
- 分区尺寸与 `OF_*` 开关 `BoardConfig.mk`
- reboot helper `foxb_reboot.c`

这些随设备树一起复制即可，无需打补丁。
