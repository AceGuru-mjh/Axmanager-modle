<div align="center">

# AXManager 插件合集

**38 个免 Root 系统工具插件 · ADB Shell · Material 3 WebUI**

[![Plugins](https://img.shields.io/badge/插件-38-ff6b35?style=for-the-badge)](https://github.com/AceGuru-mjh/Axmanager-modle/releases/latest)
[![Release](https://img.shields.io/github/v/release/AceGuru-mjh/Axmanager-modle?style=for-the-badge&color=2ea043&label=最新版本)](https://github.com/AceGuru-mjh/Axmanager-modle/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/AceGuru-mjh/Axmanager-modle/total?style=for-the-badge&color=0969da&label=总下载)](https://github.com/AceGuru-mjh/Axmanager-modle/releases)

[![Root](https://img.shields.io/badge/Root-不需要-2ea043?style=flat-square)](#能力边界重要)
[![Mode](https://img.shields.io/badge/模式-ADB%20%2F%20Shell-ff6b35?style=flat-square)](#能力边界重要)
[![UI](https://img.shields.io/badge/WebUI-Material%203-8957e5?style=flat-square)](https://m3.material.io/)
[![Platform](https://img.shields.io/badge/Platform-Android%208.0%2B-3ddc84?style=flat-square)](https://www.android.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Build](https://github.com/AceGuru-mjh/Axmanager-modle/actions/workflows/build-release.yml/badge.svg?style=flat-square)](https://github.com/AceGuru-mjh/Axmanager-modle/actions/workflows/build-release.yml)

</div>

---

一套面向 **AxManager（免 Root 插件体系）** 的系统工具插件。全部插件只使用
`shell(uid 2000)` 权限下真实可用的接口，**不伪装 root 能力**，所有改动均有回滚日志。

<details open>
<summary><b>目录</b></summary>

- [这个版本做了什么](#这个版本做了什么)
- [能力边界](#能力边界重要)
- [插件列表](#插件列表)
- [快速开始](#快速开始)
- [目录结构](#目录结构)
- [开发一个插件](#开发一个插件)
- [技术说明](#技术说明)

</details>

---

## 这个版本做了什么

v2 是对整个仓库的一次重写，而不是增补。改动集中在四件事：

### 1. 修正结构，让插件真正被 AxManager 识别

| 问题 | 旧版本 | v2 |
|------|--------|-----|
| WebUI 目录 | `web/`（**25 个插件用错**） | `webroot/`（AxManager 规范） |
| 模块 id | 目录名与 `id=` 不一致（如 `plugin_ad_block` / `ad_block_ax`） | 二者强制一致 |
| 生命周期 | 只有部分插件有 `uninstall.sh`，无 `action.sh` / `service.sh` | 全部补齐，统一由模板同步 |
| 安装校验 | 无 | `customize.sh` 校验 API 等级与宿主环境 |

> `web/` → `webroot/` 是硬伤：AxManager 只从 `webroot/index.html` 读取界面，
> 旧版本这 25 个插件的 WebUI **根本不会显示**。

### 2. 删掉无效代码，改用真实生效的接口

旧版本大量使用 `setprop persist.cpu.governor performance` 之类的自造属性——
这些属性**没有任何系统组件读取**，且 `persist.*` 对 shell 受 SELinux `neverallow` 限制，
**写入即失败，也不会有任何效果**。v2 全部替换为有据可查的官方接口：

```
✗ setprop persist.cpu.governor      →  ✓ cmd power set-fixed-performance-mode-enabled
✗ setprop persist.cpu.freq.max      →  ✓ cmd thermalservice override-status
✗ 写 /sys/devices/system/cpu/*      →  ✓ settings global cached_apps_freezer
✗ 写 /proc/sys/vm/swappiness        →  ✓ device_config activity_manager max_cached_processes
✗ 写 /system/etc/hosts              →  ✓ settings global private_dns_mode
```

### 3. 补齐安全性与可逆性

- **关键组件保护名单** —— SystemUI、设置、电话、输入法等永不被冻结/卸载
  （旧版本无此保护，存在把设备冻结到无法操作的风险）
- **回滚日志** —— 每一次写入都记录修改前的原值，一键精确还原
- **开机自恢复** —— `service.sh` 在 BOOT_COMPLETED 后重放上次档位
  （旧版本每次重启都要手动重设）
- **回读校验** —— 每次写入后重新读取，被系统拒绝时如实提示，而不是假装成功

### 4. 统一 WebUI

38 份重复的 HTML 收敛为一套 **Material 3 Expressive** 设计系统 + 声明式渲染引擎。

同时修复了一个隐蔽缺陷：旧 CSS 中大量 `var(--p)22` 这类写法**不是合法 CSS**
（`var()` 无法与字面量拼接），意味着此前所有半透明配色、毛玻璃与描边全都未生效。

---

## 能力边界（重要）

免 Root 是有明确上限的。下表说明哪些能做、哪些不能。

<details>
<summary><b>做不到（需要 root）</b> —— 点击展开</summary>

| 能力 | 原因 |
|------|------|
| CPU 调速器 / 频率上下限 | `/sys/devices/system/cpu/*/cpufreq/*` 属主 root |
| 核心上下线 | `/sys/devices/system/cpu/cpuN/online` 不可写 |
| GPU 频率 / devfreq | `/sys/class/kgsl`、`/sys/.../devfreq` 需 root |
| Swap / ZRAM 大小 / swappiness | `/proc/sys/vm/`、`/sys/block/zram0` 不可写 |
| TCP 拥塞算法与缓冲区 | `/proc/sys/net/` 不可写 |
| 修改 `/system/etc/hosts` | 系统分区只读 |
| 蓝牙音频编码器与码率 | 由蓝牙协议栈与厂商属性控制 |
| 进程 OOM 优先级锁定 | `/proc/<pid>/oom_score_adj` 不可写 |
| 读取 `/data/data/<包名>` | 权限 0700，属主为应用自身 |
| 充电电流 / 充电阈值 | 由内核充电 IC 驱动控制 |

插件不会假装实现这些能力，而是在界面上如实说明并给出等效替代方案。

</details>

<details>
<summary><b>做得到（shell 身份真实可用）</b> —— 点击展开</summary>

- `settings put global / system / secure` —— adb shell 拥有写入权限
- `device_config put` —— Android 10+ 运行时特性开关
- `appops set` —— 应用操作级授权管控
- `pm disable-user / enable` —— 可逆停用应用与组件
- `am set-standby-bucket`、`am kill`、`am force-stop`
- `cmd power` / `cmd thermalservice` / `cmd notification` / `cmd package`
- `svc wifi|data|bluetooth|nfc|power`、`wm`、`input`、`screencap`、`screenrecord`
- `dumpsys` / `logcat` / `/proc` 只读采集

</details>

---

## 插件列表

<!-- STATS:START -->
当前共 **39** 个插件，分为 7 类：

![⚙️ 系统调优](https://img.shields.io/badge/%E2%9A%99%EF%B8%8F%20%E7%B3%BB%E7%BB%9F%E8%B0%83%E4%BC%98-7-orange?style=flat-square) ![🌐 网络优化](https://img.shields.io/badge/%F0%9F%8C%90%20%E7%BD%91%E7%BB%9C%E4%BC%98%E5%8C%96-4-orange?style=flat-square) ![🎨 显示与音频](https://img.shields.io/badge/%F0%9F%8E%A8%20%E6%98%BE%E7%A4%BA%E4%B8%8E%E9%9F%B3%E9%A2%91-4-orange?style=flat-square) ![📦 应用管理](https://img.shields.io/badge/%F0%9F%93%A6%20%E5%BA%94%E7%94%A8%E7%AE%A1%E7%90%86-7-orange?style=flat-square) ![🛠 系统工具](https://img.shields.io/badge/%F0%9F%9B%A0%20%E7%B3%BB%E7%BB%9F%E5%B7%A5%E5%85%B7-6-orange?style=flat-square) ![🧩 扩展插件](https://img.shields.io/badge/%F0%9F%A7%A9%20%E6%89%A9%E5%B1%95%E6%8F%92%E4%BB%B6-4-orange?style=flat-square) ![✨ 新增玩法](https://img.shields.io/badge/%E2%9C%A8%20%E6%96%B0%E5%A2%9E%E7%8E%A9%E6%B3%95-7-orange?style=flat-square)

<!-- STATS:END -->

<!-- PLUGINS:START -->
> 点击**模块名**即可下载对应的 zip（当前版本 `v2.1.0`）；
> 也可前往 [Releases 页面](https://github.com/AceGuru-mjh/Axmanager-modle/releases/latest) 一次性下载全部。

### ⚙️ 系统调优

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**charge_thermal_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/charge_thermal_ax.zip) | 覆盖温控节流档位、省电触发阈值与充电保持唤醒（充电电流需 root） | `thermalservice` `low_power` `实时电流` |
| [**cpu_tuner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/cpu_tuner_ax.zip) | 以官方 power / thermalservice 接口调节调度与节流，附 ART 预编译提速 | `cmd power` `thermalservice` `冻结器` |
| [**doze_tuner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/doze_tuner_ax.zip) | 以 standby bucket 与后台运行权限管控待机耗电，通讯应用自动豁免 | `standby bucket` `appops` `白名单` |
| [**gpu_tune_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/gpu_tune_ax.zip) | 调节屏幕刷新率上限与合成负载，替代无效的免 root GPU 超频 | `peak_refresh_rate` `自适应刷新率` `60/120Hz` |
| [**memory_cleaner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/memory_cleaner_ax.zip) | trim-caches 回收 + 后台进程清理 + 临时文件清理，含只读分析模式 | `trim-caches` `am kill` `/data/local/tmp` |
| [**sensor_tuner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/sensor_tuner_ax.zip) | 管控调用传感器的体感功能以降低待机耗电（采样率需 root，已说明） | `doze_pulse` `wake_gesture` `省电` |
| [**swap_tuner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/swap_tuner_ax.zip) | 以缓存进程上限与冻结器调节内存压力（ZRAM 需 root，已如实说明） | `activity_manager` `freezer` `trim-caches` |

### 🌐 网络优化

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**bluetooth_audio_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/bluetooth_audio_ax.zip) | 蓝牙开关、后台扫描、媒体与 SCO 音量、声道平衡（编解码需 root） | `svc bluetooth` `media volume` `master_balance` |
| [**network_optimize_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/network_optimize_ax.zip) | 私有 DNS (DoT) / 息屏网络策略 / 后台扫描管控（TCP 参数需 root） | `Private DNS` `DoT` `wifi_sleep_policy` |
| [**proxy_switch_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/proxy_switch_ax.zip) | 系统级 HTTP 代理切换与排除列表管理，支持自定义与一键直连 | `http_proxy` `排除列表` `抓包` |
| [**wifi_boost_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/wifi_boost_ax.zip) | 减少系统断网与自动切网行为，提升实际可用体验（信号强度需 root） | `wifi_sleep_policy` `watchdog` `avoid_bad_wifi` |

### 🎨 显示与音频

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**audio_balance_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/audio_balance_ax.zip) | 各音频流音量、左右声道平衡与触感反馈控制 | `media volume` `master_balance` `7 个音频流` |
| [**display_color_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/display_color_ax.zip) | 亮度 / 自动亮度 / 夜间色温 / 灰度 / 色彩反转（饱和度需 root） | `night_display` `灰度` `色彩反转` |
| [**reading_mode_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/reading_mode_ax.zip) | 灰度显示、夜间色温、色彩反转与亮度组合的护眼方案 | `灰度显示` `night_display` `色彩反转` |
| [**ui_customizer_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/ui_customizer_ax.zip) | 状态栏图标显隐、字号与字重、暗色模式与通知音效选择，全部可逆 | `icon_blacklist` `font_scale` `ui_night_mode` |

### 📦 应用管理

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**apk_manager_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/apk_manager_ax.zip) | 导出已安装 APK、审计危险权限、查看应用清单（系统应用卸载需 root） | `pm path` `权限审计` `批量导出` |
| [**app_backup_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/app_backup_ax.zip) | 备份 APK 与公共存储数据，恢复时重新安装并还原（私有数据需 root） | `pm path` `tar 打包` `单应用/全量` |
| [**app_freeze_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/app_freeze_ax.zip) | 扫描并冻结厂商/运营商预装与广告上报组件，关键系统组件受保护 | `pm disable-user` `保护名单` `可逆` |
| [**boot_control_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/boot_control_ax.zip) | 组件级停用 BOOT_COMPLETED 接收器，应用仍可手动打开，可一键恢复 | `query-intent-receivers` `组件级` `白名单` |
| [**notification_control_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/notification_control_ax.zip) | 悬浮通知 / 免打扰 / 单应用通知权限批量管控，通讯应用豁免 | `set_dnd` `POST_NOTIFICATION` `API 33+` |
| [**process_guard_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/process_guard_ax.zip) | 进程占用排行、按 PID/包名结束进程、降低回收概率（锁定 OOM 需 root） | `ps 排行` `am kill` `关键进程保护` |
| [**storage_cleaner_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/storage_cleaner_ax.zip) | 缓存回收、临时文件清理与占用分析（私有缓存需 root，已说明） | `trim-caches` `占用分析` `日志清理` |

### 🛠 系统工具

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**adb_toolbox_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/adb_toolbox_ax.zip) | 截图、录屏、DPI/分辨率、网络开关、重启 SystemUI 与设备信息 | `screencap` `screenrecord` `wm` |
| [**game_toolbox_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/game_toolbox_ax.zip) | 为游戏准备运行环境：高性能调度、节流、免打扰、释放内存（画质由游戏决定） | `fixed perf mode` `DND` `温控覆盖` |
| [**gps_optimizer_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/gps_optimizer_ax.zip) | 定位模式、定位源与扫描辅助开关（GPS 更新频率需 root，已说明） | `location_mode` `providers` `扫描辅助` |
| [**logcat_toolbox_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/logcat_toolbox_ax.zip) | 按级别/标签/关键词过滤日志，导出日志与系统诊断信息 | `logcat` `标签过滤` `导出文件` |
| [**ota_guard_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/ota_guard_ax.zip) | 扫描并停用系统与厂商的 OTA / FOTA 更新组件，可随时恢复 | `pm disable-user` `GMS 组件级` `保护名单` |
| [**system_monitor_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/system_monitor_ax.zip) | CPU / 内存 / 电池 / 存储 / 网络速率实时仪表盘，含截图与缓存回收 | `/proc 采样` `dumpsys` `3s 刷新` |

### 🧩 扩展插件

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**ad_block_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/ad_block_ax.zip) | 过滤型私有 DNS 拦截 + 停用广告追踪组件（hosts 需 root，已说明） | `DoT 拦截` `组件停用` `自定义 DNS` |
| [**background_optimize_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/background_optimize_ax.zip) | 待机分组、后台运行与唤醒锁管控，通讯应用白名单豁免 | `standby bucket` `WAKE_LOCK` `白名单` |
| [**game_gpu_tune_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/game_gpu_tune_ax.zip) | 识别已安装游戏并做 AOT 编译与豁免，配合刷新率与温控策略 | `speed 编译` `自动识别` `刷新率` |
| [**system_ui_tweak_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/system_ui_tweak_ax.zip) | 沉浸全屏、显示密度、导航栏布局与状态栏微调，全部可逆 | `immersive` `wm density` `nav_bar` |

### ✨ 新增玩法

| 模块 | 说明 | 技术点 |
|------|------|--------|
| [**app_ops_manager_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/app_ops_manager_ax.zip) | 基于 appops 对单个应用的单项操作授权进行查询、拒绝与恢复 | `appops` `单项管控` `操作名速查` |
| [**auto_input_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/auto_input_ax.zip) | 文本输入、按键事件、坐标点击与滑动，实现免 root 的简易自动化 | `input text` `keyevent` `tap/swipe` |
| [**battery_guardian_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/battery_guardian_ax.zip) | 省电阈值、自适应电池、唤醒锁与待机分组组合的续航方案 | `low_power` `WAKE_LOCK` `batterystats` |
| [**device_info_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/device_info_ax.zip) | 只读汇总机型、系统、硬件、电池与运行环境信息，可导出存档 | `只读` `getprop` `传感器` |
| [**quick_settings_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/quick_settings_ax.zip) | Wi-Fi / 数据 / 蓝牙 / NFC / 飞行模式 / 旋转等系统开关集中控制 | `svc` `飞行模式` `自动旋转` |
| [**thermal_monitor_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/thermal_monitor_ax.zip) | 读取真实温区温度与节流状态，支持手动覆盖节流档位 | `thermalservice` `温区读取` `节流覆盖` |
| [**traffic_stats_ax**](https://github.com/AceGuru-mjh/Axmanager-modle/releases/download/v2.1.0/traffic_stats_ax.zip) | 接口级流量统计、实时速率与按 UID 用量排行（统计无法重置） | `/proc/net/dev` `netstats` `实时速率` |

<!-- PLUGINS:END -->

---

## 快速开始

1. 安装 [AxManager](https://github.com/fahrez182/AxManager) 并完成 ADB 授权
2. 从上方插件列表**点击模块名**下载 zip
3. AxManager → 插件 → 导入，选择 zip
4. 在插件列表中打开 **WebUI**，选档位后应用

所有改动都记录在模块目录的 `.state/journal.tsv`，点击「一键回滚」可精确还原；
卸载插件时会先自动回滚再移除。

---

## 目录结构

```
Axmanager-modle/
├── common/                      # 共享层（不重复 38 遍）
│   ├── axcore.sh                # Shell 核心库：写入+回读校验、回滚日志、JSON 输出
│   ├── dispatch.sh              # 命令分发器：apply/revert/current/action/reapply/status
│   ├── webroot/
│   │   ├── ax-ui.css            # Material 3 Expressive 设计系统
│   │   └── ax-ui.js             # ksu 桥接 + 声明式渲染引擎
│   └── templates/               # 生命周期脚本模板（由构建器注入各插件）
│       ├── customize.sh
│       ├── action.sh
│       ├── service.sh
│       ├── uninstall.sh
│       └── index.html
├── plugins/                     # 每个插件仅 2 个文件
│   └── <plugin_id>/
│       ├── plugin.json          # 元数据 + WebUI 声明式配置
│       └── api.sh               # 业务逻辑
├── tools/
│   ├── build.mjs                # 构建：校验 → 生成模块目录 → 打包 zip
│   ├── check.sh                 # 静态校验：语法 / 换行 / 结构 / 完整性
│   └── gen-readme.mjs           # 由 plugin.json 生成本文插件清单
├── .github/workflows/
│   └── build-release.yml        # 构建并发布到 GitHub Releases
├── dist/                        # 构建产物（未入库）
└── releases/                    # 可直接刷入的 zip
```

---

## 开发一个插件

**只需要写 2 个文件**，公共部分由构建器注入。

### 1. plugin.json

```jsonc
{
  "id": "my_plugin",              // 必须与目录名完全一致
  "name": "我的插件",
  "version": "2.0.0",
  "versionCode": 20,              // 整数，用于版本比较
  "author": "MJH",
  "axeronPlugin": 1,              // 需 ≤ 宿主 AxManager 服务器版本
  "category": "系统调优",
  "summary": "一句话说明",
  "description": "module.prop 中的描述，单行",
  "subtitle": "WebUI 副标题",
  "accent": "#818cf8",            // 主题色
  "accent2": "#a855f7",
  "chips": ["接口1", "接口2"],
  "ui": {
    "profileId": "profile",
    "sections": [ /* 见下 */ ]
  }
}
```

### 2. api.sh

```sh
#!/system/bin/sh
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    performance)
        ax_set_global low_power 0              # settings put global
        ax_devcfg activity_manager max_cached_processes 128
        ;;
    balanced)
        ax_set_global low_power 0
        ;;
    *) return 1 ;;
    esac
    return 0
}

ax_custom() {                                  # 可选：自定义动词
    case "$1" in
    info) ax_info "自定义输出"; ax_result ok ;;
    *) return 1 ;;
    esac
}

ax_status() {                                  # 可选：状态 JSON
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
```

<details>
<summary><b>axcore.sh 提供的能力</b> —— 点击展开</summary>

| 函数 | 说明 |
|------|------|
| `ax_set_global/set_system/set_secure <k> <v>` | 写入 settings 并**回读校验**，失败如实报告 |
| `ax_setprop <k> <v>` | 写入属性并校验（多数属性会失败，会提示跳过） |
| `ax_devcfg <ns> <k> <v>` | `device_config` 写入（API 29+） |
| `ax_pkg_disable / ax_pkg_enable <pkg>` | 可逆停用（内置关键组件保护） |
| `ax_comp_disable / ax_comp_enable <comp>` | 组件级停用 |
| `ax_appops <pkg> <op> <mode>` | appops 设置 |
| `ax_revert_all` | 按日志回滚全部改动 |
| `ax_profile_save / ax_profile_load` | 档位记忆（供开机自恢复） |
| `ax_json_begin / ax_json_kv / ax_json_end` | 输出 JSON 给 WebUI |
| `ax_ok / ax_err / ax_warn / ax_info / ax_step` | 结构化输出（WebUI 自动着色） |
| `ax_result ok\|fail` | 供 WebUI 判断成败 |

</details>

<details>
<summary><b>UI section 类型</b> —— 点击展开</summary>

| type | 用途 |
|------|------|
| `note` | 说明卡片（用于交代能力边界） |
| `profiles` | 档位选择卡（需 api.sh 实现 `apply_profile`） |
| `actions` | 动作按钮网格（对应 `ax_custom` 分支） |
| `metrics` | 实时数值卡片（需 `ax_status`） |
| `list` | 列表（输出格式 `标题\|副标题\|徽标\|类型`） |
| `switches` | 开关行 |
| `input` | 输入框 + 按钮（空格分隔为多参数） |
| `slider` / `html` | 滑块 / 自定义 HTML |

</details>

### 3. 构建

```bash
node tools/build.mjs              # 构建全部
node tools/build.mjs cpu_tuner_ax # 构建单个
bash tools/check.sh               # 静态校验
node tools/gen-readme.mjs         # 更新本文档的插件清单
```

构建器会在打包前做静态校验，包括：`id` 与目录名一致、`axeronPlugin` 存在、
声明的每个档位在 `apply_profile` 中都有分支、UI 引用的每个动词在 `ax_custom`
中都有处理、声明了 `metrics` 就必须实现 `ax_status`。**不合规直接报错退出**。

---

## 技术说明

- **运行时**：AxManager 插件环境（BusyBox ash，独立 Shell 模式）
- **换行**：所有 `.sh` / `.prop` / `.html` 强制 UNIX LF（`module.prop` 用 CRLF 会导致 `versionCode` 解析失败）
- **脚本规范**：纯 POSIX sh，不使用 bash 专有语法
- **WebUI**：`ksu.exec(cmd, options, callback)` 异步三参数形式，兼容同步降级
- **CI**：推送 `v*` tag 自动构建并发布到 [Releases](https://github.com/AceGuru-mjh/Axmanager-modle/releases)

---

<div align="center">

**如果这个项目对你有帮助，欢迎点个 Star**

[![Star](https://img.shields.io/github/stars/AceGuru-mjh/Axmanager-modle?style=social)](https://github.com/AceGuru-mjh/Axmanager-modle)

开发者 **MJH** · [@AceGuru-mjh](https://github.com/AceGuru-mjh) · MIT License

</div>
