#!/system/bin/sh
# =============================================================================
# charge_thermal_ax — 充电温控与耗电策略
# -----------------------------------------------------------------------------
# 【边界】充电电流由内核充电 IC 驱动控制（/sys/class/power_supply），
#         免 root 无法调节；也不存在可写的「快充开关」属性。
# 【实际手段】
#   ✓ cmd thermalservice override-status 0..6 / reset   温控节流档位覆盖
#   ✓ settings global low_power / low_power_trigger_level 省电模式与触发电量
#   ✓ settings global adaptive_battery_management_enabled 自适应电池
#   ✓ cmd power set-fixed-performance-mode-enabled       固定性能模式
#   ✓ settings global stay_on_while_plugged_in           充电时保持唤醒
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    fast)
        ax_step "快充均衡：解除节流限制，避免充电时降功率"
        if cmd thermalservice override-status 0 >/dev/null 2>&1; then
            _ax_journal_add thermal 0 '-' reset
            AX_TOUCHED=$((AX_TOUCHED + 1))
            ax_ok "温控节流已覆盖为 0 档（不降功率）"
        else
            ax_warn "温控覆盖不被本机支持"
            AX_SKIPPED=$((AX_SKIPPED + 1))
        fi
        ax_set_global low_power 0
        ax_set_global low_power_trigger_level 0
        ax_set_global adaptive_battery_management_enabled 0
        ax_set_global stay_on_while_plugged_in 0
        ax_need_api 30 "固定性能模式" &&
            cmd power set-fixed-performance-mode-enabled false >/dev/null 2>&1
        ax_warn "长时间解除温控会加速电池老化，建议仅在需要时使用"
        ;;

    cool)
        ax_step "低温慢充：加强节流，降低发热"
        if cmd thermalservice override-status 4 >/dev/null 2>&1; then
            _ax_journal_add thermal 4 '-' reset
            AX_TOUCHED=$((AX_TOUCHED + 1))
            ax_ok "温控节流已覆盖为 4 档（较强降功率）"
        else
            ax_warn "温控覆盖不被本机支持"
            AX_SKIPPED=$((AX_SKIPPED + 1))
        fi
        ax_set_global low_power 1
        ax_set_global low_power_trigger_level 30
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global stay_on_while_plugged_in 0
        ;;

    balanced)
        ax_step "均衡：温控交由系统托管"
        cmd thermalservice reset >/dev/null 2>&1 && ax_ok "温控已恢复系统托管"
        ax_set_global low_power 0
        ax_set_global low_power_trigger_level 15
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global stay_on_while_plugged_in 0
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    battinfo)
        ax_head "电池与充电信息"
        dumpsys battery 2>/dev/null | head -14
        _t=$(ax_num "$(ax_battery_field temperature)")
        ax_info "当前温度 $((_t / 10))℃ / 电量 $(ax_battery_field level)%"
        ax_result ok
        ;;
    thermal)
        ax_head "温控状态"
        dumpsys thermalservice 2>/dev/null | head -20 || ax_info "本机未提供 thermalservice"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_battery_field temperature)")
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv level "$(ax_num "$(ax_battery_field level)")"
    ax_json_kv temp "$((_t / 10))"
    ax_json_kv volt "$(ax_num "$(ax_battery_field voltage)")"
    ax_json_kv status "$(ax_battery_field status)"
    ax_json_kv cur "$(( ax_num "$(ax_battery_field current_now)" / 1000 ))"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
