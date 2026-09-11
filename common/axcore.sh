#!/system/bin/sh
# =============================================================================
# axcore.sh — AxManager 插件公共核心库
# -----------------------------------------------------------------------------
# 设计约束（必须遵守，勿删）：
#   1. AxManager 是「非 root」环境，脚本以 shell(uid 2000) 身份运行。
#      => 不可写 /system、/proc/sys、/sys/devices/system/cpu/**
#      => 只能使用 settings / cmd / pm / am / appops / device_config / dumpsys
#   2. 本库被 action.sh、service.sh、scripts/*.sh 以 `. axcore.sh` 方式引入。
#   3. ui_print 仅在「安装器」上下文中由 AxManager 定义；从 WebUI 调用脚本时
#      并不存在。因此这里必须提供回退实现，否则每行输出都会变成
#      "ui_print: not found"（这是旧版本插件的致命缺陷）。
#   4. 纯 POSIX sh / busybox ash 语法，禁止 bash 专有特性（[[ ]]、数组等）。
# =============================================================================

AXCORE_VERSION=2

# ---------------------------------------------------------------------------
# ui_print 回退：仅在未定义时补充，避免覆盖安装器的实现
# ---------------------------------------------------------------------------
if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() { echo "$@"; }
fi

# ---------------------------------------------------------------------------
# 结构化输出：WebUI 依据行首字形着色，终端里同样可读
# ---------------------------------------------------------------------------
ax_ok()   { ui_print "✔ $*"; }
ax_err()  { ui_print "✖ $*"; }
ax_warn() { ui_print "⚠ $*"; }
ax_info() { ui_print "· $*"; }
ax_step() { ui_print "▸ $*"; }
ax_head() { ui_print ""; ui_print "── $* ──"; }

# 供 WebUI 精确提取的结果行（始终位于输出末尾）
ax_result() { ui_print "::result:$*"; }

# ---------------------------------------------------------------------------
# ax_init [模块目录]
#   初始化 MODDIR / MODID / AX_STATE / AX_JOURNAL 等全局变量
# ---------------------------------------------------------------------------
ax_init() {
    if [ -n "$1" ]; then
        MODDIR="$1"
    elif [ -z "$MODDIR" ]; then
        MODDIR="$AX_SELF_DIR"
    fi
    # 归一化：去掉结尾斜杠，解析出绝对路径
    MODDIR=$(cd "$MODDIR" 2>/dev/null && pwd) || MODDIR="$1"

    MODID=$(ax_prop_get_local id)
    [ -z "$MODID" ] && MODID=$(basename "$MODDIR")

    AX_STATE="$MODDIR/.state"
    AX_JOURNAL="$AX_STATE/journal.tsv"
    AX_PROFILE="$AX_STATE/profile"
    mkdir -p "$AX_STATE" 2>/dev/null

    AX_TOUCHED=0
    AX_FAILED=0
    AX_SKIPPED=0
}

# 读取本模块 module.prop 中的字段
ax_prop_get_local() {
    [ -f "$MODDIR/module.prop" ] || return 1
    sed -n "s/^$1=//p" "$MODDIR/module.prop" 2>/dev/null | head -1 | tr -d '\r'
}

# ---------------------------------------------------------------------------
# 环境与能力探测
# ---------------------------------------------------------------------------

# 是否运行于 AxManager（由 AxManager 注入 AXERON=true）
ax_in_axmanager() { [ "$AXERON" = "true" ]; }

# 当前 uid：0=root 2000=shell
ax_uid() { id -u 2>/dev/null || echo "-1"; }

# 校验权限层级；AxManager 不支持 root 级模块，shell 即为预期状态
ax_check_privilege() {
    _u=$(ax_uid)
    case "$_u" in
    0)    ax_info "运行身份：root（AxManager 不依赖此权限，脚本按 shell 语义执行）" ;;
    2000) ax_info "运行身份：shell (uid 2000) · ADB 级权限" ;;
    *)    ax_warn "运行身份异常 (uid=$_u)，部分命令可能被拒绝" ;;
    esac
}

# 命令是否可用
ax_has() { command -v "$1" >/dev/null 2>&1; }

# Android API 等级
ax_api() { getprop ro.build.version.sdk 2>/dev/null; }

