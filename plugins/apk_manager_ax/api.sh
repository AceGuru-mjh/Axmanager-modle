#!/system/bin/sh
# =============================================================================
# apk_manager_ax — APK 提取与权限审计
# -----------------------------------------------------------------------------
#   ✓ pm list packages -3        列出第三方应用
#   ✓ pm path <pkg>              取得 APK 路径
#   ✓ cat <apk> > /sdcard/...    导出 APK（shell 可读取已安装 APK）
#   ✓ pm dump <pkg>              读取已授予权限（只读审计）
#   ✓ pm uninstall --user 0 <pkg> 卸载第三方应用
#   ✗ 系统应用无法卸载（需 root），会如实报告
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=none
AX_OUT=/sdcard/ax_apks

AX_DANGEROUS='CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|READ_SMS|SEND_SMS|READ_CONTACTS|WRITE_CONTACTS|READ_CALL_LOG|CALL_PHONE|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|ACCESS_BACKGROUND_LOCATION|READ_PHONE_STATE|ACTIVITY_RECOGNITION|BODY_SENSORS'

_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }
_ver() { dumpsys package "$1" 2>/dev/null | grep -m1 'versionName=' | sed 's/.*versionName=//; s/ .*//'; }
_path() { pm path "$1" 2>/dev/null | head -1 | sed 's/^package://'; }

apply_profile() {
    # 本插件以按需操作为主，档位仅用于「批量导出范围」设置
    case "$1" in
    exportall)
        ax_step "导出全部第三方应用 APK"
        mkdir -p "$AX_OUT" 2>/dev/null
        _n=0
        for _p in $(_apps); do
            _a=$(_path "$_p")
            [ -z "$_a" ] && continue
            if cat "$_a" >"$AX_OUT/$_p.apk" 2>/dev/null && [ -s "$AX_OUT/$_p.apk" ]; then
                _n=$((_n + 1))
            else
                rm -f "$AX_OUT/$_p.apk" 2>/dev/null
            fi
        done
        ax_ok "已导出 $_n 个 APK 到 $AX_OUT"
        [ "$_n" -eq 0 ] && ax_warn "导出失败：可能是存储权限未授予"
        ;;

    none)
        ax_info "未选择批量操作，可使用下方单项工具"
        ;;

    *) return 1 ;;
    esac
    return 0
}

_export_one() {
    ax_pkg_exists "$1" || { ax_err "未安装：$1"; return 1; }
    _a=$(_path "$1")
    [ -z "$_a" ] && { ax_err "无法定位 APK 路径"; return 1; }
    mkdir -p "$AX_OUT" 2>/dev/null
    if cat "$_a" >"$AX_OUT/$1.apk" 2>/dev/null && [ -s "$AX_OUT/$1.apk" ]; then
        _s=$(du -k "$AX_OUT/$1.apk" 2>/dev/null | cut -f1)
        ax_ok "已导出：$AX_OUT/$1.apk（${_s} KB）"
    else
        ax_err "导出失败，请检查存储权限"
        return 1
    fi
}

ax_custom() {
    case "$1" in
    export) _export_one "$2" && ax_result ok || ax_result fail ;;

    audit)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_exists "$2" || { ax_err "未安装：$2"; ax_result fail; return 1; }
        ax_head "$2 已授予权限"
        _all=$(dumpsys package "$2" 2>/dev/null | grep -E 'granted=true' |
            grep -oE 'android\.permission\.[A-Za-z0-9_.]+' | sed 's/android.permission.//' | sort -u)
        if [ -z "$_all" ]; then
            ax_info "未查询到已授予权限"
        else
            echo "$_all" | while IFS= read -r _o; do
                if echo "$_o" | grep -qE "^($AX_DANGEROUS)$"; then
                    printf '%s|危险权限|高风险|err\n' "$_o"
                else
                    printf '%s|普通权限|低风险|dim\n' "$_o"
                fi
            done
        fi
        ax_result ok
        ;;

    auditall)
        ax_head "持有危险权限的第三方应用"
        for _p in $(_apps); do
            _d=$(dumpsys package "$_p" 2>/dev/null | grep -E 'granted=true' |
                grep -oE 'android\.permission\.[A-Za-z0-9_.]+' |
                grep -cE "^android\.permission\.($AX_DANGEROUS)$" 2>/dev/null)
            _d=$(ax_num "$_d")
            [ "$_d" -gt 0 ] && printf '%s|持有 %s 项危险权限|需关注|warn\n' "$_p" "$_d"
        done
        ax_result ok
        ;;

    list)
        for _p in $(_apps); do
            _v=$(_ver "$_p")
            _a=$(_path "$_p")
            _s=0
            [ -n "$_a" ] && _s=$(( $(stat -c%s "$_a" 2>/dev/null || echo 0) / 1024 ))
            printf '%s|%s|%sKB|dim\n' "$_p" "版本 ${_v:-未知}" "$_s"
        done
        ax_result ok
        ;;

    uninstall)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_protected "$2" && { ax_err "系统关键组件，拒绝卸载"; ax_result fail; return 1; }
        if pm uninstall --user 0 "$2" >/dev/null 2>&1; then
            ax_ok "已卸载 $2"
            ax_result ok
        else
            ax_warn "卸载失败：系统应用或受保护应用需要 root 才能卸载"
            ax_result fail
        fi
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv apps "$(_apps | grep -c .)"
    ax_json_kv out "$AX_OUT"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
