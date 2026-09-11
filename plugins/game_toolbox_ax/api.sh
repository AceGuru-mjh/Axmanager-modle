#!/system/bin/sh
# =============================================================================
# game_toolbox_ax — 游戏场景工具箱
# -----------------------------------------------------------------------------
# 【边界】游戏帧率与画质由游戏自身渲染逻辑与 GPU 驱动决定，脚本无法强制提升。
# 【实际手段】为游戏创造更好的运行环境：
#   ✓ cmd power set-fixed-performance-mode-enabled   固定高性能调度
#   ✓ cmd thermalservice override-status / reset      温控节流
#   ✓ cmd notification set_dnd on                    游戏免打扰
#   ✓ am kill-all                                    释放后台内存
#   ✓ settings system peak_refresh_rate              高刷
#   ✓ settings system accelerometer_rotation 0       锁定旋转
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

_perf() {
    ax_need_api 30 "固定高性能模式" || return 1
    cmd power set-fixed-performance-mode-enabled "$1" >/dev/null 2>&1 && return 0
    return 1
}

_thermal() {
    if [ "$1" = "reset" ]; then
        cmd thermalservice reset >/dev/null 2>&1 && ax_ok "温控已恢复系统托管"
        return 0
    fi
    if cmd thermalservice override-status "$1" >/dev/null 2>&1; then
        _ax_journal_add thermal "$1" '-' reset
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "温控节流档位 $1"
        return 0
    fi
    ax_warn "温控覆盖不被支持"
    AX_SKIPPED=$((AX_SKIPPED + 1))
    return 1
}

_base() {
    cmd notification set_dnd on >/dev/null 2>&1 && ax_ok "已开启免打扰"
    am kill-all 2>/dev/null && ax_ok "后台进程已释放"
    ax_set_system accelerometer_rotation 0
    ax_set_global heads_up_notifications_enabled 0
}

apply_profile() {
    case "$1" in
    extreme)
        ax_step "极致性能：固定高性能 + 解除节流 + 高刷"
        _perf true && ax_ok "固定高性能模式已开启"
        _thermal 0
        ax_set_system peak_refresh_rate 0
        ax_set_system screen_brightness_mode 0
        ax_set_system screen_brightness 255
        _base
        ;;

    balanced)
        ax_step "均衡游戏：系统自适应 + 免打扰 + 释放内存"
        _perf false
        _thermal reset
        ax_set_system peak_refresh_rate 0
        ax_set_system screen_brightness_mode 1
        _base
        ;;

    eco)
        ax_step "轻度省电：适当节流 + 降低亮度"
        _perf false
        _thermal 2
        ax_set_system screen_brightness_mode 0
        ax_set_system screen_brightness 140
        _base
        ;;

    silent)
        ax_step "温控静音：强力节流控制发热"
        _perf false
        _thermal 4
        ax_set_system screen_brightness_mode 0
        ax_set_system screen_brightness 110
        _base
        ;;

    restore)
        ax_step "退出游戏模式：恢复全部系统默认"
        _perf false
        _thermal reset
        cmd notification set_dnd off >/dev/null 2>&1 && ax_ok "免打扰已关闭"
        ax_set_global heads_up_notifications_enabled 1
        ax_set_system accelerometer_rotation 1
        ax_set_system screen_brightness_mode 1
        ax_set_system peak_refresh_rate 0
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    gstate)
        ax_head "游戏模式状态"
        ax_info "免打扰 = $(ax_get global zen_mode)"
        ax_info "峰值刷新率 = $(ax_get system peak_refresh_rate)"
        ax_info "自动旋转 = $(ax_get system accelerometer_rotation)"
        ax_info "亮度 = $(ax_get system screen_brightness) / 自动 = $(ax_get system screen_brightness_mode)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_battery_field temperature)")
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv temp "$((_t / 10))"
    ax_json_kv level "$(ax_num "$(ax_battery_field level)")"
    ax_json_kv zen "$(ax_get global zen_mode)"
    ax_json_kv refresh "$(ax_get system peak_refresh_rate)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
