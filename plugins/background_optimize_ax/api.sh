#!/system/bin/sh
# =============================================================================
# background_optimize_ax — 后台活动管控
# -----------------------------------------------------------------------------
#   ✓ am set-standby-bucket <pkg> <bucket>   待机分组（影响后台执行频率）
#   ✓ appops RUN_IN_BACKGROUND / RUN_ANY_IN_BACKGROUND  后台运行
#   ✓ appops WAKE_LOCK                       唤醒锁
#   ✓ cmd appops / appops get                只读查询
# 通讯应用默认加入白名单，避免漏收消息。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

AX_KEEP='com.tencent.mm
com.tencent.mobileqq
com.tencent.tim
com.eg.android.AlipayGphone
com.tencent.wework
com.alibaba.android.rimet
com.android.mms
com.android.dialer
com.google.android.gms'

_keep() { echo "$AX_KEEP" | grep -qx "$1"; }
_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

_bucket() {
    _n=0; _k=0
    for _p in $(_apps); do
        if _keep "$_p"; then
            am set-standby-bucket "$_p" active >/dev/null 2>&1
            _k=$((_k + 1))
            continue
        fi
        am set-standby-bucket "$_p" "$1" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    _ax_journal_add meta bucket "$AX_NULL" "$1"
    AX_TOUCHED=$((AX_TOUCHED + 1))
    ax_ok "待机分组 $1 已应用于 $_n 个应用（白名单豁免 $_k 个）"
}

_op() {
    _n=0
    for _p in $(_apps); do
        _keep "$_p" && continue
        appops set "$_p" "$1" "$2" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    _ax_journal_add meta op "$1" "$2"
    AX_TOUCHED=$((AX_TOUCHED + 1))
    ax_ok "$1=$2 已应用于 $_n 个应用"
}

apply_profile() {
    case "$1" in
    aggressive)
        ax_step "激进管控：限制后台运行与唤醒锁"
        _bucket restricted
        _op RUN_IN_BACKGROUND deny
        _op RUN_ANY_IN_BACKGROUND deny
        _op WAKE_LOCK deny
        ax_warn "可能会影响消息接收与后台同步"
        ;;

    balanced)
        ax_step "均衡管控：常用分组，限制非常驻后台"
        _bucket working_set
        _op RUN_IN_BACKGROUND allow
        _op RUN_ANY_IN_BACKGROUND deny
        _op WAKE_LOCK allow
        ;;

    loose)
        ax_step "宽松策略：恢复活跃分组与全部后台权限"
        _bucket active
        _op RUN_IN_BACKGROUND allow
        _op RUN_ANY_IN_BACKGROUND allow
        _op WAKE_LOCK allow
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    list)
        for _p in $(_apps | sort | head -60); do
            _b=$(am get-standby-bucket "$_p" 2>/dev/null | tr -d '\r')
            [ -z "$_b" ] && _b="未知"
            if _keep "$_p"; then
                printf '%s|待机分组 %s|白名单|ok\n' "$_p" "$_b"
            else
                printf '%s|待机分组 %s|受管控|dim\n' "$_p" "$_b"
            fi
        done
        ax_result ok
        ;;
    wakelock)
        ax_head "持有唤醒锁的应用"
        dumpsys power 2>/dev/null | grep -E 'Wake Locks|PARTIAL_WAKE_LOCK' | head -10
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv apps "$(_apps | grep -c .)"
    ax_json_kv locks "$(dumpsys power 2>/dev/null | grep -c 'Wake Locks' 2>/dev/null)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
