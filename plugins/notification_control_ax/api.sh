#!/system/bin/sh
# =============================================================================
# notification_control_ax — 通知与免打扰控制
# -----------------------------------------------------------------------------
#   ✓ settings global heads_up_notifications_enabled   悬浮通知
#   ✓ cmd notification set_dnd on|off                  免打扰（DND）
#   ✓ appops set <pkg> POST_NOTIFICATION allow|deny    单应用通知权限 (API 33+)
#   ✓ settings global zen_mode                         只读禅定模式状态
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=standard

AX_NOTIFY_KEEP='com.tencent.mm
com.tencent.mobileqq
com.android.dialer
com.android.mms
com.android.contacts
com.tencent.wework
com.alibaba.android.rimet
com.android.email
com.google.android.gm'

_keep() { echo "$AX_NOTIFY_KEEP" | grep -qx "$1"; }

_dnd() {
    if cmd notification set_dnd "$1" >/dev/null 2>&1; then
        _ax_journal_add meta dnd "$AX_NULL" "$1"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "免打扰已${2}"
        return 0
    fi
    ax_warn "免打扰设置失败（部分 ROM 限制 shell 调用）"
    AX_SKIPPED=$((AX_SKIPPED + 1))
    return 1
}

_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

apply_profile() {
    case "$1" in
    focus)
        ax_step "专注模式：关闭悬浮通知并开启免打扰"
        ax_set_global heads_up_notifications_enabled 0
        _dnd on 开启
        ax_need_api 33 "单应用通知权限" && {
            _n=0
            for _p in $(_apps); do
                _keep "$_p" && continue
                appops set "$_p" POST_NOTIFICATION deny >/dev/null 2>&1 && _n=$((_n + 1))
            done
            _ax_journal_add meta post_notification "$AX_NULL" deny
            AX_TOUCHED=$((AX_TOUCHED + 1))
            ax_ok "已屏蔽 $_n 个应用的通知（白名单豁免）"
        }
        ;;

    standard)
        ax_step "标准管理：开启悬浮通知，关闭免打扰"
        ax_set_global heads_up_notifications_enabled 1
        _dnd off 关闭
        ax_need_api 33 "单应用通知权限" && {
            _n=0
            for _p in $(_apps); do
                appops set "$_p" POST_NOTIFICATION allow >/dev/null 2>&1 && _n=$((_n + 1))
            done
            AX_TOUCHED=$((AX_TOUCHED + 1))
            ax_ok "已恢复 $_n 个应用的通知权限"
        }
        ;;

    allon)
        ax_step "全部开启：悬浮通知开启，免打扰关闭"
        ax_set_global heads_up_notifications_enabled 1
        _dnd off 关闭
        ax_info "如需恢复被本插件屏蔽的应用，请点击「恢复全部通知」"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    restoreall)
        ax_need_api 33 "单应用通知权限" || { ax_result fail; return 1; }
        _n=0
        for _p in $(_apps); do
            appops set "$_p" POST_NOTIFICATION allow >/dev/null 2>&1 && _n=$((_n + 1))
        done
        ax_ok "已恢复 $_n 个应用的通知权限"
        ax_result ok
        ;;
    dndon)  _dnd on 开启;  ax_result ok ;;
    dndoff) _dnd off 关闭; ax_result ok ;;
    zenstate)
        ax_head "免打扰状态"
        ax_info "zen_mode = $(ax_get global zen_mode)"
        ax_info "免打扰状态 = $(ax_get global zen_mode_config_etag | cut -c1-20)"
        ax_info "heads_up_notifications_enabled = $(ax_get global heads_up_notifications_enabled)"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv heads "$(ax_get global heads_up_notifications_enabled)"
    ax_json_kv zen "$(ax_get global zen_mode)"
    ax_json_kv apps "$(_apps | grep -c .)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
