<!-- ═══════════════════════════════════════════════════════════════════
     AXManager 插件合集 · README v2
     美化参考 GitHub 社区最佳实践：shields.io 徽章 / emoji 锚点目录 /
     details 折叠面板 / 分栏布局 / 语法高亮代码块
     素材来源：simple-icons · shields.io · komarev/ghpvc
═══════════════════════════════════════════════════════════════════ -->

<div align="center">

<!-- ── Hero 标题区：文字渐变 + 副标题 ─────────────────────────────── -->

<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=32&pause=1000&color=A855F7&center=true&vCenter=true&width=520&lines=AXManager+%E6%8F%92%E4%BB%B6%E5%90%88%E9%9B%86+v2;38+%E4%B8%AA%E5%85%8D+Root+%E7%B3%BB%E7%BB%9F%E5%B7%A5%E5%85%B7;ADB+Shell+%E7%9C%9F%E5%AE%9E%E6%8E%A5%E5%8F%A3+%C2%B7+%E5%85%A8%E9%83%A8%E5%8F%AF%E5%9B%9E%E6%BB%9A" />
    <source media="(prefers-color-scheme: light)" srcset="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=32&pause=1000&color=6750A4&center=true&vCenter=true&width=520&lines=AXManager+%E6%8F%92%E4%BB%B6%E5%90%88%E9%9B%86+v2;38+%E4%B8%AA%E5%85%8D+Root+%E7%B3%BB%E7%BB%9F%E5%B7%A5%E5%85%B7;ADB+Shell+%E7%9C%9F%E5%AE%9E%E6%8E%A5%E5%8F%A3+%C2%B7+%E5%85%A8%E9%83%A8%E5%8F%AF%E5%9B%9E%E6%BB%9A" />
    <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=32&pause=1000&color=6750A4&center=true&vCenter=true&width=520&lines=AXManager+%E6%8F%92%E4%BB%B6%E5%90%88%E9%9B%86+v2;38+%E4%B8%AA%E5%85%8D+Root+%E7%B3%BB%E7%BB%9F%E5%B7%A5%E5%85%B7;ADB+Shell+%E7%9C%9F%E5%AE%9E%E6%8E%A5%E5%8F%A3+%C2%B7+%E5%85%A8%E9%83%A8%E5%8F%AF%E5%9B%9E%E6%BB%9A" alt="AXManager 插件合集 v2 — 打字机动效" />
  </picture>
</h1>

> **38 个免 Root 系统工具插件** · ADB Shell 真实接口 · Material 3 WebUI · 全部可回滚
>
> 一套面向 **AxManager（免 Root 插件体系）** 的系统工具插件。全部插件只使用
> `shell(uid 2000)` 权限下真实可用的接口，不伪装 root 能力，所有改动均有回滚日志。

<!-- ── for-the-badge 主徽章行 ─────────────────────────────────────── -->

