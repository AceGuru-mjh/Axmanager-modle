#!/system/bin/sh
# =============================================================================
# audio_balance_ax — 音量与声道平衡
# -----------------------------------------------------------------------------
#   ✓ media volume --stream <n> --set/--get   各音频流音量（系统真实接口）
#   ✓ settings system master_balance          左右声道平衡 (-1.0 ~ 1.0)
#   ✓ settings system sound_effects_enabled   触摸音效
#   ✓ settings system haptic_feedback_enabled 触摸振动
#   ✓ settings system dtmf_tone               拨号键盘音
# 音频流编号：0 通话 / 1 系统 / 2 铃声 / 3 媒体 / 4 闹钟 / 5 通知 / 6 蓝牙
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

_vol() {
    if media volume --stream "$1" --set "$2" >/dev/null 2>&1; then
        _ax_journal_add meta volume "stream$1" "$AX_NULL"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    ax_warn "stream $1 音量设置失败"
    AX_SKIPPED=$((AX_SKIPPED + 1))
    return 1
}

_gv() { media volume --get --stream "$1" 2>/dev/null | grep -oE '[0-9]+' | head -1; }

apply_profile() {
    case "$1" in
    balanced)
        ax_step "原声标准：中等音量，声道居中，保留触感反馈"
        _vol 3 8
        _vol 2 6
        _vol 4 8
        _vol 5 6
        ax_set_system master_balance 0
        ax_set_system sound_effects_enabled 1
        ax_set_system haptic_feedback_enabled 1
        ax_set_system dtmf_tone 1
        ;;

    boost)
        ax_step "增强：抬升全部音量，关闭音效压缩干扰"
        _vol 3 14
        _vol 2 10
        _vol 4 12
        _vol 5 10
        ax_set_system master_balance 0
        ax_set_system sound_effects_enabled 0
        ax_set_system haptic_feedback_enabled 0
        ax_set_system dtmf_tone 0
        ax_warn "长时间高音量可能损伤听力，系统安全音量限制仍会生效"
        ;;

    callgain)
        ax_step "通话增益：抬升通话与蓝牙音量"
        _vol 0 15
        _vol 6 15
        _vol 3 6
        ax_set_system master_balance 0
        ax_info "通话音量上限由系统安全策略约束"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    setbal)
        [ -z "$2" ] && { ax_err "缺少平衡值（-1.0 ~ 1.0）"; ax_result fail; return 1; }
        ax_set_system master_balance "$2" && ax_ok "声道平衡已设置为 $2"
        ax_result ok
        ;;
    setvol)
        [ -z "$2" ] || [ -z "$3" ] && { ax_err "格式：流编号 音量"; ax_result fail; return 1; }
        _vol "$2" "$3" && ax_ok "stream $2 音量已设置为 $3"
        ax_result ok
        ;;
    dump)
        ax_head "音频状态"
        for _s in 0 1 2 3 4 5 6; do ax_info "stream $_s = $(_gv "$_s")"; done
        ax_info "master_balance = $(ax_get system master_balance)"
        ax_info "触摸音效 = $(ax_get system sound_effects_enabled) / 振动 = $(ax_get system haptic_feedback_enabled)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv music "$(_gv 3)"
    ax_json_kv ring "$(_gv 2)"
    ax_json_kv call "$(_gv 0)"
    ax_json_kv balance "$(ax_get system master_balance)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
