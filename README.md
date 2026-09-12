# AXManager 插件合集 v2

> 38 个 AXManager 系统工具插件 · ADB Shell · Material 3 WebUI · 免 Root

<p align="center">
  <img src="https://img.shields.io/badge/Plugins-38-orange" />
  <img src="https://img.shields.io/badge/Mode-ADB%20%2F%20Shell-orange" />
  <img src="https://img.shields.io/badge/UI-Material%203%20Expressive-orange" />
  <img src="https://img.shields.io/badge/Root-Not%20Required-orange" />
</p>

一套面向 **AxManager（免 Root 插件体系）** 的系统工具插件。全部插件只使用
`shell(uid 2000)` 权限下真实可用的接口，不伪装 root 能力，所有改动均有回滚日志。

---

## 这个版本做了什么

v2 是对整个仓库的一次重写，而不是增补。改动集中在四件事：

**1. 修正结构，让插件真正被 AxManager 识别**

| 问题 | 旧版本 | v2 |
|------|--------|-----|
| WebUI 目录 | `web/`（共 25 个插件用错） | `webroot/`（AxManager 规范） |
| 模块 id | 目录名与 `id=` 不一致（如 `plugin_ad_block` / `ad_block_ax`） | 二者强制一致 |
| 生命周期 | 只有部分插件有 `uninstall.sh`，无 `action.sh` / `service.sh` | 全部补齐，统一由模板同步 |
| 安装校验 | 无 | `customize.sh` 校验 API 等级与宿主环境 |

**2. 删掉无效代码，改用真实生效的接口**

旧版本大量使用 `setprop persist.cpu.governor performance` 之类的自造属性——
这些属性没有任何系统组件读取，且 `persist.*` 对 shell 受 SELinux `neverallow` 限制，
**写入即失败，也不会有任何效果**。v2 全部替换为有据可查的官方接口：

```
✗ setprop persist.cpu.governor      →  ✓ cmd power set-fixed-performance-mode-enabled
✗ setprop persist.cpu.freq.max      →  ✓ cmd thermalservice override-status
✗ 写 /sys/devices/system/cpu/*      →  ✓ settings global cached_apps_freezer
✗ 写 /proc/sys/vm/swappiness        →  ✓ device_config activity_manager max_cached_processes
✗ 写 /system/etc/hosts              →  ✓ settings global private_dns_mode
```

**3. 补齐安全性与可逆性**

- 新增**关键组件保护名单**：SystemUI、设置、电话、输入法等永不被冻结/卸载
  （旧版本无此保护，存在把设备冻结到无法操作的风险）
- 新增**回滚日志**：每一次写入都记录修改前的原值，一键精确还原
- 新增**开机自恢复**：`service.sh` 在 BOOT_COMPLETED 后重放上次档位
  （旧版本每次重启都要手动重设）
- 每次写入都**回读校验**，被系统拒绝时如实提示，而不是假装成功

**4. 统一 WebUI**

38 份重复的 HTML 收敛为一套 Material 3 Expressive 设计系统 + 声明式渲染引擎。
同时修复了一个隐蔽缺陷：旧 CSS 中大量 `var(--p)22` 这类写法**不是合法 CSS**
（无法把 `var()` 与字面量拼接），意味着此前所有半透明配色、毛玻璃与描边都未生效。

---

## 能力边界（重要）

免 Root 是有明确上限的。下表说明哪些能做、哪些不能：

### 做不到（需要 root）

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

对于这些能力，插件不会假装实现，而是在界面上如实说明并给出等效替代方案。

### 做得到（shell 身份真实可用）

- `settings put global / system / secure` —— adb shell 拥有写入权限
- `device_config put` —— Android 10+ 运行时特性开关
- `appops set` —— 应用操作级授权管控
- `pm disable-user / enable` —— 可逆停用应用与组件
- `am set-standby-bucket`、`am kill`、`am force-stop`
- `cmd power` / `cmd thermalservice` / `cmd notification` / `cmd package`
- `svc wifi|data|bluetooth|nfc|power`、`wm`、`input`、`screencap`、`screenrecord`
- `dumpsys` / `logcat` / `/proc` 只读采集

---

## 插件列表（38 个）

### 系统调优

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `cpu_tuner_ax` | 调度与性能模式、ART 预编译 | `cmd power` / `thermalservice` / `cmd package compile` |
| `gpu_tune_ax` | 刷新率与合成负载 | `peak_refresh_rate` / 动画缩放 |
| `swap_tuner_ax` | 内存水位与后台进程 | `activity_manager` / `cached_apps_freezer` |
| `memory_cleaner_ax` | 缓存回收与进程清理 | `pm trim-caches` / `am kill` |
| `doze_tuner_ax` | 后台行为与待机分组 | `am set-standby-bucket` / `appops` |
| `charge_thermal_ax` | 充电温控与耗电策略 | `thermalservice` / `low_power_trigger_level` |
| `battery_guardian_ax` | 电池守护、唤醒锁管控 | `low_power` / `WAKE_LOCK` / `batterystats` |

