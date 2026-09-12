#!/system/bin/sh
# =============================================================================
# swap_tuner_ax — 内存水位与后台进程管理
# -----------------------------------------------------------------------------
# 【边界】ZRAM 大小 / swappiness 位于 /sys/block/zram0 与 /proc/sys/vm，
#         需要 root 才能修改；任何声称免 root 调整 Swap 的插件都是无效操作。
# 【实际手段】通过控制「可以同时存活多少后台进程」来等效调节内存压力：
#   ✓ device_config activity_manager max_cached_processes   缓存进程上限
#   ✓ settings global cached_apps_freezer                   缓存进程冻结器
#   ✓ settings global adaptive_battery_management_enabled   自适应电池
#   ✓ pm trim-caches                                        立即回收缓存
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    multitask)
        ax_step "多任务保活：放宽缓存进程上限，关闭冻结器"
        ax_devcfg activity_manager max_cached_processes 128
        ax_set_global cached_apps_freezer disabled
        ax_set_global adaptive_battery_management_enabled 0
        ax_warn "保活进程越多，可用内存越少、耗电越高"
        ;;

    balanced)
        ax_step "均衡日常：标准缓存进程上限，启用冻结器"
        ax_devcfg activity_manager max_cached_processes 32
        ax_set_global cached_apps_freezer enabled
        ax_set_global adaptive_battery_management_enabled 1
        ;;

    aggressive)
        ax_step "激进回收：收紧进程上限，冻结并回收缓存"
        ax_devcfg activity_manager max_cached_processes 12
        ax_set_global cached_apps_freezer enabled
        ax_set_global adaptive_battery_management_enabled 1
        pm trim-caches 999999999999 2>/dev/null
        am kill-all 2>/dev/null
        ax_ok "已回收缓存并结束后台进程"
        ;;

    *) return 1 ;;
    esac
    return 0
}

_mem_used_pct() {
    _t=$(ax_num "$(ax_mem_field MemTotal)")
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    [ "$_t" -le 0 ] && { echo 0; return; }
    echo $(( (_t - _a) * 100 / _t ))
}

ax_custom() {
    case "$1" in
    trim)
        pm trim-caches 999999999999 2>/dev/null && ax_ok "缓存回收完成" || ax_warn "缓存回收被拒绝"
        am kill-all 2>/dev/null && ax_ok "后台进程已结束"
        ax_result ok
        ;;
    meminfo)
        ax_head "内存详情"
        grep -E 'MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|ZRAM' /proc/meminfo 2>/dev/null | head -10
        ax_info "ZRAM / Swap 参数只能查看，修改需要 root"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_mem_field MemTotal)")
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv used "$(_mem_used_pct)"
    ax_json_kv avail "$((_a / 1024))"
    ax_json_kv total "$((_t / 1024))"
    ax_json_kv maxproc "$(device_config get activity_manager max_cached_processes 2>/dev/null | tr -d '\r')"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
