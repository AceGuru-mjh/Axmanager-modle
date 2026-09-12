#!/system/bin/sh
# =============================================================================
# adb_toolbox_ax — ADB 常用工具箱
# -----------------------------------------------------------------------------
# 汇集 shell 身份下最常用的一组 adb 命令，全部为系统内置工具：
#   screencap / screenrecord / wm / svc / pm / am / input / dumpsys
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_shot() {
    _f="/sdcard/ax_shot_$(date +%y%m%d_%H%M%S).png"
    if screencap -p "$_f" 2>/dev/null && [ -s "$_f" ]; then
        ax_ok "截图已保存：$_f"
        return 0
    fi
    ax_err "截图失败"
    return 1
}

ax_custom() {
    case "$1" in
    shot) _shot && ax_result ok || ax_result fail ;;

    rec)
        _f="/sdcard/ax_rec_$(date +%y%m%d_%H%M%S).mp4"
        ax_step "开始录制 10 秒（最长 180 秒限制）"
        if screenrecord --time-limit 10 --bit-rate 8000000 "$_f" >/dev/null 2>&1 && [ -s "$_f" ]; then
            _s=$(du -k "$_f" 2>/dev/null | cut -f1)
            ax_ok "录屏已保存：$_f（${_s} KB）"
        else
            ax_warn "录屏失败：部分设备或 ROM 不支持 screenrecord"
        fi
        ax_result ok
        ;;

    dpi)
        [ -z "$2" ] && { ax_err "缺少 DPI 值"; ax_result fail; return 1; }
        if [ "$2" = "reset" ]; then
            wm density reset >/dev/null 2>&1 && ax_ok "DPI 已恢复默认"
        else
            wm density "$2" >/dev/null 2>&1 && ax_ok "DPI 已设置为 $2" || ax_warn "设置失败"
            ax_info "恢复方法：在下方输入 reset"
        fi
        ax_result ok
        ;;

    size)
        [ -z "$2" ] && { ax_err "格式：宽x高 或 reset"; ax_result fail; return 1; }
        if [ "$2" = "reset" ]; then
            wm size reset >/dev/null 2>&1 && ax_ok "分辨率已恢复默认"
        else
            wm size "$2" >/dev/null 2>&1 && ax_ok "分辨率已设置为 $2" || ax_warn "设置失败"
        fi
        ax_result ok
        ;;

    wmreset)
        wm density reset >/dev/null 2>&1
        wm size reset >/dev/null 2>&1
        ax_ok "显示参数已全部恢复默认"
        ax_result ok
        ;;

    wifion)  svc wifi enable  >/dev/null 2>&1 && ax_ok "Wi-Fi 已开启"  || ax_warn "操作被拒绝"; ax_result ok ;;
    wifioff) svc wifi disable >/dev/null 2>&1 && ax_ok "Wi-Fi 已关闭"  || ax_warn "操作被拒绝"; ax_result ok ;;
    dataon)  svc data enable  >/dev/null 2>&1 && ax_ok "移动数据已开启" || ax_warn "操作被拒绝"; ax_result ok ;;
    dataoff) svc data disable >/dev/null 2>&1 && ax_ok "移动数据已关闭" || ax_warn "操作被拒绝"; ax_result ok ;;
    nfcoff)  svc nfc disable  >/dev/null 2>&1 && ax_ok "NFC 已关闭"     || ax_warn "操作被拒绝"; ax_result ok ;;
    stayon)  svc power stayon true  >/dev/null 2>&1 && ax_ok "充电时保持唤醒已开启"; ax_result ok ;;
    stayoff) svc power stayon false >/dev/null 2>&1 && ax_ok "保持唤醒已关闭"; ax_result ok ;;

    ui)
        _old=$(pidof com.android.systemui 2>/dev/null)
        killall com.android.systemui 2>/dev/null || am force-stop --user 0 com.android.systemui 2>/dev/null
        sleep 2
        if [ "$_old" != "$(pidof com.android.systemui 2>/dev/null)" ]; then
            ax_ok "SystemUI 已重启"
        else
            ax_warn "SystemUI 未重启（ROM 禁止 shell 结束该系统进程）"
        fi
        ax_result ok
        ;;

    devinfo)
        ax_head "设备信息"
        ax_info "机型：$(getprop ro.product.model) $(getprop ro.product.brand)"
        ax_info "系统：Android $(getprop ro.build.version.release) · API $(ax_api)"
        ax_info "分辨率：$(wm size 2>/dev/null | tail -1)"
        ax_info "DPI：$(wm density 2>/dev/null | tail -1)"
        ax_info "CPU 核心：$(ax_cpu_cores)"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv model "$(getprop ro.product.model)"
    ax_json_kv android "$(getprop ro.build.version.release)"
    ax_json_kv size "$(wm size 2>/dev/null | tail -1 | sed 's/.*: //')"
    ax_json_kv density "$(wm density 2>/dev/null | tail -1 | sed 's/.*: //')"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