# API 下限检查：ax_need_api 29 "分区存储"
ax_need_api() {
    _a=$(ax_api)
    [ -z "$_a" ] && return 0
    if [ "$_a" -lt "$1" ] 2>/dev/null; then
        ax_warn "${2:-该功能}需要 Android API $1 及以上（当前 $_a），已跳过"
        AX_SKIPPED=$((AX_SKIPPED + 1))
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# 回滚日志
#   格式：类型 \t 参数1 \t 参数2 \t 原始值
#   同一目标只记录首次修改前的值，确保回滚到真正的原始状态
# ---------------------------------------------------------------------------
AX_NULL='__ax_null__'

_ax_journal_has() {
    [ -f "$AX_JOURNAL" ] || return 1
    grep -q "^$1	$2	$3	" "$AX_JOURNAL" 2>/dev/null
}

_ax_journal_add() {
    _ax_journal_has "$1" "$2" "$3" && return 0
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >>"$AX_JOURNAL"
}

# ---------------------------------------------------------------------------
# settings：shell 身份可稳定读写 global / system / secure
#   ax_set <namespace> <key> <value>
# ---------------------------------------------------------------------------
ax_set() {
    _ns="$1"; _k="$2"; _v="$3"
    _old=$(settings get "$_ns" "$_k" 2>/dev/null | tr -d '\r')
    [ -z "$_old" ] && _old="null"
    [ "$_old" = "null" ] && _old="$AX_NULL"

    if settings put "$_ns" "$_k" "$_v" 2>/dev/null; then
        _new=$(settings get "$_ns" "$_k" 2>/dev/null | tr -d '\r')
        if [ "$_new" = "$_v" ]; then
            _ax_journal_add setting "$_ns" "$_k" "$_old"
            AX_TOUCHED=$((AX_TOUCHED + 1))
            return 0
        fi
        ax_warn "$_ns/$_k 写入后被系统改写为 \"$_new\""
        AX_FAILED=$((AX_FAILED + 1))
        return 1
    fi
    ax_warn "$_ns/$_k 写入被拒绝"
    AX_FAILED=$((AX_FAILED + 1))
    return 1
}

ax_set_global() { ax_set global "$1" "$2"; }
ax_set_system() { ax_set system "$1" "$2"; }
ax_set_secure() { ax_set secure "$1" "$2"; }

ax_get() { settings get "$1" "$2" 2>/dev/null | tr -d '\r'; }

# ---------------------------------------------------------------------------
# setprop：绝大多数 persist.* 属性对 shell 是只读的（SELinux neverallow）
#   因此必须「写入后回读校验」，失败即如实告知，不写入回滚日志。
#   这修正了旧版本插件把大量无效 setprop 当成生效功能的问题。
# ---------------------------------------------------------------------------
ax_setprop() {
    _k="$1"; _v="$2"
    _old=$(getprop "$_k" 2>/dev/null)
    setprop "$_k" "$_v" 2>/dev/null
    _new=$(getprop "$_k" 2>/dev/null)
    if [ "$_new" = "$_v" ]; then
        [ -z "$_old" ] && _old="$AX_NULL"
        _ax_journal_add prop "$_k" '-' "$_old"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    ax_warn "属性 $_k 不可写（SELinux 限制或内核不支持），已跳过"
    AX_SKIPPED=$((AX_SKIPPED + 1))
    return 1
}

# ---------------------------------------------------------------------------
# device_config：Android 10+ 的运行时特性开关，shell 可写，效果真实
#   ax_devcfg <namespace> <key> <value>
# ---------------------------------------------------------------------------
ax_devcfg() {
    ax_need_api 29 "device_config" || return 1
    _ns="$1"; _k="$2"; _v="$3"
    _old=$(device_config get "$_ns" "$_k" 2>/dev/null | tr -d '\r')
    [ -z "$_old" ] || [ "$_old" = "null" ] && _old="$AX_NULL"
    if device_config put "$_ns" "$_k" "$_v" 2>/dev/null; then
        _ax_journal_add devcfg "$_ns" "$_k" "$_old"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    ax_warn "device_config $_ns/$_k 写入失败"
    AX_FAILED=$((AX_FAILED + 1))
    return 1
}

# ---------------------------------------------------------------------------
# appops：非 root 环境下最有效的行为管控接口（真实生效、可逆）
#   ax_appops <pkg> <op> <mode>   mode: allow|ignore|deny|default
# ---------------------------------------------------------------------------
ax_appops() {
    _p="$1"; _o="$2"; _m="$3"
    ax_pkg_exists "$_p" || return 1
    if appops set "$_p" "$_o" "$_m" 2>/dev/null; then
        _ax_journal_add appops "$_p" "$_o" default
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# 包管理
# ---------------------------------------------------------------------------
ax_pkg_exists() {
    pm path "$1" >/dev/null 2>&1 && return 0
    pm list packages "$1" 2>/dev/null | grep -q "^package:$1$"
}

ax_pkg_disabled() {
    pm list packages -d 2>/dev/null | grep -q "^package:$1$"
}

# 关键包保护名单：冻结这些会导致系统无法使用甚至无法开机
# 旧版本插件缺少该保护，存在把设备刷成砖的实际风险
AX_PROTECTED='com.android.systemui
com.android.settings
com.android.phone
com.android.server.telecom
com.android.providers.settings
com.android.providers.contacts
com.android.providers.media
com.android.providers.downloads
com.android.providers.telephony
com.android.externalstorage
com.android.documentsui
com.android.permissioncontroller
com.android.packageinstaller
com.google.android.permissioncontroller
com.android.shell
com.android.keychain
com.android.inputdevices
com.android.location.fused
android'

ax_pkg_protected() {
    # 输入法一律保护，否则冻结后无法输入
    case "$1" in
    *inputmethod*|*.ime|*ime.*|*keyboard*) return 0 ;;
    esac
    echo "$AX_PROTECTED" | grep -qx "$1"
}

# ax_pkg_disable <pkg>  停用（可逆，不删除任何文件）
ax_pkg_disable() {
    _p="$1"
    if ax_pkg_protected "$_p"; then
        ax_warn "$_p 属于系统关键组件，已拒绝冻结"
        AX_SKIPPED=$((AX_SKIPPED + 1))
        return 1
    fi
    if ! ax_pkg_exists "$_p"; then
        AX_SKIPPED=$((AX_SKIPPED + 1))
        return 1
    fi
    if ax_pkg_disabled "$_p"; then
        AX_SKIPPED=$((AX_SKIPPED + 1))
        return 0
    fi
    if pm disable-user --user 0 "$_p" >/dev/null 2>&1; then
        _ax_journal_add pkg "$_p" '-' enabled
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "已冻结 $_p"
        return 0
    fi
    ax_warn "$_p 冻结失败（可能受厂商保护）"
    AX_FAILED=$((AX_FAILED + 1))
    return 1
}

ax_pkg_enable() {
    ax_pkg_exists "$1" || return 1
    pm enable --user 0 "$1" >/dev/null 2>&1 || pm enable "$1" >/dev/null 2>&1
}

# 停止应用（不杀白名单）
ax_pkg_stop() {
    ax_pkg_protected "$1" && return 1
    am force-stop --user 0 "$1" >/dev/null 2>&1 || am force-stop "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# 组件级控制：可精确冻结广告/自启接收器而不影响应用主体
# ---------------------------------------------------------------------------
ax_comp_disable() {
    _c="$1"
    _p=$(echo "$_c" | cut -d/ -f1)
    ax_pkg_protected "$_p" && return 1
    ax_pkg_exists "$_p" || return 1
    if pm disable-user --user 0 "$_c" >/dev/null 2>&1 || pm disable --user 0 "$_c" >/dev/null 2>&1; then
        _ax_journal_add comp "$_c" '-' enabled
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    return 1
}

ax_comp_enable() { pm default-state --user 0 "$1" >/dev/null 2>&1 || pm enable --user 0 "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# ax_revert_all — 按日志逆序回滚全部改动，然后清空日志
# ---------------------------------------------------------------------------
ax_revert_all() {
    if [ ! -s "$AX_JOURNAL" ]; then
        ax_info "没有需要回滚的记录，当前已是原始状态"
        rm -f "$AX_PROFILE" 2>/dev/null
        return 0
    fi
    _n=0
    # tac 在 busybox 中可用；不可用时退化为 sed 逆序
    if ax_has tac; then _rev="tac"; else _rev="sed -n 1!G;h;\$p"; fi
    $_rev "$AX_JOURNAL" 2>/dev/null | while IFS='	' read -r _t _a1 _a2 _ov; do
        [ -z "$_t" ] && continue
        case "$_t" in
        setting)
            if [ "$_ov" = "$AX_NULL" ]; then
                settings delete "$_a1" "$_a2" >/dev/null 2>&1
            else
                settings put "$_a1" "$_a2" "$_ov" >/dev/null 2>&1
            fi
            ;;
        prop)
            [ "$_ov" = "$AX_NULL" ] || setprop "$_a1" "$_ov" 2>/dev/null
            ;;
        devcfg)
            if [ "$_ov" = "$AX_NULL" ]; then
                device_config delete "$_a1" "$_a2" >/dev/null 2>&1
            else
                device_config put "$_a1" "$_a2" "$_ov" >/dev/null 2>&1
            fi
            ;;
        pkg)   ax_pkg_enable "$_a1" ;;
        comp)  ax_comp_enable "$_a1" ;;
        appops) appops set "$_a1" "$_a2" default >/dev/null 2>&1 ;;
        esac
        _n=$((_n + 1))
    done
    _total=$(wc -l <"$AX_JOURNAL" 2>/dev/null | tr -d ' ')
    rm -f "$AX_JOURNAL" "$AX_PROFILE" 2>/dev/null
    ax_ok "已回滚 $_total 项改动，恢复到原始状态"
}

