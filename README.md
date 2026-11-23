# OrangeFox Recovery 12.1 · Xiaomi Mi 6 (sagit)

小米 6（sagit）的 OrangeFox 12.1 定制 recovery —— **从 V1 到 V48 的完整源码、补丁与开发记录**。

这个仓库不是一份「改好的成品」，而是一份**可以照着复现的全部材料**：设备树、对上游的每一处改动（拆成 5 个可单独应用的补丁）、编译脚本、镜像校验脚本，以及踩过的每一个坑。

| 项目 | 内容 |
|---|---|
| 设备 | Xiaomi Mi 6（`sagit`）· 骁龙 835（MSM8998）· A-only · 4Kn 逻辑扇区 |
| 基线 | OrangeFox R12.0/R12.1（`fox_12.1`，Android 12.1） |
| 内核 | 4.4（prebuilt `Image.gz-dtb`，三个版本随设备树附带） |
| 开发周期 | 2026-11-20 → 2026-11-23，83 个版本节点 |
| 最终产物 | `OrangeFox-sagit-V48.img`，44 MB，MD5 `54176b6dbbda336bf7c4f1c232d2a994` |

一句话概括：**把一台 2017 年的手机，用 2026 年的 Recovery 源码，从「能开机」做到「能日用」，再做到「无致命 bug」，最后把扩容、插件化、内核工具全部收进一个正式发布版。**

![V48 界面](screenshots/v48-ui.png)

---

## 目录结构

```
.
├── device/xiaomi/sagit/        设备树（完整，直接放进源码树即可编译）
│   ├── BoardConfig.mk          分区尺寸、内核参数、4Kn 扇区设置
│   ├── twrp_sagit.mk           产品配置（keystore / gatekeeper 名字）
│   ├── recovery.fstab          分区表（已删 splash 条目）
│   ├── prebuilt/               三个 4.4 内核 Image.gz-dtb
│   └── recovery/root/sbin/     ★ 扩容脚本、系统信息脚本、静态 reboot
├── patches/                    对 bootable/recovery 的 5 个补丁（按主题拆分）
├── build/                      编译与清理脚本
├── scripts/                    镜像校验、补丁应用
├── docs/                       开发全记录、扩容方案、疑难杂症、构建指南、技术细节
└── screenshots/                V48 界面与版本总览
```

---

## 快速开始

```bash
# 1. 同步 fox_12.1 源码（约 60–80 GB，视网速 1–3 小时）
mkdir -p ~/OrangeFox_sync && cd ~/OrangeFox_sync
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 12.1 --path ~/fox_12.1

# 2. 放入设备树
cp -a /path/to/this-repo/device/xiaomi/sagit ~/fox_12.1/device/xiaomi/

# 3. 打补丁
cd ~/fox_12.1/bootable/recovery
for p in /path/to/this-repo/patches/*.patch; do git apply "$p" || echo "FAILED: $p"; done

# 4. 编译
cd ~/fox_12.1
bash /path/to/this-repo/build/build.sh

# 5. 校验产物
python3 /path/to/this-repo/scripts/verify_img.py \
        out/target/product/sagit/OrangeFox-R12.0-Unofficial-sagit.img
```

详细步骤、依赖安装、常见编译错误见 **[docs/构建指南.md](docs/构建指南.md)**。

---

## 补丁清单

补丁按「一处逻辑一组」拆分，互不重叠，可以单独应用、单独阅读。

| 补丁 | 文件 | 解决什么 |
|---|---|---|
| `0001-scroll-list.patch` | `gui/scrolllist.cpp` `gui/listbox.cpp` `gui/objects.hpp` `gui/fileselector.cpp` | 列表回弹、进入页面被拉到底部、组内边距被算进滚动范围 |
| `0002-partition-expand.patch` | `partition.cpp` `partitions.hpp` `partitionmanager.cpp` | System 扩容、格式化 Data、F2FS/EXT4 能力探测、卸载重试 |
| `0003-recovery-core.patch` | `recovery_main.cpp` `twrp.cpp` `twrp-functions.cpp` `data.cpp` `gui/gui.cpp` `orangefox.mk` `sepolicy/twrp.te` | 重启到 Recovery 走完整启动、reboot 生效、默认时区、手电筒轻点、f2fs 兼容开关 |
| `0004-theme-ui.patch` | `gui/theme/portrait_hdpi/**` | 晓宇插件页、扩容页、启动页、关于页、坐标与字体 |
| `0005-languages.patch` | `gui/theme/common/languages/**` `extra-languages/**` | 32 个语言包统一改词条（`fox_modules_hdr` → 晓宇插件） |

> 补丁基于 `fox_12.1` 的 `bootable/recovery`（commit `8cd9df2b4` 前后）。若上游有更新，先 `git log` 对齐再应用。

---

## 这个包做了什么

### 1. 系统分区扩容（5–12 GB）

从 `userdata` 头部切空间给 `system`，`cust` 重建为 832 MiB，`data` 整体后移。九档实测：

