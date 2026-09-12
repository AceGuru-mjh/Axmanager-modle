#!/system/bin/sh
# =============================================================================
# battery_guardian_ax — 电池守护
# -----------------------------------------------------------------------------
#   ✓ settings global low_power / low_power_trigger_level  省电模式与触发电量
#   ✓ settings global adaptive_battery_management_enabled  自适应电池
#   ✓ settings global cached_apps_freezer                  缓存进程冻结器
#   ✓ am set-standby-bucket                                待机分组
#   ✓ appops WAKE_LOCK deny                                阻止息屏唤醒
#   ✓ dumpsys batterystats                                 只读耗电统计
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

AX_KEEP='com.tencent.mm
com.tencent.mobileqq
com.tencent.tim
com.tencent.wework
com.alibaba.android.rimet
com.android.mms
com.android.dialer'

_keep() { echo "$AX_KEEP" | grep -qx "$1"; }
_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

apply_profile() {
    case "$1" in
    endurance)
        ax_step "长续航：提高省电触发阈值，限制后台与唤醒锁"
        ax_set_global low_power_trigger_level 40
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global cached_apps_freezer enabled
        _n=0
        for _p in $(_apps); do
            _keep "$_p" && continue
            am set-standby-bucket "$_p" rare >/dev/null 2>&1
            appops set "$_p" WAKE_LOCK deny >/dev/null 2>&1 && _n=$((_n + 1))
        done
        _ax_journal_add meta wakelock "$AX_NULL" deny
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "已限制 $_n 个应用的唤醒锁（白名单豁免）"
        ;;

    balanced)
        ax_step "均衡：系统默认阈值，允许常规后台活动"
        ax_set_global low_power_trigger_level 15
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global cached_apps_freezer enabled
        _n=0
        for _p in $(_apps); do
            am set-standby-bucket "$_p" working_set >/dev/null 2>&1
            appops set "$_p" WAKE_LOCK allow >/dev/null 2>&1 && _n=$((_n + 1))
        done
        ax_ok "已恢复 $_n 个应用的唤醒锁"
        ;;

    performance)
        ax_step "性能优先：关闭省电与限制，换取流畅度"
        ax_set_global low_power_trigger_level 0
        ax_set_global low_power 0
        ax_set_global adaptive_battery_management_enabled 0
        ax_set_global cached_apps_freezer disabled
        _n=0
        for _p in $(_apps); do
            am set-standby-bucket "$_p" active >/dev/null 2>&1
            appops set "$_p" WAKE_LOCK allow >/dev/null 2>&1 && _n=$((_n + 1))
        done
        ax_ok "已恢复 $_n 个应用的后台活动能力"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    battinfo)
        ax_head "电池信息"
        dumpsys battery 2>/dev/null | head -12
        _t=$(ax_num "$(ax_battery_field temperature)")
        ax_info "温度 $((_t / 10))℃ · 电量 $(ax_battery_field level)% · 健康 $(ax_battery_field health)"
        ax_result ok
        ;;
    drain)
        ax_head "耗电排行（自上次充电）"
        dumpsys batterystats --charged 2>/dev/null |
            grep -E '^ *[0-9]+[a-z]?[0-9]* *[a-zA-Z]' | head -15
        ax_info "排行由系统 batterystats 提供，仅供参考"
        ax_result ok
        ;;
    wakelocks)
        ax_head "唤醒锁持有情况"
        dumpsys power 2>/dev/null | grep -E 'Wake Locks|PARTIAL' | head -12
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
    ax_json_kv health "$(ax_battery_field health)"
    ax_json_kv volt "$(ax_num "$(ax_battery_field voltage)")"
    ax_json_kv plugged "$(ax_battery_field USB\ powered | head -1)"
    ax_json_kv trigger "$(ax_get global low_power_trigger_level)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
