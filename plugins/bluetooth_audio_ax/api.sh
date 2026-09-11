#!/system/bin/sh
# =============================================================================
# bluetooth_audio_ax — 蓝牙与无线音频
# -----------------------------------------------------------------------------
# 【边界】蓝牙音频编码器（SBC/AAC/LDAC/aptX）与码率由蓝牙协议栈与厂商
#         属性控制，切换需要 root 或厂商私有接口，免 root 无法修改。
# 【实际手段】
#   ✓ svc bluetooth enable|disable               蓝牙开关
#   ✓ settings global ble_scan_always_enabled    后台蓝牙扫描（耗电与隐私）
#   ✓ media volume --stream 3 --set N            媒体音量
#   ✓ media volume --stream 6 --set N            蓝牙 SCO 音量
#   ✓ settings system master_balance             左右声道平衡
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

_media_vol() {
    if media volume --stream "$1" --set "$2" >/dev/null 2>&1; then
        _ax_journal_add meta volume "stream$1" "$AX_NULL"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        return 0
    fi
    ax_warn "音量调节失败（stream $1）"
    AX_SKIPPED=$((AX_SKIPPED + 1))
    return 1
}

_get_vol() {
    media volume --get --stream "$1" 2>/dev/null | grep -oE '[0-9]+' | head -1
}

apply_profile() {
    case "$1" in
    hifi)
        ax_step "高音质：关闭蓝牙后台扫描，抬升媒体与 SCO 音量"
        ax_set_global ble_scan_always_enabled 0
        _media_vol 3 12
        _media_vol 6 12
        ax_set_system master_balance 0
        ;;

    balanced)
        ax_step "标准均衡：保留扫描能力，中等音量"
        ax_set_global ble_scan_always_enabled 1
        _media_vol 3 8
        _media_vol 6 8
        ax_set_system master_balance 0
        ;;

    call)
        ax_step "通话优先：抬升蓝牙 SCO 音量，降低媒体音量"
        ax_set_global ble_scan_always_enabled 0
        _media_vol 6 15
        _media_vol 3 5
        ax_info "通话音量上限受系统安全音量限制约束"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    bton)  svc bluetooth enable  >/dev/null 2>&1 && ax_ok "蓝牙已开启"  || ax_warn "蓝牙开启失败"; ax_result ok ;;
    btoff) svc bluetooth disable >/dev/null 2>&1 && ax_ok "蓝牙已关闭"  || ax_warn "蓝牙关闭失败"; ax_result ok ;;
    volinfo)
        ax_head "各声道音量"
        for _s in 0 1 2 3 4 5 6; do
            ax_info "stream $_s = $(_get_vol "$_s")"
        done
        ax_info "master_balance = $(ax_get system master_balance)"
        ax_result ok
        ;;
    btdump)
        ax_head "蓝牙状态"
        ax_info "bluetooth_on = $(ax_get global bluetooth_on)"
        dumpsys bluetooth_manager 2>/dev/null | grep -E 'enabled:|state:|Bonded|Connected' | head -8
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv bton "$(ax_get global bluetooth_on)"
    ax_json_kv music "$(_get_vol 3)"
    ax_json_kv sco "$(_get_vol 6)"
    ax_json_kv balance "$(ax_get system master_balance)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
