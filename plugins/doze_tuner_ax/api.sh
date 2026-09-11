#!/system/bin/sh
# =============================================================================
# doze_tuner_ax — 后台行为与待机分组
# -----------------------------------------------------------------------------
# 【边界】Doze 内部参数（inactive_to / sensing_to 等）位于 deviceidle 的
#         XML 与 settings 私有键，需要 root 或系统签名才能持久化修改。
# 【实际手段】用系统公开的待机分组与后台运行权限接口实现等效效果：
#   ✓ am set-standby-bucket <pkg> active|working_set|frequent|rare|restricted
#   ✓ appops set <pkg> RUN_IN_BACKGROUND allow|deny    后台运行
#   ✓ appops set <pkg> RUN_ANY_IN_BACKGROUND allow|deny
#   ✓ appops set <pkg> WAKE_LOCK allow|deny            唤醒锁
#   通讯类应用默认在白名单内，避免漏收消息。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

# 通讯与常用应用白名单：这些应用必须保持活跃，否则漏收消息
AX_IM_WHITELIST='com.tencent.mm
com.tencent.mobileqq
com.tencent.tim
com.eg.android.AlipayGphone
com.taobao.taobao
com.tencent.wework
com.alibaba.android.rimet
com.ss.android.ugc.aweme
com.sina.weibo
com.google.android.gm
com.whatsapp
org.telegram.messenger
com.android.mms
com.android.dialer
com.android.contacts
com.android.email'

_keep() { echo "$AX_IM_WHITELIST" | grep -qx "$1"; }

_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

_apply_bucket() {
    _n=0; _s=0
    for _p in $(_apps); do
        if _keep "$_p"; then
            am set-standby-bucket "$_p" active >/dev/null 2>&1
            _s=$((_s + 1))
            continue
        fi
        am set-standby-bucket "$_p" "$1" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    _ax_journal_add meta bucket "$AX_NULL" "$1"
    AX_TOUCHED=$((AX_TOUCHED + 1))
    ax_ok "已调整 $_n 个应用的待机分组为 $1（白名单豁免 $_s 个）"
}

_apply_op() {
    _n=0
    for _p in $(_apps); do
        _keep "$_p" && continue
        appops set "$_p" "$1" "$2" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    _ax_journal_add meta op "$1" "$2"
    AX_TOUCHED=$((AX_TOUCHED + 1))
    ax_ok "$1 = $2 已应用于 $_n 个应用"
}

apply_profile() {
    case "$1" in
    aggressive)
        ax_step "激进省电：限制后台运行并收紧待机分组"
        _apply_bucket restricted
        _apply_op RUN_IN_BACKGROUND deny
        _apply_op RUN_ANY_IN_BACKGROUND deny
        _apply_op WAKE_LOCK deny
        ax_warn "被限制的应用在后台将不会同步数据，可能影响消息及时性"
        ;;

    balanced)
        ax_step "均衡待机：常用分组，允许受限后台活动"
        _apply_bucket working_set
        _apply_op RUN_IN_BACKGROUND allow
        _apply_op RUN_ANY_IN_BACKGROUND allow
        _apply_op WAKE_LOCK allow
        ;;

    default)
        ax_step "原厂默认：恢复活跃分组与全部后台权限"
        _apply_bucket active
        _apply_op RUN_IN_BACKGROUND allow
        _apply_op RUN_ANY_IN_BACKGROUND allow
        _apply_op WAKE_LOCK allow
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    buckets)
        ax_head "第三方应用待机分组"
        for _p in $(_apps | head -40); do
            _b=$(am get-standby-bucket "$_p" 2>/dev/null | tr -d '\r')
            [ -z "$_b" ] && _b="未知"
            if _keep "$_p"; then
                printf '%s|%s|白名单|ok\n' "$_p" "$_b"
            else
                printf '%s|%s|受限管理|dim\n' "$_p" "$_b"
            fi
        done
        ax_result ok
        ;;
    idle)
        ax_head "Doze 状态"
        dumpsys deviceidle 2>/dev/null | head -12
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv apps "$(_apps | grep -c .)"
    ax_json_kv state "$(dumpsys deviceidle 2>/dev/null | grep -oE 'mState=[A-Z_]+' | head -1 | cut -d= -f2)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
