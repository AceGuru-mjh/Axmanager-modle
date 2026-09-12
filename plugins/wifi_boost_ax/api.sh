#!/system/bin/sh
# =============================================================================
# wifi_boost_ax — Wi-Fi 保持与扫描策略
# -----------------------------------------------------------------------------
# 【边界】Wi-Fi 发射功率与 RSSI 阈值由驱动与固件决定，免 root 无法调整，
#        不存在「增强信号」的开关。
# 【实际手段】减少系统主动降级 / 断开网络的行为，提升实际可用体验：
#   ✓ settings global wifi_sleep_policy              息屏是否保持 Wi-Fi
#   ✓ settings global wifi_watchdog_on               网络看门狗（会切网）
#   ✓ settings global wifi_scan_always_enabled       后台扫描（影响定位耗电）
#   ✓ settings global wifi_networks_available_notification_on  可用网络提醒
#   ✓ settings global avoid_bad_wifi / wifi_watchdog_poor_network_test_enabled
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    gaming)
        ax_step "极速稳定：息屏保持 Wi-Fi，关闭自动切网"
        ax_set_global wifi_sleep_policy 0
        ax_set_global wifi_watchdog_on 0
        ax_set_global wifi_watchdog_poor_network_test_enabled 0
        ax_set_global avoid_bad_wifi 0
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global wifi_networks_available_notification_on 0
        ;;

    balanced)
        ax_step "均衡日常：系统默认策略"
        ax_set_global wifi_sleep_policy 2
        ax_set_global wifi_watchdog_on 1
        ax_set_global wifi_watchdog_poor_network_test_enabled 1
        ax_set_global avoid_bad_wifi 1
        ax_set_global wifi_scan_always_enabled 1
        ax_set_global wifi_networks_available_notification_on 0
        ;;

    saving)
        ax_step "深度省电：息屏可断网，关闭全部扫描"
        ax_set_global wifi_sleep_policy 1
        ax_set_global wifi_watchdog_on 0
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global wifi_networks_available_notification_on 0
        ax_set_global ble_scan_always_enabled 0
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    wifidump)
        ax_head "Wi-Fi 状态"
        dumpsys wifi 2>/dev/null | grep -E 'Wi-Fi is|SSID:|BSSID:|RSSI:|Link speed:|freq=|NetworkInfo' | head -12
        ax_result ok
        ;;
    scans)
        ax_head "已保存网络数量"
        ax_info "已保存网络：$(dumpsys wifi 2>/dev/null | grep -c 'SSID:')"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv rssi "$(dumpsys wifi 2>/dev/null | grep -oE 'RSSI: -?[0-9]+' | head -1 | cut -d' ' -f2)"
    ax_json_kv speed "$(dumpsys wifi 2>/dev/null | grep -oE 'Link speed: [0-9]+' | head -1 | cut -d' ' -f3)"
    ax_json_kv ssid "$(dumpsys wifi 2>/dev/null | grep -oE 'SSID: [^,]+' | head -1 | cut -d' ' -f2)"
    ax_json_kv sleep "$(ax_get global wifi_sleep_policy)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
