#!/system/bin/sh
# =============================================================================
# boot_control_ax — 开机自启组件管控
# -----------------------------------------------------------------------------
# 组件级停用 BOOT_COMPLETED 接收器，而不是直接停掉整个应用 ——
# 这样应用仍可手动打开，只是不再随开机自动启动。
#   ✓ cmd package query-intent-receivers  查询响应开机广播的组件
#   ✓ pm disable-user --user 0 <component> 停用单个组件
# 由于 shell 无法读取组件的启用状态，本插件自行维护已停用清单，
# 该清单同时用于一键恢复。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=smart
AX_FROZEN="$AX_STATE/frozen"

# 通讯与常用应用白名单
AX_BOOT_KEEP='com.tencent.mm
com.tencent.mobileqq
com.tencent.tim
com.eg.android.AlipayGphone
com.taobao.taobao
com.tencent.wework
com.alibaba.android.rimet
com.android.mms
com.android.dialer
com.android.contacts
com.google.android.gms'

_keep() { echo "$AX_BOOT_KEEP" | grep -qx "$1"; }
_is_frozen() { [ -f "$AX_FROZEN" ] && grep -qx "$1" "$AX_FROZEN" 2>/dev/null; }
_mark() { _is_frozen "$1" || echo "$1" >>"$AX_FROZEN"; }
_unmark() {
    [ -f "$AX_FROZEN" ] || return 0
    grep -vx "$1" "$AX_FROZEN" >"$AX_FROZEN.t" 2>/dev/null && mv "$AX_FROZEN.t" "$AX_FROZEN"
}

# 查询所有响应开机广播的接收器组件
_scan() {
    cmd package query-intent-receivers --brief -a android.intent.action.BOOT_COMPLETED 2>/dev/null |
        tr -d '\r' | tr ' ' '\n' | grep -E '^[a-zA-Z][a-zA-Z0-9._]*/' 2>/dev/null
    # 兼容部分 ROM：附加锁定屏幕与快速启动广播
    cmd package query-intent-receivers --brief -a android.intent.action.LOCKED_BOOT_COMPLETED 2>/dev/null |
        tr -d '\r' | tr ' ' '\n' | grep -E '^[a-zA-Z][a-zA-Z0-9._]*/' 2>/dev/null
}

_apply_scope() {
    # $1 = 作用域：all 全部第三方 | aggressive 含系统应用
    _n=0; _k=0
    for _c in $(_scan | sort -u); do
        _p=$(echo "$_c" | cut -d/ -f1)
        if [ "$1" != "aggressive" ]; then
            case "$_p" in
            com.android.*|com.google.android.*|android) continue ;;
            esac
        fi
        if _keep "$_p"; then _k=$((_k + 1)); continue; fi
        ax_comp_disable "$_c" >/dev/null 2>&1 && { _mark "$_c"; _n=$((_n + 1)); }
    done
    AX_TOUCHED=$((AX_TOUCHED + 1))
    ax_ok "已停用 $_n 个开机自启组件（白名单豁免 $_k 个）"
}

apply_profile() {
    case "$1" in
    aggressive)
        ax_step "激进控制：停用全部可停用的开机自启组件"
        _apply_scope aggressive
        ax_warn "部分应用的后台服务与推送可能失效"
        ;;

    smart)
        ax_step "智能管理：仅停用第三方应用的开机自启"
        _apply_scope all
        ;;

    allowall)
        ax_step "全部放行：恢复此前停用的开机自启组件"
        if [ -s "$AX_FROZEN" ]; then
            _n=0
            while IFS= read -r _c; do
                ax_comp_enable "$_c" >/dev/null 2>&1 && _n=$((_n + 1))
            done <"$AX_FROZEN"
            rm -f "$AX_FROZEN" 2>/dev/null
            ax_ok "已恢复 $_n 个组件"
        else
            ax_info "没有需要恢复的组件"
        fi
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    scan)
        for _c in $(_scan | sort -u | head -80); do
            _p=$(echo "$_c" | cut -d/ -f1)
            if _is_frozen "$_c"; then
                printf '%s|%s|已停用|ok\n' "${_c##*/}" "$_p"
            elif _keep "$_p"; then
                printf '%s|%s|白名单|dim\n' "${_c##*/}" "$_p"
            else
                printf '%s|%s|自启中|warn\n' "${_c##*/}" "$_p"
            fi
        done
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(_scan 2>/dev/null | sort -u | grep -c . 2>/dev/null)
    _f=0
    [ -f "$AX_FROZEN" ] && _f=$(grep -c . "$AX_FROZEN" 2>/dev/null)
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv total "${_t:-0}"
    ax_json_kv frozen "$(ax_num "$_f")"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
