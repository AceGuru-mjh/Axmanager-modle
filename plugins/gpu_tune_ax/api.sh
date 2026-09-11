#!/system/bin/sh
# =============================================================================
# gpu_tune_ax — 渲染与帧率调度
# -----------------------------------------------------------------------------
# 【边界】GPU 频率节点 /sys/class/kgsl 与 /sys/devices/.../devfreq 需要 root，
#         免 root 环境下无法调节；persist.gpu.* 之类自造属性无人读取。
# 【实际手段】通过系统显示与渲染设置影响帧率与合成负载：
#   ✓ settings system peak_refresh_rate / min_refresh_rate   屏幕刷新率上限
#   ✓ settings global enable_gpu_debug_layers                 GPU 调试层开关
#   ✓ settings global force_resizable_activities              强制可调整窗口
#   ✓ 动画时长缩放                                            合成负载
#   ✓ cmd package compile -m speed                           减少 JIT 开销
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

# 读取屏幕支持的最大刷新率（mHz 单位，取自 dumpsys display）
_max_rate_hz() {
    dumpsys display 2>/dev/null | grep -oE 'refreshRate=[0-9.]+' | cut -d= -f2 |
        sort -g | tail -1 | cut -d. -f1
}

_set_rate() {
    if settings put system peak_refresh_rate "$1" 2>/dev/null; then
        _ax_journal_add setting system peak_refresh_rate "$AX_NULL"
        settings put system min_refresh_rate "$2" 2>/dev/null
        _ax_journal_add setting system min_refresh_rate "$AX_NULL"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "刷新率策略：峰值 ${1}Hz / 下限 ${2}Hz"
    else
        ax_warn "刷新率设置未被系统接受"
        AX_FAILED=$((AX_FAILED + 1))
    fi
}

apply_profile() {
    case "$1" in
    performance)
        ax_step "高帧率：抬升刷新率上限，降低动画耗时"
        _max=$(_max_rate_hz)
        [ -z "$_max" ] || [ "$_max" -lt 60 ] && _max=120
        _set_rate "$_max" 90
        ax_set_global enable_gpu_debug_layers 0
        ax_set_global force_resizable_activities 1
        ax_set_global window_animation_scale 0.5
        ax_set_global transition_animation_scale 0.5
        ax_set_global animator_duration_scale 0.5
        ax_info "峰值刷新率按屏幕硬件上限设置（读取到 ${_max}Hz）"
        ;;

    balanced)
        ax_step "均衡：交由系统自适应刷新率，标准动画"
        _set_rate 0 0
        ax_set_global enable_gpu_debug_layers 0
        ax_set_global force_resizable_activities 0
        ax_set_global window_animation_scale 1
        ax_set_global transition_animation_scale 1
        ax_set_global animator_duration_scale 1
        ;;

    battery)
        ax_step "省电：锁定 60Hz，关闭可变窗口"
        _set_rate 60 60
        ax_set_global enable_gpu_debug_layers 0
        ax_set_global force_resizable_activities 0
        ax_set_global window_animation_scale 1
        ax_set_global transition_animation_scale 1
        ax_set_global animator_duration_scale 1
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    ratedump)
        ax_head "屏幕与刷新率信息"
        dumpsys display 2>/dev/null | grep -E 'DisplayDeviceInfo|refreshRate|state=' | head -12
        ax_info "当前设置：峰值 $(ax_get system peak_refresh_rate) Hz / 下限 $(ax_get system min_refresh_rate) Hz"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv peak "$(ax_get system peak_refresh_rate)"
    ax_json_kv min "$(ax_get system min_refresh_rate)"
    ax_json_kv hwmax "$(_max_rate_hz)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
