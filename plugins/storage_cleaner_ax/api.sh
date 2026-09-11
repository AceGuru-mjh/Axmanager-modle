#!/system/bin/sh
# =============================================================================
# storage_cleaner_ax — 存储空间清理
# -----------------------------------------------------------------------------
# shell 可写可删的范围：
#   ✓ pm trim-caches                    通知应用自行削减缓存
#   ✓ /data/local/tmp                   shell 可写
#   ✓ /sdcard 下的缩略图、日志、下载临时文件
#   ✓ logcat 缓冲区与 tombstones 日志
#   ✗ /data/data/<pkg>/cache            应用私有缓存，需 root
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=light

_disk_pct() {
    _d=$(df -k /data 2>/dev/null | awk 'NR==2{print $2" "$3}')
    _t=$(echo "$_d" | cut -d' ' -f1); _u=$(echo "$_d" | cut -d' ' -f2)
    [ "$(ax_num "$_t")" -le 0 ] && { echo 0; return; }
    echo $(( (ax_num "$_u") * 100 / (ax_num "$_t") ))
}

_sweep() {
    _n=0
    # 应用缓存
    pm trim-caches 999999999999 2>/dev/null && _n=$((_n + 1))
    # shell 可写的临时目录
    rm -rf /data/local/tmp/* 2>/dev/null
    rm -rf /data/anr/*.tmp 2>/dev/null
    # 缩略图与缩略图缓存
    rm -rf /sdcard/DCIM/.thumbnails 2>/dev/null
    rm -rf /sdcard/Pictures/.thumbnails 2>/dev/null
    rm -rf /sdcard/Movies/.thumbnails 2>/dev/null
    # 下载目录临时文件
    find /sdcard/Download -maxdepth 1 -type f \
        \( -name '*.tmp' -o -name '*.temp' -o -name '*.crdownload' -o -name '*.part' \
           -o -name '*.apk.*' \) -delete 2>/dev/null
    # 根目录零散日志
    rm -f /sdcard/*.log /sdcard/*.tmp 2>/dev/null
    echo "$_n"
}

apply_profile() {
    case "$1" in
    deep)
        ax_step "深度清理：缓存 + 临时文件 + 日志缓冲区"
        _sweep >/dev/null
        logcat -c -b all >/dev/null 2>&1 && ax_ok "日志缓冲区已清空"
        rm -rf /sdcard/Android/data/*/cache/* 2>/dev/null
        ax_ok "深度清理完成"
        ;;

    light)
        ax_step "轻度清理：仅回收缓存与临时文件"
        _sweep >/dev/null
        ax_ok "轻度清理完成"
        ;;

    analyze)
        ax_step "仅分析：不删除任何文件"
        _show_usage
        ;;

    *) return 1 ;;
    esac
    return 0
}

_show_usage() {
    ax_head "存储占用分析"
    _d=$(df -h /data 2>/dev/null | awk 'NR==2{print $2" 已用"$3" 可用"$4}')
    ax_info "/data 分区：${_d:-未知}"
    ax_info "占用率 $(_disk_pct)%"
    ax_info ""
    ax_info "/sdcard 占用最大的目录："
    du -sh /sdcard/* 2>/dev/null | sort -rh 2>/dev/null | head -8 |
        while IFS= read -r _l; do ax_info "  $_l"; done
    ax_info ""
    _t=$(du -sk /data/local/tmp 2>/dev/null | cut -f1)
    ax_info "/data/local/tmp 占用 ${_t:-0} KB（可清理）"
}

ax_custom() {
    case "$1" in
    sweep) _sweep >/dev/null; ax_ok "临时文件已清理"; ax_result ok ;;
    trim)  pm trim-caches 999999999999 2>/dev/null; ax_ok "缓存已回收"; ax_result ok ;;
    logs)  logcat -c -b all >/dev/null 2>&1; ax_ok "日志缓冲区已清空"; ax_result ok ;;
    usage) _show_usage; ax_result ok ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _d=$(df -k /data 2>/dev/null | awk 'NR==2{print $4}')
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv used "$(_disk_pct)"
    ax_json_kv free "$(( (ax_num "$_d") / 1024 ))"
    ax_json_kv tmp "$(du -sk /data/local/tmp 2>/dev/null | cut -f1)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
