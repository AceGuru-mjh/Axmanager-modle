#!/system/bin/sh
# =============================================================================
# app_ops_manager_ax — 应用权限与行为精细管控
# -----------------------------------------------------------------------------
# appops 是免 root 环境下最精细的行为管控接口，可单独控制某个应用的某项操作：
#   ✓ appops get <pkg>              查询全部操作授权状态
#   ✓ appops set <pkg> <op> <mode>  设置（allow / deny / ignore / default）
# 常用 op：CAMERA、RECORD_AUDIO、ACCESS_FINE_LOCATION、READ_SMS、READ_CONTACTS、
#          READ_CLIPBOARD、POST_NOTIFICATION、RUN_IN_BACKGROUND、WAKE_LOCK、
#          READ_PHONE_STATE、WRITE_SETTINGS、SYSTEM_ALERT_WINDOW
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_fmt() {
    while IFS= read -r _l; do
        [ -z "$_l" ] && continue
        case "$_l" in
        Uid\ mode:*|*'No operations.'*) continue ;;
        esac
        _op=$(printf '%s' "$_l" | awk -F: '{print $1}' | tr -d ' ')
        _mode=$(printf '%s' "$_l" | awk -F: '{print $2}' | awk '{print $1}' | tr -d ';')
        [ -z "$_op" ] && continue
        case "$_mode" in
        allow)   _t=ok ;;
        deny)    _t=err ;;
        ignore)  _t=warn ;;
        default) _t=dim ;;
        *)       _t=dim ;;
        esac
        printf '%s|%s|%s|%s\n' "$_op" "模式 $_mode" "$_mode" "$_t"
    done
}

ax_custom() {
    case "$1" in
    query)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_exists "$2" || { ax_err "未安装：$2"; ax_result fail; return 1; }
        appops get "$2" 2>/dev/null | _fmt
        ax_result ok
        ;;

    deny)
        [ -z "$3" ] && { ax_err "格式：包名 操作名"; ax_result fail; return 1; }
        ax_pkg_protected "$2" && { ax_err "系统关键组件，拒绝操作"; ax_result fail; return 1; }
        if appops set "$2" "$3" deny >/dev/null 2>&1; then
            _ax_journal_add appops "$2" "$3" default
            ax_ok "已拒绝 $2 的 $3"
            ax_result ok
        else
            ax_err "设置失败：操作名可能不存在"
            ax_result fail
        fi
        ;;

    allow)
        [ -z "$3" ] && { ax_err "格式：包名 操作名"; ax_result fail; return 1; }
        if appops set "$2" "$3" allow >/dev/null 2>&1; then
            _ax_journal_add appops "$2" "$3" default
            ax_ok "已允许 $2 的 $3"
            ax_result ok
        else
            ax_err "设置失败：操作名可能不存在"
            ax_result fail
        fi
        ;;

    reset)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        appops reset --user 0 "$2" >/dev/null 2>&1 || appops reset "$2" >/dev/null 2>&1
        ax_ok "已重置 $2 的全部操作为默认"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv apps "$(pm list packages -3 2>/dev/null | grep -c .)"
    ax_json_kv api "$(ax_api)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
