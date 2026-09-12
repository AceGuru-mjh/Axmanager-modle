#!/system/bin/sh
# =============================================================================
# cpu_tuner_ax — CPU 调度与性能模式
# -----------------------------------------------------------------------------
# 【能力边界说明】非 root 环境下无法做到的事（旧版本插件曾错误声称支持）：
#   ✗ 写 /sys/devices/system/cpu/*/cpufreq/scaling_governor  → EACCES
#   ✗ 写 scaling_max_freq / scaling_min_freq                 → EACCES
#   ✗ 核心上下线 /sys/devices/system/cpu/cpuN/online          → EACCES
#   ✗ setprop persist.cpu.*  → SELinux neverallow，且无任何系统组件读取这些
#     自造属性，写了也不会有任何效果
#
# 【实际可用的等效手段】全部经由 shell(uid 2000) 合法接口：
#   ✓ cmd power set-fixed-performance-mode-enabled  锁定高性能调度 (API 30+)
#   ✓ cmd thermalservice override-status            覆盖温控节流档位
#   ✓ settings global low_power                      省电模式（真实降频）
#   ✓ settings global cached_apps_freezer            缓存进程冻结器
#   ✓ device_config activity_manager                 后台进程上限
#   ✓ cmd package compile -m speed                   ART 预编译（真实提速）
#   ✓ 动画时长缩放                                    响应感知
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

# ---------------------------------------------------------------------------
# 高性能模式：Android 11+ 提供的官方接口，会把任务固定到大核并抬高调度下限
# ---------------------------------------------------------------------------
_perf_mode() {
    ax_need_api 30 "固定高性能模式" || return 1
    if cmd power set-fixed-performance-mode-enabled "$1" >/dev/null 2>&1; then
        _ax_journal_add cmd "power-fixed-perf" '-' false
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "固定高性能模式：$1"
    else
        ax_warn "固定高性能模式不被本机支持，已跳过"
        AX_SKIPPED=$((AX_SKIPPED + 1))
    fi
}

# ---------------------------------------------------------------------------
# 温控档位覆盖：0=无节流 1..6=逐级加重
# ---------------------------------------------------------------------------
_thermal() {
    if [ "$1" = "reset" ]; then
        cmd thermalservice reset >/dev/null 2>&1 && ax_ok "温控已恢复系统托管"
        return 0
    fi
    if cmd thermalservice override-status "$1" >/dev/null 2>&1; then
        _ax_journal_add thermal "$1" '-' reset
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "温控节流档位覆盖为 $1"
    else
        ax_warn "温控覆盖失败（厂商可能已锁定 thermalservice）"
        AX_SKIPPED=$((AX_SKIPPED + 1))
    fi
}

# ---------------------------------------------------------------------------
# ART 预编译：对前台常用应用做 speed 编译，是非 root 环境下最实在的提速手段
# ---------------------------------------------------------------------------
_compile_speed() {
    _n=0
    for _p in $(cmd package list packages -3 2>/dev/null | sed 's/^package://' | head -25); do
        cmd package compile -m speed -f "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    ax_ok "已对 $_n 个第三方应用执行 speed 预编译"
    AX_TOUCHED=$((AX_TOUCHED + 1))
}

apply_profile() {
    case "$1" in
    performance)
        ax_step "性能优先：解除节流上限，锁定高性能调度"
        _perf_mode true
        _thermal 0
        ax_set_global low_power 0
        ax_set_global cached_apps_freezer disabled
        ax_set_global adaptive_battery_management_enabled 0
        ax_devcfg activity_manager max_cached_processes 128
        ax_set_global window_animation_scale 0.5
        ax_set_global transition_animation_scale 0.5
        ax_set_global animator_duration_scale 0.5
        ax_warn "此档位会显著增加发热与耗电，不建议长期使用"
        ;;

    balanced)
        ax_step "均衡日常：交由系统自适应调度，仅优化响应感知"
        _perf_mode false
        _thermal reset
        ax_set_global low_power 0
        ax_set_global cached_apps_freezer enabled
        ax_set_global adaptive_battery_management_enabled 1
        ax_devcfg activity_manager max_cached_processes 32
        ax_set_global window_animation_scale 0.8
        ax_set_global transition_animation_scale 0.8
        ax_set_global animator_duration_scale 0.8
        ;;

    battery)
        ax_step "省电续航：开启省电模式，收紧后台与调度"
        _perf_mode false
        _thermal reset
        ax_set_global low_power 1
        ax_set_global cached_apps_freezer enabled
        ax_set_global adaptive_battery_management_enabled 1
        ax_devcfg activity_manager max_cached_processes 16
        ax_set_global window_animation_scale 1
        ax_set_global transition_animation_scale 1
        ax_set_global animator_duration_scale 1
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    compile)
        ax_head "ART speed 预编译"
        ax_info "对第三方应用执行 AOT 编译，启动与运行更快，占用少量存储"
        _compile_speed
        ax_result ok
        ;;
    coreinfo)
        ax_head "CPU 硬件信息"
        ax_info "核心数：$(ax_cpu_cores)"
        _i=0
        while [ "$_i" -lt "$(ax_cpu_cores)" ]; do
            _d="/sys/devices/system/cpu/cpu$_i/cpufreq"
            if [ -r "$_d/scaling_cur_freq" ]; then
                _c=$(cat "$_d/scaling_cur_freq" 2>/dev/null)
                _mx=$(cat "$_d/cpuinfo_max_freq" 2>/dev/null)
                _g=$(cat "$_d/scaling_governor" 2>/dev/null)
                ax_info "cpu$_i  当前 $((${_c:-0} / 1000))MHz / 上限 $((${_mx:-0} / 1000))MHz  调速器 ${_g:-未知}"
            fi
            _i=$((_i + 1))
        done
        ax_info "调速器为只读展示 —— 修改需要 root，AxManager 环境下不可写"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _cores=$(ax_cpu_cores)
    # 平均频率占比：反映当前整体负载水位
    _sum=0; _max=0; _n=0
    _i=0
    while [ "$_i" -lt "${_cores:-0}" ]; do
        _d="/sys/devices/system/cpu/cpu$_i/cpufreq"
        if [ -r "$_d/scaling_cur_freq" ]; then
            _c=$(ax_num "$(cat "$_d/scaling_cur_freq" 2>/dev/null)")
            _m=$(ax_num "$(cat "$_d/cpuinfo_max_freq" 2>/dev/null)")
            _sum=$((_sum + _c)); _max=$((_max + _m)); _n=$((_n + 1))
        fi
        _i=$((_i + 1))
    done
    _pct=0
    [ "$_max" -gt 0 ] && _pct=$((_sum * 100 / _max))

    # 电池温度（0.1℃ 单位）
    _t=$(ax_num "$(ax_battery_field temperature)")
    _temp=$((_t / 10))

    _load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)

    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv cores "${_cores:-0}"
    ax_json_kv freq "$_pct"
    ax_json_kv temp "$_temp"
    ax_json_kv load "${_load:-0}"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
