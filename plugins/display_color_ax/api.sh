#!/system/bin/sh
# =============================================================================
# display_color_ax — 屏幕亮度与色彩辅助
# -----------------------------------------------------------------------------
# 【边界】饱和度 / 色域 / 背光曲线由 SurfaceFlinger 与显示驱动控制，
#        需要 root 写入 /sys 或厂商节点，免 root 无法调整。
# 【实际手段】这些是 AOSP 提供且 shell 可写、效果立即可见的显示设置：
#   ✓ settings system screen_brightness           屏幕亮度
#   ✓ settings system screen_brightness_mode      自动亮度
#   ✓ settings secure night_display_activated     夜间显示（色温）
#   ✓ settings secure night_display_color_temperature   色温值
#   ✓ settings secure accessibility_display_inversion_enabled  色彩反转
#   ✓ settings secure accessibility_display_daltonizer*       灰度 / 色彩校正
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=standard

_brightness() {
    ax_set_system screen_brightness "$1" && ax_ok "亮度已设置为 $1/255"
}

_night() {
    ax_set_secure night_display_activated "$1"
    if [ -n "$2" ] && [ "$1" = "1" ]; then
        ax_set_secure night_display_color_temperature "$2"
        ax_ok "夜间显示色温 $2K"
    fi
}

apply_profile() {
    case "$1" in
    standard)
        ax_step "标准原色：关闭全部色彩辅助"
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure accessibility_display_daltonizer_enabled 0
        _night 0
        ax_set_system screen_brightness_mode 1
        ax_info "亮度交由自动亮度管理"
        ;;

    vivid)
        ax_step "高亮模式：关闭色彩辅助，提高亮度上限"
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure accessibility_display_daltonizer_enabled 0
        _night 0
        ax_set_system screen_brightness_mode 0
        _brightness 255
        ax_warn "锁定最高亮度会明显增加耗电"
        ;;

    warm)
        ax_step "护眼低亮：开启夜间显示并降低亮度"
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure accessibility_display_daltonizer_enabled 0
        _night 1 2400
        ax_set_system screen_brightness_mode 0
        _brightness 90
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    gray)
        ax_set_secure accessibility_display_daltonizer_enabled 1
        ax_set_secure accessibility_display_daltonizer 0
        ax_ok "已开启灰度显示"
        ax_result ok
        ;;
    invert)
        ax_set_secure accessibility_display_inversion_enabled 1
        ax_ok "已开启色彩反转"
        ax_result ok
        ;;
    reset)
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure accessibility_display_daltonizer_enabled 0
        _night 0
        ax_set_system screen_brightness_mode 1
        ax_ok "显示色彩已恢复"
        ax_result ok
        ;;
    info)
        ax_head "显示设置"
        ax_info "亮度 = $(ax_get system screen_brightness) / 自动亮度 = $(ax_get system screen_brightness_mode)"
        ax_info "夜间显示 = $(ax_get secure night_display_activated) / 色温 = $(ax_get secure night_display_color_temperature)"
        ax_info "色彩反转 = $(ax_get secure accessibility_display_inversion_enabled)"
        ax_info "色彩校正 = $(ax_get secure accessibility_display_daltonizer_enabled)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv bright "$(ax_get system screen_brightness)"
    ax_json_kv auto "$(ax_get system screen_brightness_mode)"
    ax_json_kv night "$(ax_get secure night_display_activated)"
    ax_json_kv temp "$(ax_get secure night_display_color_temperature)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
