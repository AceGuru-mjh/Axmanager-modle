#!/system/bin/sh
# =============================================================================
# reading_mode_ax — 阅读与护眼模式
# -----------------------------------------------------------------------------
#   ✓ settings secure night_display_activated           夜间显示开关
#   ✓ settings secure night_display_color_temperature   色温 (1000~10000K)
#   ✓ settings secure night_display_auto_mode           自动启用时段
#   ✓ settings secure accessibility_display_daltonizer* 灰度 / 色彩校正
#   ✓ settings secure accessibility_display_inversion_enabled  色彩反转
#   ✓ settings system screen_brightness / screen_off_timeout
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=standard

_gray() {
    if ax_set_secure accessibility_display_daltonizer_enabled "$1"; then
        [ "$1" = "1" ] && ax_set_secure accessibility_display_daltonizer 0
        return 0
    fi
    return 1
}

apply_profile() {
    case "$1" in
    standard)
        ax_step "标准默认：关闭灰度与色彩辅助，恢复自动亮度"
        _gray 0
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure night_display_activated 0
        ax_set_system screen_brightness_mode 1
        ;;

    reading)
        ax_step "沉浸阅读：灰度显示 + 夜间暖色"
        _gray 1
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure night_display_activated 1
        ax_set_secure night_display_color_temperature 2700
        ax_set_system screen_brightness_mode 0
        ax_set_system screen_brightness 120
        ax_info "灰度显示可显著降低阅读时的视觉刺激"
        ;;

    dark)
        ax_step "极暗护眼：最低亮度 + 暖色温"
        _gray 0
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure night_display_activated 1
        ax_set_secure night_display_color_temperature 1800
        ax_set_system screen_brightness_mode 0
        ax_set_system screen_brightness 30
        ax_warn "极低亮度在强光环境下可能看不清屏幕"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    grayon)  _gray 1 && ax_ok "灰度显示已开启";  ax_result ok ;;
    grayoff) _gray 0 && ax_ok "灰度显示已关闭";  ax_result ok ;;
    invert)  ax_set_secure accessibility_display_inversion_enabled 1 && ax_ok "色彩反转已开启"; ax_result ok ;;
    restore)
        _gray 0
        ax_set_secure accessibility_display_inversion_enabled 0
        ax_set_secure night_display_activated 0
        ax_set_system screen_brightness_mode 1
        ax_ok "已恢复标准显示"
        ax_result ok
        ;;
    state)
        ax_head "阅读模式状态"
        ax_info "夜间显示 = $(ax_get secure night_display_activated)"
        ax_info "色温 = $(ax_get secure night_display_color_temperature)"
        ax_info "灰度 = $(ax_get secure accessibility_display_daltonizer_enabled)"
        ax_info "色彩反转 = $(ax_get secure accessibility_display_inversion_enabled)"
        ax_info "亮度 = $(ax_get system screen_brightness) / 自动亮度 = $(ax_get system screen_brightness_mode)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv night "$(ax_get secure night_display_activated)"
    ax_json_kv temp "$(ax_get secure night_display_color_temperature)"
    ax_json_kv gray "$(ax_get secure accessibility_display_daltonizer_enabled)"
    ax_json_kv bright "$(ax_get system screen_brightness)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