# ---------------------------------------------------------------------------
# 档位状态：记录/读取当前生效的方案，供 WebUI 高亮与开机自恢复使用
# ---------------------------------------------------------------------------
ax_profile_save() { echo "$1" >"$AX_PROFILE" 2>/dev/null; }
ax_profile_load() { cat "$AX_PROFILE" 2>/dev/null | tr -d '\r\n'; }

# 应用收尾：输出统计并保存档位
ax_finish() {
    [ -n "$1" ] && ax_profile_save "$1"
    ui_print ""
    ax_info "生效 $AX_TOUCHED 项 · 跳过 $AX_SKIPPED 项 · 失败 $AX_FAILED 项"
    if [ "$AX_TOUCHED" -eq 0 ] && [ "$AX_FAILED" -gt 0 ]; then
        ax_result "fail"
        return 1
    fi
    ax_result "ok"
    return 0
}

# ---------------------------------------------------------------------------
# JSON 输出：供 WebUI 的监控/列表类接口使用
# ---------------------------------------------------------------------------
ax_json_esc() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
        -e 's/	/\\t/g' -e 's/\r//g' | tr '\n' ' '
}
_AX_JFIRST=1
ax_json_begin() { _AX_JFIRST=1; printf '{'; }
ax_json_kv() {
    [ "$_AX_JFIRST" -eq 1 ] || printf ','
    _AX_JFIRST=0
    printf '"%s":"%s"' "$(ax_json_esc "$1")" "$(ax_json_esc "$2")"
}
ax_json_kvraw() {
    [ "$_AX_JFIRST" -eq 1 ] || printf ','
    _AX_JFIRST=0
    printf '"%s":%s' "$(ax_json_esc "$1")" "$2"
}
ax_json_end() { printf '}\n'; }

# 数字兜底：空值或非数字统一返回 0，避免 WebUI 出现 NaN
ax_num() {
    case "$1" in
    ''|*[!0-9-]*) echo "${2:-0}" ;;
    *) echo "$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# 常用只读采集
# ---------------------------------------------------------------------------
ax_battery() { dumpsys battery 2>/dev/null; }
ax_battery_field() { ax_battery | sed -n "s/^ *$1: *//p" | head -1 | tr -d '\r'; }

# 内存（单位 KB）
ax_mem_field() { sed -n "s/^$1: *\([0-9]*\).*/\1/p" /proc/meminfo 2>/dev/null | head -1; }

# CPU 核心数
ax_cpu_cores() { grep -c '^processor' /proc/cpuinfo 2>/dev/null; }