| 标称 | 可用 | 占标称 | 较上一档 |
|---|---|---|---|
| 5 GB（原厂） | 4895 MB | 97.2% | — |
| 6 GB | 5887 MB | 95.8% | — |
| 7 GB | 6879 MB | 96.0% | +992 |
| 8 GB | 7871 MB | 96.1% | +992 |
| 9 GB | 8863 MB | 96.2% | +992 |
| 10 GB | 9855 MB | 96.2% | +992 |
| 11 GB | 10847 MB | 96.3% | +992 |
| 12 GB | 11839 MB | 96.3% | +992 |

每加 1 GB 精确多 992 MB，六次完全一致 —— 那 3.7% 是 4Kn 对齐与文件系统元数据的**固定开销**，不是误差。

写完分区表立即校验 `system` / `cust` / `userdata` 三块，缺一块自动 `load-backup` 回滚。这种失败下 Data 完好。

### 2. 晓宇插件

原来的「Fox 插件」整页并入，改成三段式分组（系统工具 / 插件 / 用户模块），主菜单精简。所有 zip 统一放 `/sdcard/Fox/XiaoyuFiles/`，找不到自动切 `/data/media/Fox/XiaoyuFiles/`。

- 一键内核宽容 → `Permissiver.zip`
- 卸载内核-EXT4 → `NoksuEXT4.zip`
- 卸载内核-EROFS → `NoksuEROFS.zip`
- 安装 SukiSU / 安装 Magisk

### 3. 默认中文与解密

`fileencryption=ice` + qseecomd / keymaster / gatekeeper 补齐 FBE 解密链；默认语言三道保险（编译默认值 / 无选择时反向强制 / 语言页记录），格式化 Data 之后也不会变回英文。

### 4. 交互细节

- 「重启到 Recovery」走完整启动流程（BCB 写 `boot-recovery`，进 recovery 先清标记防循环）
- zip 刷机脚本里的 `reboot` 真的会重启（静态 `foxb_reboot` 直连内核 syscall + `/sbin/reboot` 包装 + sepolicy 兜底）
- 音量上 + 电源轻点切换手电筒
- 列表装得下就不许滚动（解决回弹）

---

## 产物

| 文件 | 大小 | MD5 |
|---|---|---|
| `OrangeFox-sagit-V48.img` | 44 MB | `54176b6dbbda336bf7c4f1c232d2a994` |

V48 是 recovery 镜像本体；含签名与附加文件的完整卡刷包在此基础上打包。

---

## 已知限制

| 限制 | 说明 |
|---|---|
| 三大金刚键不响应 | TWRP 12.1 的 minui 丢弃 `EV_KEY`，上游行为，非本包缺陷 |
| 扩容约 3.7% 容量损耗 | 4Kn 对齐 + 文件系统元数据，固定开销 |
| 大跨度扩容偶发 `exit 3` | 分区表已写入，重启后格式化 Data 即正常，属收尾校验误报 |
| 扩容会清空 Data | 脚本与界面均有红字警告，必须先备份 |
| 5 GB 缩回比原厂少约 80 MB | 分区起止对齐位置变化，一次性差异 |

---

## 许可

- `device/xiaomi/sagit/`：Apache-2.0（衍生自 OrangeFox 官方 sagit 设备树）
- `patches/`：GPL-3.0（与上游 `bootable/recovery` 一致）
- `docs/`、`README.md`：CC BY-SA 4.0
- `prebuilt/` 下的内核镜像版权归各自作者（Xiaomi / 第三方内核作者），仅用于本设备编译，未做修改

详见 [LICENSE.md](LICENSE.md)。

---

## 发布到 GitHub

仓库已经初始化并提交（`main` 分支 + `v48` 标签），直接推即可：

```bash
cd OrangeFox-sagit-Source

# 先在 GitHub 网页建一个空仓库（不要勾 README / .gitignore / license）
git remote add origin git@github.com:<你的用户名>/<仓库名>.git
git push -u origin main
git push origin v48
```

用 `gh` 更省事：

```bash
gh auth login
gh repo create orangefox-sagit --public --source=. --push
git push origin v48
```

> 仓库约 47 MB（其中 35 MB 是三个预编译内核）。不需要预编译内核的话，可以删掉 `device/xiaomi/sagit/prebuilt/` 并在 README 里注明来源，仓库会降到 12 MB。

---

## 更多

| 文档 | 内容 |
|---|---|
| [docs/V1-V48-开发全记录.md](docs/V1-V48-开发全记录.md) | 83 个版本节点、七个阶段、五个值得记住的 bug |
| [docs/扩容方案.md](docs/扩容方案.md) | System 5–12 GB 的完整方案：原理、算法、12 步流程、退出码、回滚、九档实测 |
| [docs/疑难杂症.md](docs/疑难杂症.md) | 按症状查：界面 / 硬件 / 扩容 / 编译，共 40 余条 |
| [docs/构建指南.md](docs/构建指南.md) | 环境依赖、编译、刷机、验证、排错 |
| [docs/技术细节.md](docs/技术细节.md) | 关键改动的代码级说明（滚动、扩容、格式化分支、f2fs 兼容） |
| [docs/OrangeFox-V1-V48-完整记录.pdf](docs/OrangeFox-V1-V48-完整记录.pdf) | 上面五份合并排版（含封面与目录），适合直接转发 |