[![AXManager][badge-hero]][repo-url]
[![Plugins][badge-plugins]][plugins-dir]
[![Mode][badge-mode]](#%E8%83%BD%E5%8A%9B%E8%BE%B9%E7%95%8C%E9%87%8D%E8%A6%81)
[![UI][badge-ui]](#4%EF%B8%8F%E2%83%A3-%E7%BB%9F%E4%B8%80-webui)
[![Root][badge-root]](#%E8%83%BD%E5%8A%9B%E8%BE%B9%E7%95%8C%E9%87%8D%E8%A6%81)
[![License][badge-license]][license-url]
[![Platform][badge-platform]](#%E6%8A%80%E6%9C%AF%E8%AF%B4%E6%98%8E)

<!-- ── flat-square 品牌图标补充行（simple-icons 配色） ────────────── -->

[![Kotlin][ic-kotlin]][plugins-dir]
[![Shell][ic-shell]][common-dir]
[![Android][ic-android]](#%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B)
[![GitHub Actions][ic-actions]](./.github/workflows/build-release.yml)
[![Material Design][ic-m3]](#4%EF%B8%8F%E2%83%A3-%E7%BB%9F%E4%B8%80-webui)

<br/>

<!-- ── 特性速览：图标网格 ─────────────────────────────────────────── -->

<table>
  <tr>
    <td align="center" width="20%"><img src="https://cdn.simpleicons.org/bash/FFD053" width="42" alt="真实接口"/><br/><b>⚡ 真实接口</b><br/><sub>只用 shell 权限<br/>下真实生效的命令</sub></td>
    <td align="center" width="20%"><img src="https://cdn.simpleicons.org/letsencrypt/F7C943" width="42" alt="组件保护"/><br/><b>🔒 组件保护</b><br/><sub>SystemUI 等关键<br/>组件永不被停用</sub></td>
    <td align="center" width="20%"><img src="https://cdn.simpleicons.org/gnubash/4EAA25" width="42" alt="精确回滚"/><br/><b>↩️ 一键回滚</b><br/><sub>回滚日志记录<br/>原值，精确还原</sub></td>
    <td align="center" width="20%"><img src="https://cdn.simpleicons.org/androidstudio/3DDC84" width="42" alt="开机自恢复"/><br/><b>🔄 开机自恢复</b><br/><sub>service.sh 重放<br/>上次档位</sub></td>
    <td align="center" width="20%"><img src="https://cdn.simpleicons.org/materialdesign/7677DC" width="42" alt="设计系统"/><br/><b>🎨 设计系统</b><br/><sub>Material 3<br/>Expressive WebUI</sub></td>
  </tr>
</table>

</div>

<br/>

<!-- ── 目录：双栏布局 ─────────────────────────────────────────────── -->

<details open>
<summary><h2>📑 目录</h2></summary>

<table>
<tr>
<td width="50%">

- [✨ 这个版本做了什么](#%E8%BF%99%E4%B8%AA%E7%89%88%E6%9C%AC%E5%81%9A%E4%BA%86%E4%BB%80%E4%B9%88)
- [🚧 能力边界（重要）](#%E8%83%BD%E5%8A%9B%E8%BE%B9%E7%95%8C%E9%87%8D%E8%A6%81)
- [🧩 插件列表](#%E6%8F%92%E4%BB%B6%E5%88%97%E8%A1%A838-%E4%B8%AA)
- [📁 目录结构](#%E7%9B%AE%E5%BD%95%E7%BB%93%E6%9E%84)

</td>
<td width="50%">

- [🛠️ 开发一个插件](#%E5%BC%80%E5%8F%91%E4%B8%80%E4%B8%AA%E6%8F%92%E4%BB%B6)
- [🚀 快速开始](#%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B)
- [🧪 构建与校验](#%E6%9E%84%E5%BB%BA%E4%B8%8E%E6%A0%A1%E9%AA%8C)
- [📖 技术说明](#%E6%8A%80%E6%9C%AF%E8%AF%B4%E6%98%8E)
- [🙏 参考与致谢](#%E5%8F%82%E8%80%83%E4%B8%8E%E8%87%B4%E8%B0%A2)
- [📄 License](#license)

</td>
</tr>
</table>

</details>

<br/>

---

<br/>

## ✨ 这个版本做了什么

v2 是对整个仓库的一次**重写**，而不是增补。改动集中在四件事：

<table>
<tr>
<td align="center">1️⃣ <b>修正结构</b><br/>让插件真正被识别</td>
<td align="center">2️⃣ <b>真实接口</b><br/>删掉无效代码</td>
<td align="center">3️⃣ <b>安全可逆</b><br/>保护名单 + 回滚日志</td>
<td align="center">4️⃣ <b>统一 WebUI</b><br/>M3 设计系统</td>
</tr>
</table>

### 1️⃣ 修正结构，让插件真正被 AxManager 识别

| 问题 | 旧版本 | ✅ v2 |
|------|--------|-----|
| WebUI 目录 | `web/`（共 25 个插件用错） | `webroot/`（AxManager 规范） |
| 模块 id | 目录名与 `id=` 不一致（如 `plugin_ad_block` / `ad_block_ax`） | 二者强制一致 |
| 生命周期 | 只有部分插件有 `uninstall.sh`，无 `action.sh` / `service.sh` | 全部补齐，统一由模板同步 |
| 安装校验 | 无 | `customize.sh` 校验 API 等级与宿主环境 |

### 2️⃣ 删掉无效代码，改用真实生效的接口

旧版本大量使用 `setprop persist.cpu.governor performance` 之类的自造属性——
这些属性没有任何系统组件读取，且 `persist.*` 对 shell 受 SELinux `neverallow` 限制，
**写入即失败，也不会有任何效果**。v2 全部替换为有据可查的官方接口：

```diff
- setprop persist.cpu.governor performance   →  cmd power set-fixed-performance-mode-enabled
- setprop persist.cpu.freq.max               →  cmd thermalservice override-status
- 写 /sys/devices/system/cpu/*               →  settings global cached_apps_freezer
- 写 /proc/sys/vm/swappiness                 →  device_config activity_manager max_cached_processes
- 写 /system/etc/hosts                       →  settings global private_dns_mode
```

### 3️⃣ 补齐安全性与可逆性

- 🛡️ 新增**关键组件保护名单**：SystemUI、设置、电话、输入法等永不被冻结/卸载
  （旧版本无此保护，存在把设备冻结到无法操作的风险）
- 📜 新增**回滚日志**：每一次写入都记录修改前的原值，一键精确还原
- 🔁 新增**开机自恢复**：`service.sh` 在 BOOT_COMPLETED 后重放上次档位
  （旧版本每次重启都要手动重设）
- 👁️ 每次写入都**回读校验**，被系统拒绝时如实提示，而不是假装成功

### 4️⃣ 统一 WebUI

38 份重复的 HTML 收敛为一套 **Material 3 Expressive 设计系统** + 声明式渲染引擎。
同时修复了一个隐蔽缺陷：旧 CSS 中大量 `var(--p)22` 这类写法**不是合法 CSS**
（无法把 `var()` 与字面量拼接），意味着此前所有半透明配色、毛玻璃与描边都未生效。

<br/>

---

<br/>

## 🚧 能力边界（重要）

免 Root 是有明确上限的。下表说明哪些能做、哪些不能：

### ❌ 做不到（需要 root）

| 能力 | 原因 |
|------|------|
| CPU 调速器 / 频率上下限 | `/sys/devices/system/cpu/*/cpufreq/*` 权限 0644，属主 root |
| 核心上下线 | `/sys/devices/system/cpu/cpuN/online` 不可写 |
| GPU 频率 / devfreq | `/sys/class/kgsl`、`/sys/.../devfreq` 需 root |
| Swap / ZRAM 大小 / swappiness | `/proc/sys/vm/`、`/sys/block/zram0` 不可写 |
| TCP 拥塞算法与缓冲区 | `/proc/sys/net/` 不可写 |
| 修改 `/system/etc/hosts` | 系统分区只读 |
| 蓝牙音频编码器与码率 | 由蓝牙协议栈与厂商属性控制 |
| 进程 OOM 优先级锁定 | `/proc/<pid>/oom_score_adj` 不可写 |
| 读取 `/data/data/<包名>` | 权限 0700，属主为应用自身 |
| 充电电流 / 充电阈值 | 由内核充电 IC 驱动控制 |

> 💡 对于这些能力，插件不会假装实现，而是在界面上**如实说明**并给出等效替代方案。

### ✅ 做得到（shell 身份真实可用）

<table>
<tr>
<td width="50%">

- ⚙️ `settings put global / system / secure`
- 🎛️ `device_config put` —— Android 10+ 特性开关
- 📱 `appops set` —— 应用操作级授权管控
- 🧊 `pm disable-user / enable` —— 可逆停用

</td>
<td width="50%">

- 📴 `am set-standby-bucket` / `am kill` / `force-stop`
- 🔋 `cmd power` / `thermalservice` / `notification`
- 📡 `svc wifi|data|bluetooth|nfc` / `wm` / `input`
- 📊 `dumpsys` / `logcat` / `/proc` 只读采集

</td>
</tr>
</table>

<br/>

---

<br/>

## 🧩 插件列表（38 个）

<div align="center">

| ⚡ 系统调优 | 🌐 网络优化 | 🎨 显示音频 | 📦 应用管理 | 🔧 系统工具 | 🆕 新增玩法 |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **7** | **5** | **3** | **7** | **7** | **9** |

</div>

<details open>
<summary><b>⚡ 系统调优（7）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`cpu_tuner_ax`](plugins/cpu_tuner_ax) | 调度与性能模式、ART 预编译 | `cmd power` / `thermalservice` / `cmd package compile` |
| [`gpu_tune_ax`](plugins/gpu_tune_ax) | 刷新率与合成负载 | `peak_refresh_rate` / 动画缩放 |
| [`swap_tuner_ax`](plugins/swap_tuner_ax) | 内存水位与后台进程 | `activity_manager` / `cached_apps_freezer` |
| [`memory_cleaner_ax`](plugins/memory_cleaner_ax) | 缓存回收与进程清理 | `pm trim-caches` / `am kill` |
| [`doze_tuner_ax`](plugins/doze_tuner_ax) | 后台行为与待机分组 | `am set-standby-bucket` / `appops` |
| [`charge_thermal_ax`](plugins/charge_thermal_ax) | 充电温控与耗电策略 | `thermalservice` / `low_power_trigger_level` |
| [`battery_guardian_ax`](plugins/battery_guardian_ax) | 电池守护、唤醒锁管控 | `low_power` / `WAKE_LOCK` / `batterystats` |

</details>

<details open>
<summary><b>🌐 网络优化（5）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`network_optimize_ax`](plugins/network_optimize_ax) | 私有 DNS、息屏网络策略 | `private_dns_mode` / `wifi_sleep_policy` |
| [`wifi_boost_ax`](plugins/wifi_boost_ax) | Wi-Fi 保持与扫描策略 | `wifi_watchdog_on` / `avoid_bad_wifi` |
| [`proxy_switch_ax`](plugins/proxy_switch_ax) | 全局 HTTP 代理 | `http_proxy` / 排除列表 |
| [`bluetooth_audio_ax`](plugins/bluetooth_audio_ax) | 蓝牙开关与音量 | `svc bluetooth` / `media volume` |
| [`ad_block_ax`](plugins/ad_block_ax) | 广告与追踪拦截 | 过滤型 DoT + 组件停用 |

</details>

<details open>
<summary><b>🎨 显示与音频（3）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`display_color_ax`](plugins/display_color_ax) | 亮度、色温、灰度、色彩反转 | `night_display` / `accessibility` |
| [`audio_balance_ax`](plugins/audio_balance_ax) | 多流音量与声道平衡 | `media volume` / `master_balance` |
| [`reading_mode_ax`](plugins/reading_mode_ax) | 阅读与护眼组合方案 | 灰度 + 色温 + 亮度 |

</details>

<details open>
<summary><b>📦 应用管理（7）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`apk_manager_ax`](plugins/apk_manager_ax) | APK 导出与权限审计 | `pm path` / `pm dump` |
| [`app_backup_ax`](plugins/app_backup_ax) | 应用备份与恢复 | `pm path` + `tar` |
| [`app_freeze_ax`](plugins/app_freeze_ax) | 预装冗余冻结 | `pm disable-user` + 保护名单 |
| [`storage_cleaner_ax`](plugins/storage_cleaner_ax) | 空间清理与占用分析 | `pm trim-caches` / 临时文件 |
| [`process_guard_ax`](plugins/process_guard_ax) | 进程查看与清理 | `ps` / `am kill` |
| [`boot_control_ax`](plugins/boot_control_ax) | 开机自启组件管控 | `query-intent-receivers` |
| [`notification_control_ax`](plugins/notification_control_ax) | 通知与免打扰 | `cmd notification set_dnd` / `POST_NOTIFICATION` |

</details>

<details open>
<summary><b>🔧 系统工具（7）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`adb_toolbox_ax`](plugins/adb_toolbox_ax) | 截图、录屏、DPI、网络开关 | `screencap` / `wm` / `svc` |
| [`logcat_toolbox_ax`](plugins/logcat_toolbox_ax) | 日志过滤与导出 | `logcat` / 诊断包 |
| [`system_monitor_ax`](plugins/system_monitor_ax) | 实时仪表盘 | `/proc` 采样 + `dumpsys` |
| [`ota_guard_ax`](plugins/ota_guard_ax) | OTA 升级阻断 | `pm disable-user` |
| [`sensor_tuner_ax`](plugins/sensor_tuner_ax) | 体感功能与省电 | `doze_pulse_on_pick_up` 等 |
| [`game_toolbox_ax`](plugins/game_toolbox_ax) | 游戏场景工具箱 | 高性能模式 / DND / 温控 |
| [`gps_optimizer_ax`](plugins/gps_optimizer_ax) | 定位模式与辅助定位 | `location_mode` / `location_providers_allowed` |

</details>

<details open>
<summary><b>🆕 新增玩法（9）</b></summary>

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| [`device_info_ax`](plugins/device_info_ax) | 设备信息总览（只读） | `getprop` / `/proc` |
| [`quick_settings_ax`](plugins/quick_settings_ax) | 系统快捷开关面板 | `svc` + 全局设置 |
| [`auto_input_ax`](plugins/auto_input_ax) | 输入与手势自动化 | `input text/keyevent/tap/swipe` |
| [`app_ops_manager_ax`](plugins/app_ops_manager_ax) | 应用行为精细管控 | `appops get/set` |
| [`thermal_monitor_ax`](plugins/thermal_monitor_ax) | 温度与节流监控 | `dumpsys thermalservice` |
| [`traffic_stats_ax`](plugins/traffic_stats_ax) | 流量统计与实时速率 | `/proc/net/dev` + `netstats` |
| [`background_optimize_ax`](plugins/background_optimize_ax) | 后台活动管控 | 待机分组 + `RUN_IN_BACKGROUND` |
| [`game_gpu_tune_ax`](plugins/game_gpu_tune_ax) | 游戏 AOT 编译与豁免 | `cmd package compile` |
| [`system_ui_tweak_ax`](plugins/system_ui_tweak_ax) | 界面微调 | `policy_control` / `wm density` |

</details>

<br/>

---

<br/>

## 📁 目录结构

```text
Axmanager-modle/
├── common/                      # 共享层（不重复 30 遍）
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
├── plugins/
│   └── <plugin_id>/
│       ├── plugin.json          # 元数据 + WebUI 声明式配置
│       └── api.sh               # 业务逻辑
├── tools/
│   ├── build.mjs                # 构建：校验 → 生成模块目录 → 打包 zip
│   ├── check.sh                 # 静态校验：语法 / 换行 / 结构 / 完整性
│   └── release-notes.mjs        # 由构建产物生成 GitHub Release 说明
├── dist/                        # 构建产物（未入库）
└── releases/                    # 可直接刷入的 zip
```

> 🎯 **开发一个插件只需要写 2 个文件**，公共部分由构建器注入。

<br/>

---

<br/>

## 🛠️ 开发一个插件

<div align="center">

| **第 1 步** | ➜ | **第 2 步** | ➜ | 🤖 **自动完成** |
|:---:|:---:|:---:|:---:|:---:|
| ✍️ `plugin.json`<br/><sub>元数据 + 声明式 UI</sub> | | ⚙️ `api.sh`<br/><sub>业务逻辑</sub> | | 📦 `build.mjs` 注入模板<br/>并打包 zip |

</div>

### 第 1 步 · `plugin.json`

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

### 第 2 步 · `api.sh`

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

### 📚 axcore.sh 提供的能力

<details>
<summary>点击展开 · 核心库函数一览</summary>

| 函数 | 说明 |
|------|------|
| `ax_set_global/set_system/set_secure <k> <v>` | 写入 settings 并**回读校验**，失败如实报告 |
| `ax_setprop <k> <v>` | 写入属性并校验（大多数属性会失败，会提示跳过） |
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

### 🧱 UI section 类型

<details>
<summary>点击展开 · 声明式 UI 区块类型</summary>

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

<br/>

---

<br/>

## 🚀 快速开始

<table>
<tr>
<td width="50%">

### 📱 普通用户

1. 安装 [**AxManager**](https://github.com/fahrez182/AxManager) 并完成 ADB 授权
2. 从 [**Releases**](https://github.com/fahrez182/Axmanager-modle/releases) 或本仓库 [`releases/`](releases) 下载需要的插件 zip
3. AxManager → 插件 → **导入**，选择 zip
4. 在插件列表中打开 **WebUI**，选档位后应用

> ♻️ 所有改动都记录在模块目录的 `.state/journal.tsv`，
> 点击「一键回滚」可精确还原；卸载插件时会先自动回滚再移除。

</td>
<td width="50%">

### 👩‍💻 开发者

```bash
# 克隆仓库
git clone https://github.com/<your-name>/Axmanager-modle.git
cd Axmanager-modle

# 构建全部插件
node tools/build.mjs

# 或只构建单个
node tools/build.mjs cpu_tuner_ax

# 静态校验
bash tools/check.sh
```

产物位于 `dist/`，可直接安装的 zip 位于 `releases/`。

</td>
</tr>
</table>

<br/>

---

<br/>

## 🧪 构建与校验

构建器会在打包前做**静态校验**，不合规直接报错退出：

- ✔️ `id` 与目录名一致
- ✔️ `axeronPlugin` 字段存在
- ✔️ 声明的每个档位在 `apply_profile` 中都有分支
- ✔️ UI 引用的每个动词在 `ax_custom` 中都有处理
- ✔️ 声明了 `metrics` 就必须实现 `ax_status`

CI 工作流见 [`.github/workflows/build-release.yml`](.github/workflows/build-release.yml)，推送时自动构建并发布 Release。

<br/>

---

<br/>

## 📖 技术说明

| 项目 | 说明 |
|------|------|
| **运行时** | AxManager 插件环境（BusyBox ash，独立 Shell 模式） |
| **换行** | 所有 `.sh` / `.prop` / `.html` 强制 UNIX LF（`module.prop` 用 CRLF 会导致 `versionCode` 解析失败） |
| **脚本规范** | 纯 POSIX sh，不使用 bash 专有语法 |
| **WebUI** | `ksu.exec(cmd, options, callback)` 异步三参数形式，兼容同步降级 |

---

<br/>

<!-- ── 参考与致谢 ─────────────────────────────────────────────────── -->

## 🙏 参考与致谢

本 README 的排版灵感与素材来自以下 GitHub 高星开源项目：

<table>
<tr>
<td width="50%">

**工具与生成器**

- [readme-md-generator](https://github.com/kefranabg/readme-md-generator) · 交互式 README 生成 CLI
- [doctoc](https://github.com/thlorenz/doctoc) · 自动目录生成器
- [Standard Readme](https://github.com/RichardLitt/standard-readme) · 专业 README 规范

**徽章与图标**

- [shields.io](https://github.com/badges/shields) · 徽章生成服务
- [simple-icons](https://github.com/simple-icons/simple-icons) · 品牌 SVG 图标库
- [markdown-badges](https://github.com/Ileriayo/markdown-badges) · 徽章代码片段大全

</td>
<td width="50%">

**动态特效与统计**

- [readme-typing-svg](https://github.com/DenverCoder1/readme-typing-svg) · 打字机动效（本页标题）
- [github-readme-stats](https://github.com/anuraghazra/github-readme-stats) · 动态统计卡片
- [profile-views-counter](https://github.com/antonkomarev/github-profile-views-counter) · 访客计数（本页页脚）

**灵感合集**

- [awesome-github-profile-readme](https://github.com/abhisheknaiidu/awesome-github-profile-readme) · 顶级案例集
- [Badges4-README.md-Profile](https://github.com/alexandresanlim/Badges4-README.md-Profile) · 主页徽章集合

</td>
</tr>
</table>

<br/>

<div align="center">

## 📄 License

<img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="MIT License"/>

本项目基于 [MIT](LICENSE) 许可证开源

<br/>

[![Views][views-shield]][repo-url]
[![Stars][stars-shield]][repo-url]
[![Forks][forks-shield]][repo-url]

**Made with ❤️ and ☕ for the AxManager community**

<sub>如果这个项目对你有帮助，欢迎点个 ⭐ Star！</sub>

</div>

<!-- ═══════════════════════════════════════════════════════════════════
     链接引用定义（Markdown Reference Links）
═══════════════════════════════════════════════════════════════════ -->

[repo-url]: https://github.com/fahrez182/Axmanager-modle
[license-url]: LICENSE
[plugins-dir]: plugins
[common-dir]: common
[releases-url]: https://github.com/fahrez182/Axmanager-modle/releases

[badge-hero]: https://img.shields.io/badge/AXManager-%E6%8F%92%E4%BB%B6%E5%90%88%E9%9B%86%20v2-6750a4?style=for-the-badge&logo=android&logoColor=white
[badge-plugins]: https://img.shields.io/badge/Plugins-38-orange?style=for-the-badge&logo=puzzle&logoColor=white
[badge-mode]: https://img.shields.io/badge/Mode-ADB%20%2F%20Shell-3ddc84?style=for-the-badge&logo=androidstudio&logoColor=black
[badge-ui]: https://img.shields.io/badge/UI-Material%203%20Expressive-8ab4f8?style=for-the-badge&logo=materialformularity&logoColor=white
[badge-root]: https://img.shields.io/badge/Root-Not%20Required-red?style=for-the-badge&logo=linux&logoColor=white
[badge-license]: https://img.shields.io/badge/License-MIT-blue?style=for-the-badge&logo=opensourceinitiative&logoColor=white
[badge-platform]: https://img.shields.io/badge/Platform-Android%2010%2B-green?style=for-the-badge&logo=android&logoColor=white

[ic-kotlin]: https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=kotlin&logoColor=white
[ic-shell]: https://img.shields.io/badge/POSIX%20sh-4EAA25?style=flat-square&logo=gnubash&logoColor=white
[ic-android]: https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=black
[ic-actions]: https://img.shields.io/badge/CI-2088FF?style=flat-square&logo=githubactions&logoColor=white
[ic-m3]: https://img.shields.io/badge/Material%203-7677DC?style=flat-square&logo=materialdesign&logoColor=white

[views-shield]: https://komarev.com/ghpvc/?username=fahrez182-Axmanager-modle&style=for-the-badge&color=blueviolet
[stars-shield]: https://img.shields.io/github/stars/fahrez182/Axmanager-modle?style=for-the-badge&color=EDA534&logo=github&logoColor=white
[forks-shield]: https://img.shields.io/github/forks/fahrez182/Axmanager-modle?style=for-the-badge&color=3DDC84&logo=git&logoColor=white
