#!/system/bin/sh
# =============================================================================
# sensor_tuner_ax — 传感器相关功能开关
# -----------------------------------------------------------------------------
# 【边界】传感器的采样率与量程由 HAL 与驱动决定（/sys/class/sensors 与
#         传感器服务内部配置），免 root 无法修改采样频率。
# 【实际手段】控制「哪些功能会持续调用传感器」，从而真实影响耗电与体验：
#   ✓ settings secure doze_pulse_on_pick_up    抬起亮屏（加速度计/陀螺仪）
#   ✓ settings secure doze_wake_screen_gesture 手势唤醒
#   ✓ settings secure doze_enabled              环境显示（屏幕灭时监听）
#   ✓ settings secure wake_gesture_enabled      抬手唤醒
#   ✓ settings system accelerometer_rotation    自动旋转
#   ✓ dumpsys sensorservice                     只读查看传感器清单
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

apply_profile() {
    case "$1" in
    full)
        ax_step "功能全开：启用全部体感与自动旋转"
        ax_set_secure doze_enabled 1
        ax_set_secure doze_pulse_on_pick_up 1
        ax_set_secure doze_wake_screen_gesture 1
        ax_set_secure wake_gesture_enabled 1
        ax_set_secure doze_tap_gesture 1
        ax_set_system accelerometer_rotation 1
        ;;

    balanced)
        ax_step "日常：保留抬起亮屏与自动旋转，关闭手势唤醒"
        ax_set_secure doze_enabled 1
        ax_set_secure doze_pulse_on_pick_up 1
        ax_set_secure doze_wake_screen_gesture 0
        ax_set_secure wake_gesture_enabled 0
        ax_set_secure doze_tap_gesture 0
        ax_set_system accelerometer_rotation 1
        ;;

    saving)
        ax_step "省电：关闭全部持续监听传感器的体感功能"
        ax_set_secure doze_enabled 0
        ax_set_secure doze_pulse_on_pick_up 0
        ax_set_secure doze_wake_screen_gesture 0
        ax_set_secure wake_gesture_enabled 0
        ax_set_secure doze_tap_gesture 0
        ax_set_system accelerometer_rotation 0
        ax_info "关闭后屏幕熄灭时不再采样运动传感器，可明显降低待机耗电"
        ;;

    *) return 1 ;;
    esac
    return 0
}

_sensor_count() {
    dumpsys sensorservice 2>/dev/null | grep -cE '^\s+(0x[0-9a-fA-F]+)' 2>/dev/null ||
        dumpsys sensorservice 2>/dev/null | grep -c 'Sensor Type'
}

ax_custom() {
    case "$1" in
    list)
        ax_head "传感器清单"
        dumpsys sensorservice 2>/dev/null | grep -E 'Sensor Type|String Type|Vendor|Resolution' | head -40
        ax_result ok
        ;;
    state)
        ax_head "当前体感开关"
        for _k in doze_pulse_on_pick_up doze_wake_screen_gesture wake_gesture_enabled \
                  doze_tap_gesture doze_enabled; do
            ax_info "$_k = $(ax_get secure "$_k")"
        done
        ax_info "accelerometer_rotation = $(ax_get system accelerometer_rotation)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv count "$(ax_num "$(_sensor_count)")"
    ax_json_kv lift "$(ax_get secure doze_pulse_on_pick_up)"
    ax_json_kv rotate "$(ax_get system accelerometer_rotation)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
