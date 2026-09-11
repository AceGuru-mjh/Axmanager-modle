#!/system/bin/sh
# =============================================================================
# network_optimize_ax — 网络参数与私有 DNS
# -----------------------------------------------------------------------------
# 【边界】TCP 拥塞算法与缓冲区位于 /proc/sys/net，免 root 不可写；
#         MTU 修改同样需要 root。
# 【实际手段】
#   ✓ settings global private_dns_mode / private_dns_specifier  私有 DNS (DoT)
#   ✓ settings global wifi_scan_always_enabled                  后台扫描
#   ✓ settings global wifi_sleep_policy                         息屏 Wi-Fi 策略
#   ✓ settings global mobile_data_always_on                      移动数据常连
#   ✓ settings global ble_scan_always_enabled                    蓝牙扫描
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

_dns() {
    if [ "$1" = "off" ]; then
        ax_set_global private_dns_mode off && ax_ok "私有 DNS 已关闭"
        return 0
    fi
    if [ "$1" = "auto" ]; then
        ax_set_global private_dns_mode opportunistic && ax_ok "私有 DNS：自动（ opportunistic ）"
        return 0
    fi
    ax_set_global private_dns_mode hostname && \
    ax_set_global private_dns_specifier "$1" && ax_ok "私有 DNS 已指向 $1"
}

apply_profile() {
    case "$1" in
    fast)
        ax_step "极速低延迟：常连网络，关闭后台扫描节流"
        _dns auto
        ax_set_global mobile_data_always_on 1
        ax_set_global wifi_sleep_policy 0
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global ble_scan_always_enabled 0
        ax_set_global wifi_watchdog_on 0
        ;;

    balanced)
        ax_step "均衡省电：系统默认扫描与息屏策略"
        _dns auto
        ax_set_global mobile_data_always_on 0
        ax_set_global wifi_sleep_policy 2
        ax_set_global wifi_scan_always_enabled 1
        ax_set_global ble_scan_always_enabled 1
        ax_set_global wifi_watchdog_on 1
        ;;

    saving)
        ax_step "纯省电：息屏断开网络扫描，关闭常连"
        _dns off
        ax_set_global mobile_data_always_on 0
        ax_set_global wifi_sleep_policy 1
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global ble_scan_always_enabled 0
        ax_set_global wifi_watchdog_on 0
        ax_warn "息屏后网络可能暂时断开，影响消息及时性"
        ;;

    *) return 1 ;;
    esac
    return 0
}

_link_info() {
    dumpsys wifi 2>/dev/null | grep -E 'SSID:|RSSI:|Link speed:|BSSID:|freq=' | head -6
}

ax_custom() {
    case "$1" in
    ping)
        ax_head "连通性测试"
        if command -v ping >/dev/null 2>&1; then
            _r=$(ping -c 3 -W 2 223.5.5.5 2>/dev/null | tail -2 | head -1)
            [ -n "$_r" ] && ax_info "阿里 DNS 223.5.5.5 → $_r" || ax_warn "ping 未返回结果"
            _r2=$(ping -c 3 -W 2 8.8.8.8 2>/dev/null | tail -2 | head -1)
            [ -n "$_r2" ] && ax_info "Google DNS 8.8.8.8 → $_r2"
        else
            ax_warn "系统未提供 ping，改用 connectivity 状态"
            dumpsys connectivity 2>/dev/null | grep -E 'NetworkAgentInfo|CONNECTED|VALIDATED' | head -5
        fi
        ax_result ok
        ;;
    dnsdump)
        ax_head "DNS 与链路信息"
        ax_info "private_dns_mode = $(ax_get global private_dns_mode)"
        ax_info "private_dns_specifier = $(ax_get global private_dns_specifier)"
        _link_info
        ax_result ok
        ;;
    setdns)
        [ -z "$2" ] && { ax_err "缺少 DNS 主机名"; ax_result fail; return 1; }
        _dns "$2"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv dnsmode "$(ax_get global private_dns_mode)"
    ax_json_kv dnshost "$(ax_get global private_dns_specifier)"
    ax_json_kv rssi "$(dumpsys wifi 2>/dev/null | grep -oE 'RSSI: -?[0-9]+' | head -1 | cut -d' ' -f2)"
    ax_json_kv speed "$(dumpsys wifi 2>/dev/null | grep -oE 'Link speed: [0-9]+' | head -1 | cut -d' ' -f3)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
