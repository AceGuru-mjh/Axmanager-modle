#!/system/bin/sh
# =============================================================================
# gps_optimizer_ax — 定位模式与辅助定位
# -----------------------------------------------------------------------------
# 【边界】GPS 芯片的更新频率、精度阈值与 AGPS 服务器由 HAL 与厂商配置决定，
#        免 root 无法调整；也不存在可写的定位精度属性。
# 【实际手段】
#   ✓ settings secure location_mode            定位模式（0~3）
#   ✓ settings secure location_providers_allowed  允许的定位源
#   ✓ settings global wifi_scan_always_enabled Wi-Fi 扫描辅助定位
#   ✓ settings global ble_scan_always_enabled   蓝牙扫描辅助定位
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    high)
        ax_step "高精度导航：GPS + 网络定位，开启扫描辅助"
        ax_set_secure location_mode 3
        ax_set_secure location_providers_allowed "gps,network"
        ax_set_global wifi_scan_always_enabled 1
        ax_set_global ble_scan_always_enabled 1
        ;;

    balanced)
        ax_step "均衡日常：GPS + 网络定位，关闭后台扫描"
        ax_set_secure location_mode 3
        ax_set_secure location_providers_allowed "gps,network"
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global ble_scan_always_enabled 0
        ;;

    saving)
        ax_step "省电低功耗：仅网络定位，关闭全部扫描"
        ax_set_secure location_mode 2
        ax_set_secure location_providers_allowed "network"
        ax_set_global wifi_scan_always_enabled 0
        ax_set_global ble_scan_always_enabled 0
        ax_info "仅使用网络定位时，导航精度会明显下降"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    state)
        ax_head "定位状态"
        ax_info "location_mode = $(ax_get secure location_mode)（0 关闭 / 1 仅传感器 / 2 省电 / 3 高精度）"
        ax_info "providers = $(ax_get secure location_providers_allowed)"
        ax_info "Wi-Fi 扫描 = $(ax_get global wifi_scan_always_enabled)"
        ax_info "蓝牙扫描 = $(ax_get global ble_scan_always_enabled)"
        dumpsys location 2>/dev/null | grep -E 'Location|enabled' | head -8
        ax_result ok
        ;;
    lastloc)
        ax_head "最近一次定位"
        dumpsys location 2>/dev/null | grep -E 'last location|Location\[' | head -5
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv mode "$(ax_get secure location_mode)"
    ax_json_kv providers "$(ax_get secure location_providers_allowed)"
    ax_json_kv wifiscan "$(ax_get global wifi_scan_always_enabled)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
