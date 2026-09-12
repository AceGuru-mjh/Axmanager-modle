#!/system/bin/sh
# =============================================================================
# memory_cleaner_ax — 缓存回收与进程清理
# -----------------------------------------------------------------------------
# shell 身份可写/可清理的范围：
#   ✓ pm trim-caches              通知各应用自行削减缓存（安全，不杀进程）
#   ✓ am kill <pkg> / kill-all    结束后台进程（前台与受保护应用不受影响）
#   ✓ /data/local/tmp              shell 可写，可直接删除
#   ✓ /sdcard 下的缩略图与临时文件
#   ✗ /data/data/<pkg>/cache      应用私有缓存目录，无 root 无法访问
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

_clean_tmp_space() {
    _before=$(du -sk /data/local/tmp 2>/dev/null | cut -f1)
    rm -rf /data/local/tmp/* 2>/dev/null
    rm -rf /sdcard/DCIM/.thumbnails 2>/dev/null
    rm -rf /sdcard/Pictures/.thumbnails 2>/dev/null
    find /sdcard/Download -maxdepth 1 -type f \
        \( -name '*.tmp' -o -name '*.temp' -o -name '*.crdownload' -o -name '*.part' \) \
        -delete 2>/dev/null
    _after=$(du -sk /data/local/tmp 2>/dev/null | cut -f1)
    ax_ok "临时文件清理完成（/data/local/tmp $(( (${_before:-0} - ${_after:-0}) )) KB）"
}

apply_profile() {
    case "$1" in
    deep)
        ax_step "深度清理：回收缓存 + 结束后台进程 + 清理临时文件"
        pm trim-caches 999999999999 2>/dev/null
        am kill-all 2>/dev/null
        _clean_tmp_space
        ax_set_global cached_apps_freezer enabled
        ax_devcfg activity_manager max_cached_processes 16
        ;;

    balanced)
        ax_step "均衡清理：仅回收缓存与临时文件，不结束进程"
        pm trim-caches 999999999999 2>/dev/null
        _clean_tmp_space
        ax_set_global cached_apps_freezer enabled
        ;;

    analyze)
        ax_step "仅分析：不执行任何写入操作"
        _show_usage
        ;;

    *) return 1 ;;
    esac
    return 0
}

_show_usage() {
    _t=$(ax_num "$(ax_mem_field MemTotal)")
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    _u=$((_t - _a))
    ax_info "内存：已用 $((_u / 1024)) MB / 共 $((_t / 1024)) MB"
    [ "$_t" -gt 0 ] && ax_info "占用率 $(( _u * 100 / _t ))%"
    _tmp=$(du -sk /data/local/tmp 2>/dev/null | cut -f1)
    ax_info "/data/local/tmp 占用 ${_tmp:-0} KB"
    _sd=$(df -k /sdcard 2>/dev/null | awk 'NR==2{print $4}')
    ax_info "内部存储可用 $(( (ax_num "$_sd") / 1024 )) MB"
    ax_info "应用私有缓存位于 /data/data/*/cache，无 root 无法直接清理，"
    ax_info "已改用 pm trim-caches 通知系统与应用自行削减。"
}

ax_custom() {
    case "$1" in
    trim) pm trim-caches 999999999999 2>/dev/null; ax_ok "缓存回收完成"; ax_result ok ;;
    killbg) am kill-all 2>/dev/null; ax_ok "后台进程已结束"; ax_result ok ;;
    tmp) _clean_tmp_space; ax_result ok ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_mem_field MemTotal)")
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    _pct=0
    [ "$_t" -gt 0 ] && _pct=$(( (_t - _a) * 100 / _t ))
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv used "$_pct"
    ax_json_kv avail "$((_a / 1024))"
    ax_json_kv tmp "$(du -sk /data/local/tmp 2>/dev/null | cut -f1)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