### 网络优化

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `network_optimize_ax` | 私有 DNS、息屏网络策略 | `private_dns_mode` / `wifi_sleep_policy` |
| `wifi_boost_ax` | Wi-Fi 保持与扫描策略 | `wifi_watchdog_on` / `avoid_bad_wifi` |
| `proxy_switch_ax` | 全局 HTTP 代理 | `http_proxy` / 排除列表 |
| `bluetooth_audio_ax` | 蓝牙开关与音量 | `svc bluetooth` / `media volume` |
| `ad_block_ax` | 广告与追踪拦截 | 过滤型 DoT + 组件停用 |

### 显示与音频

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `display_color_ax` | 亮度、色温、灰度、色彩反转 | `night_display` / `accessibility` |
| `audio_balance_ax` | 多流音量与声道平衡 | `media volume` / `master_balance` |
| `reading_mode_ax` | 阅读与护眼组合方案 | 灰度 + 色温 + 亮度 |

### 应用管理

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `apk_manager_ax` | APK 导出与权限审计 | `pm path` / `pm dump` |
| `app_backup_ax` | 应用备份与恢复 | `pm path` + `tar` |
| `app_freeze_ax` | 预装冗余冻结 | `pm disable-user` + 保护名单 |
| `storage_cleaner_ax` | 空间清理与占用分析 | `pm trim-caches` / 临时文件 |
| `process_guard_ax` | 进程查看与清理 | `ps` / `am kill` |
| `boot_control_ax` | 开机自启组件管控 | `query-intent-receivers` |
| `notification_control_ax` | 通知与免打扰 | `cmd notification set_dnd` / `POST_NOTIFICATION` |

### 系统工具

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `adb_toolbox_ax` | 截图、录屏、DPI、网络开关 | `screencap` / `wm` / `svc` |
| `logcat_toolbox_ax` | 日志过滤与导出 | `logcat` / 诊断包 |
| `system_monitor_ax` | 实时仪表盘 | `/proc` 采样 + `dumpsys` |
| `ota_guard_ax` | OTA 升级阻断 | `pm disable-user` |
| `sensor_tuner_ax` | 体感功能与省电 | `doze_pulse_on_pick_up` 等 |
| `game_toolbox_ax` | 游戏场景工具箱 | 高性能模式 / DND / 温控 |
| `gps_optimizer_ax` | 定位模式与辅助定位 | `location_mode` / `location_providers_allowed` |

### 新增玩法

| 插件 | 功能 | 关键接口 |
|------|------|----------|
| `device_info_ax` | 设备信息总览（只读） | `getprop` / `/proc` |
| `quick_settings_ax` | 系统快捷开关面板 | `svc` + 全局设置 |
| `auto_input_ax` | 输入与手势自动化 | `input text/keyevent/tap/swipe` |
| `app_ops_manager_ax` | 应用行为精细管控 | `appops get/set` |
| `thermal_monitor_ax` | 温度与节流监控 | `dumpsys thermalservice` |
| `traffic_stats_ax` | 流量统计与实时速率 | `/proc/net/dev` + `netstats` |
| `background_optimize_ax` | 后台活动管控 | 待机分组 + `RUN_IN_BACKGROUND` |
| `game_gpu_tune_ax` | 游戏 AOT 编译与豁免 | `cmd package compile` |
| `system_ui_tweak_ax` | 界面微调 | `policy_control` / `wm density` |

---

## 目录结构

```
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
│   └── check.sh                 # 静态校验：语法 / 换行 / 结构 / 完整性
├── dist/                        # 构建产物（未入库）
└── releases/                    # 可直接刷入的 zip
```

**开发一个插件只需要写 2 个文件**，公共部分由构建器注入。

---

## 开发一个插件

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

### axcore.sh 提供的能力

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

### UI section 类型

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

### 3. 构建

```bash
node tools/build.mjs              # 构建全部
node tools/build.mjs cpu_tuner_ax # 构建单个
bash tools/check.sh               # 静态校验
```

构建器会在打包前做静态校验，包括：`id` 与目录名一致、`axeronPlugin` 存在、
声明的每个档位在 `apply_profile` 中都有分支、UI 引用的每个动词在 `ax_custom`
中都有处理、声明了 `metrics` 就必须实现 `ax_status`。不合规直接报错退出。

---

## 使用

1. 安装 [AxManager](https://github.com/fahrez182/AxManager) 并完成 ADB 授权
2. 从 `releases/` 下载需要的插件 zip
3. AxManager → 插件 → 导入，选择 zip
4. 在插件列表中打开 **WebUI**，选档位后应用

所有改动都记录在模块目录的 `.state/journal.tsv`，点击「一键回滚」可精确还原；
卸载插件时会先自动回滚再移除。

---

## 技术说明

- **运行时**：AxManager 插件环境（BusyBox ash，独立 Shell 模式）
- **换行**：所有 `.sh` / `.prop` / `.html` 强制 UNIX LF（`module.prop` 用 CRLF 会导致 `versionCode` 解析失败）
- **脚本规范**：纯 POSIX sh，不使用 bash 专有语法
- **WebUI**：`ksu.exec(cmd, options, callback)` 异步三参数形式，兼容同步降级

## License

MIT
