#!/system/bin/sh
# =============================================================================
# logcat_toolbox_ax — 日志查看与导出
# -----------------------------------------------------------------------------
#   ✓ logcat -d -v time -t N           读取最近 N 条
#   ✓ logcat -d *:E                    仅错误级别
#   ✓ logcat -d -s <tag>               按标签过滤
#   ✓ logcat -c -b all                 清空全部缓冲区
#   ✓ logcat -b all -d > /sdcard/...   导出完整日志
#   ✓ dumpsys > /sdcard/...            导出诊断包
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_OUT=/sdcard/ax_logs

ax_custom() {
    case "$1" in
    tail)
        logcat -d -v time -t 120 2>&1 | head -120
        ax_result ok
        ;;

    error)
        logcat -d -v time *:E 2>&1 | head -80
        ax_result ok
        ;;

    warn)
        logcat -d -v time *:W 2>&1 | head -80
        ax_result ok
        ;;

    tag)
        [ -z "$2" ] && { ax_err "缺少标签"; ax_result fail; return 1; }
        logcat -d -v time -s "$2" 2>&1 | head -100
        ax_result ok
        ;;

    grep)
        [ -z "$2" ] && { ax_err "缺少关键词"; ax_result fail; return 1; }
        logcat -d -v time 2>&1 | grep -i "$2" | head -80
        ax_result ok
        ;;

    clear)
        logcat -c -b all >/dev/null 2>&1 && ax_ok "全部日志缓冲区已清空" || ax_warn "清空失败"
        ax_result ok
        ;;

    export)
        mkdir -p "$AX_OUT" 2>/dev/null
        _f="$AX_OUT/logcat_$(date +%y%m%d_%H%M%S).txt"
        if logcat -d -v time -b all >"$_f" 2>/dev/null && [ -s "$_f" ]; then
            _s=$(du -k "$_f" 2>/dev/null | cut -f1)
            ax_ok "日志已导出：$_f（${_s} KB）"
        else
            ax_err "导出失败，请检查存储权限"
        fi
        ax_result ok
        ;;

    bugreport)
        mkdir -p "$AX_OUT" 2>/dev/null
        _f="$AX_OUT/dumpsys_$(date +%y%m%d_%H%M%S).txt"
        ax_step "正在收集系统服务状态，请稍候…"
        {
            echo "=== 构建信息 ==="
            getprop ro.build.display.id
            getprop ro.product.model
            echo ""
            echo "=== 电池 ==="
            dumpsys battery
            echo ""
            echo "=== 内存 ==="
            dumpsys meminfo | head -20
        } >"$_f" 2>&1
        [ -s "$_f" ] && ax_ok "诊断信息已导出：$_f" || ax_err "导出失败"
        ax_result ok
        ;;

    list)
        if [ -d "$AX_OUT" ]; then
            ls -1 "$AX_OUT" 2>/dev/null | while IFS= read -r _f; do
                _s=$(du -k "$AX_OUT/$_f" 2>/dev/null | cut -f1)
                printf '%s|%s KB|已导出|ok\n' "$_f" "${_s:-0}"
            done
        fi
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    _n=0
    [ -d "$AX_OUT" ] && _n=$(ls -1 "$AX_OUT" 2>/dev/null | grep -c .)
    ax_json_begin
    ax_json_kv files "$(ax_num "$_n")"
    ax_json_kv lines "$(logcat -d 2>/dev/null | grep -c .)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
