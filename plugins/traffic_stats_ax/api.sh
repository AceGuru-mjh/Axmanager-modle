#!/system/bin/sh
# =============================================================================
# traffic_stats_ax — 流量统计
# -----------------------------------------------------------------------------
#   ✓ /proc/net/dev        接口级收发字节（设备启动以来累计）
#   ✓ dumpsys netstats     系统网络统计服务（含按 UID 的记录）
#   ✗ 重置统计需要系统签名权限，shell 无法重置
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_iface_bytes() {
    # $1 接口前缀（wlan / rmnet / eth），输出 "rx tx"（字节）
    awk -v p="$1" 'NR>2 {gsub(/:/,"",$1); if ($1 ~ "^"p) {rx+=$2; tx+=$10}} END {print int(rx)" "int(tx)}' \
        /proc/net/dev 2>/dev/null
}

_mb() { echo $(( (ax_num "$1") / 1048576 )); }

ax_custom() {
    case "$1" in
    ifaces)
        awk 'NR>2 {gsub(/:/,"",$1); if ($1=="lo") next;
             printf "%s|接收 %s MB · 发送 %s MB|%s|dim\n", $1, int($2/1048576), int($10/1048576), "接口"}' \
            /proc/net/dev 2>/dev/null
        ax_result ok
        ;;

    netstats)
        ax_head "系统网络统计（摘要）"
        dumpsys netstats 2>/dev/null | grep -E 'Dev stats|Xt stats|UID stats|bucketDuration|networkId' | head -25
        ax_result ok
        ;;

    uidstats)
        dumpsys netstats 2>/dev/null | grep -E 'uid=[0-9]+' | head -25 |
            while IFS= read -r _l; do
                _uid=$(printf '%s' "$_l" | grep -oE 'uid=[0-9]+' | head -1 | cut -d= -f2)
                _rx=$(printf '%s' "$_l" | grep -oE 'rxBytes=[0-9]+' | head -1 | cut -d= -f2)
                _tx=$(printf '%s' "$_l" | grep -oE 'txBytes=[0-9]+' | head -1 | cut -d= -f2)
                [ -z "$_uid" ] && continue
                _nm=$(cmd package list packages --uid "$_uid" 2>/dev/null | head -1 | sed 's/^package://')
                printf '%s|接收 %s MB · 发送 %s MB|%s|dim\n' "${_nm:-uid $_uid}" \
                    "$(_mb "${_rx:-0}")" "$(_mb "${_tx:-0}")" "统计"
            done
        ax_info "统计自设备上次启动，重置统计需要系统签名权限"
        ax_result ok
        ;;

    rate)
        ax_head "实时速率（2 秒采样）"
        _a=$(cat /proc/net/dev 2>/dev/null | awk 'NR>2 {gsub(/:/,"",$1); if ($1=="lo") next; rx+=$2; tx+=$10} END {print int(rx)" "int(tx)}')
        sleep 2
        _b=$(cat /proc/net/dev 2>/dev/null | awk 'NR>2 {gsub(/:/,"",$1); if ($1=="lo") next; rx+=$2; tx+=$10} END {print int(rx)" "int(tx)}')
        _r1=$(echo "$_a" | cut -d' ' -f1); _t1=$(echo "$_a" | cut -d' ' -f2)
        _r2=$(echo "$_b" | cut -d' ' -f1); _t2=$(echo "$_b" | cut -d' ' -f2)
        ax_info "下行 $(( (_r2 - _r1) / 2048 )) KB/s · 上行 $(( (_t2 - _t1) / 2048 )) KB/s"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    _w=$(_iface_bytes wlan)
    _m=$(_iface_bytes rmnet)
    _tot=$(awk 'NR>2 {gsub(/:/,"",$1); if ($1=="lo") next; rx+=$2; tx+=$10} END {print int(rx)" "int(tx)}' /proc/net/dev 2>/dev/null)
    _rx=$(echo "$_tot" | cut -d' ' -f1)
    _tx=$(echo "$_tot" | cut -d' ' -f2)
    ax_json_begin
    ax_json_kv total "$(( (ax_num "$_rx") / 1048576 ))"
    ax_json_kv sent "$(( (ax_num "$_tx") / 1048576 ))"
    ax_json_kv wifi "$(( (ax_num "$(echo "$_w" | cut -d' ' -f1)") / 1048576 ))"
    ax_json_kv mobile "$(( (ax_num "$(echo "$_m" | cut -d' ' -f1)") / 1048576 ))"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
