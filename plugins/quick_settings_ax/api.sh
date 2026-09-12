#!/system/bin/sh
# =============================================================================
# quick_settings_ax — 快捷开关面板
# -----------------------------------------------------------------------------
# 使用系统内置的 svc 命令与全局设置，全部为 shell 身份可执行：
#   ✓ svc wifi / data / bluetooth / nfc / power   系统开关
#   ✓ settings global airplane_mode_on + 广播      飞行模式
#   ✓ settings system screen_brightness_mode       自动亮度
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_airplane() {
    if [ "$1" = "on" ]; then
        ax_set_global airplane_mode_on 1
        am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
        ax_ok "飞行模式已开启"
    else
        ax_set_global airplane_mode_on 0
        am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1
        ax_ok "飞行模式已关闭"
    fi
}

ax_custom() {
    case "$1" in
    wifi)
        if [ "$2" = "on" ]; then svc wifi enable  >/dev/null 2>&1 && ax_ok "Wi-Fi 已开启";
        else svc wifi disable >/dev/null 2>&1 && ax_ok "Wi-Fi 已关闭"; fi
        ax_result ok ;;
    data)
        if [ "$2" = "on" ]; then svc data enable  >/dev/null 2>&1 && ax_ok "移动数据已开启";
        else svc data disable >/dev/null 2>&1 && ax_ok "移动数据已关闭"; fi
        ax_result ok ;;
    bt)
        if [ "$2" = "on" ]; then svc bluetooth enable  >/dev/null 2>&1 && ax_ok "蓝牙已开启";
        else svc bluetooth disable >/dev/null 2>&1 && ax_ok "蓝牙已关闭"; fi
        ax_result ok ;;
    nfc)
        if [ "$2" = "on" ]; then svc nfc enable  >/dev/null 2>&1 && ax_ok "NFC 已开启";
        else svc nfc disable >/dev/null 2>&1 && ax_ok "NFC 已关闭"; fi
        ax_result ok ;;
    airplane) _airplane "$2"; ax_result ok ;;
    stayon)
        if [ "$2" = "on" ]; then svc power stayon true  >/dev/null 2>&1 && ax_ok "充电时保持唤醒";
        else svc power stayon false >/dev/null 2>&1 && ax_ok "已关闭保持唤醒"; fi
        ax_result ok ;;
    autobright)
        if [ "$2" = "on" ]; then ax_set_system screen_brightness_mode 1 && ax_ok "自动亮度已开启";
        else ax_set_system screen_brightness_mode 0 && ax_ok "自动亮度已关闭"; fi
        ax_result ok ;;
    rotation)
        if [ "$2" = "on" ]; then ax_set_system accelerometer_rotation 1 && ax_ok "自动旋转已开启";
        else ax_set_system accelerometer_rotation 0 && ax_ok "自动旋转已关闭"; fi
        ax_result ok ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv wifi "$(ax_get global wifi_on)"
    ax_json_kv bt "$(ax_get global bluetooth_on)"
    ax_json_kv airplane "$(ax_get global airplane_mode_on)"
    ax_json_kv data "$(ax_get global mobile_data)"
    ax_json_kv nfc "$(ax_get global nfc_on)"
    ax_json_kv autobright "$(ax_get system screen_brightness_mode)"
    ax_json_kv rotate "$(ax_get system accelerometer_rotation)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
