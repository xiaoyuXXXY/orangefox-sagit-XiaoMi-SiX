# 许可说明

本仓库内容来自不同来源，按目录分别适用不同许可。

---

## device/xiaomi/sagit/

**Apache License 2.0**

衍生自 OrangeFox Recovery 官方 sagit 设备树（`android_device_xiaomi_sagit`，Copyright (C) 2018–2020 OrangeFox Recovery Project），并做了针对本项目的修改（分区尺寸、fstab、sbin 脚本、产品配置等）。

原始许可头保留在各源文件顶部。

## patches/

**GNU General Public License v3.0**

补丁作用于 `bootable/recovery`（OrangeFox / TWRP 衍生，GPL-3.0）。补丁作为该作品的衍生部分，同样适用 GPL-3.0。

全文：https://www.gnu.org/licenses/gpl-3.0.txt

## prebuilt/Image*.gz-dtb

内核镜像版权归各自作者（Xiaomi 及第三方内核作者）。这些文件仅用于编译本设备的 recovery，未做修改，随设备树一并分发以便复现。

## docs/ 、README.md

**CC BY-SA 4.0**（署名—相同方式共享）

可自由转载、修改，需署名并以相同许可分发。

## scripts/ 、build/

**MIT**

```
Copyright (c) 2026 Xiaoyu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 免责声明

刷机有风险。扩容会清空 Data。本项目按「现状」提供，不提供任何担保；因使用本仓库内容导致的设备损坏、数据丢失，作者不承担责任。
