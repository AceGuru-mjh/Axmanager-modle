#!/system/bin/sh
# =============================================================================
# thermal_monitor_ax — 温度与节流监控
# -----------------------------------------------------------------------------
#   ✓ dumpsys thermalservice           只读：各温区温度与当前节流状态
#   ✓ cmd thermalservice override-status 0..6 / reset   手动覆盖节流档位
#   ✓ dumpsys battery temperature      电池温度
# 温度数据全部来自系统 Thermal HAL，真实可信。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=auto

apply_profile() {
    case "$1" in
    auto)
        ax_step "系统托管：清除手动节流覆盖"
        cmd thermalservice reset >/dev/null 2>&1 && ax_ok "温控已恢复系统托管"
        ;;
    nolimit)
        ax_step "禁用节流：覆盖为 0 档"
        if cmd thermalservice override-status 0 >/dev/null 2>&1; then
            _ax_journal_add thermal 0 '-' reset
            AX_TOUCHED=$((AX_TOUCHED + 1))
            ax_ok "节流已解除"
            ax_warn "长时间解除节流会加速电池老化并可能烫伤"
        else
            ax_warn "本机不支持覆盖节流"
            AX_SKIPPED=$((AX_SKIPPED + 1))
        fi
        ;;
    cool1)
        ax_step "轻度降温：节流 2 档"
        cmd thermalservice override-status 2 >/dev/null 2>&1 &&
            { _ax_journal_add thermal 2 '-' reset; ax_ok "节流已设为 2 档"; }
        ;;
    cool2)
        ax_step "强力降温：节流 4 档"
        cmd thermalservice override-status 4 >/dev/null 2>&1 &&
            { _ax_journal_add thermal 4 '-' reset; ax_ok "节流已设为 4 档"; }
        ;;
    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    dump)
        ax_head "温控服务状态"
        dumpsys thermalservice 2>/dev/null | head -30 || ax_info "本机未提供 thermalservice"
        ax_result ok
        ;;
    zones)
        ax_head "各温区温度"
        for _z in /sys/class/thermal/thermal_zone*/temp; do
            [ -r "$_z" ] || continue
            _d=$(dirname "$_z")
            _n=$(cat "$_d/type" 2>/dev/null)
            _v=$(cat "$_z" 2>/dev/null)
            [ -z "$_v" ] && continue
            printf '%s|%s℃|温区|dim\n' "${_n:-$(basename "$_d")}" "$((_v / 1000))"
        done
        ax_info "温区为只读展示，修改需要 root"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_battery_field temperature)")
    _th=$(dumpsys thermalservice 2>/dev/null | grep -oE 'ThermalStatus: [0-9]+' | head -1 | grep -oE '[0-9]+')
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv batt "$((_t / 10))"
    ax_json_kv status "$(ax_num "$_th")"
    ax_json_kv cpu "$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%d", $1/1000}')"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
