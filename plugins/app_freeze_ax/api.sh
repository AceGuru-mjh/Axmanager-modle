#!/system/bin/sh
# =============================================================================
# app_freeze_ax — 预装冗余冻结精简
# -----------------------------------------------------------------------------
# 使用 pm disable-user --user 0（可逆，不删除任何文件）。
# 安全设计（旧版本缺失，曾可冻结 SystemUI 导致系统不可用）：
#   · axcore.sh 内置关键组件保护名单，命中即拒绝
#   · 所有被冻结的包写入回滚日志，可一键恢复
#   · 绝不 pm uninstall —— 卸载系统应用在恢复出厂前不可逆
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=light

# 匹配规则：包名包含以下关键词即视为可疑冗余
AX_BLOAT_KEYS='msa|analytics|adservice|adsdk|adx|feedback|bugreport|logkit|cloud|pushsdk|pushservice|unionservice|oppo.*log|vivo.*push|heytap|hms.*ads|samsung.*ad|facebook.*ads|gms.*ads|miui.*daemon|speech|voicetrigger|partnerbrowser|partnerbookmarks|htmlviewer|bookmarkprovider|stk|simapp|nosdn|wappush'

_apply() {
    _n=0
    for _p in $(_match_pkgs); do
        ax_pkg_disable "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    if [ "$_n" -gt 0 ]; then
        ax_ok "已冻结 $_n 个冗余组件"
        [ "${AX_VERBOSE:-1}" = "1" ] && ui_print "   被保护的关键组件与已冻结项均已记入日志"
    else
        ax_info "没有匹配到可冻结的组件（可能已被处理或厂商未预装）"
    fi
}

_match_pkgs() {
    pm list packages 2>/dev/null | sed 's/^package://' | grep -Ei "$AX_BLOAT_KEYS" 2>/dev/null
}

apply_profile() {
    case "$1" in
    deep)
        ax_step "深度精简：冻结全部匹配到的冗余组件"
        _apply
        ;;
    light)
        ax_step "轻度精简：仅冻结广告与数据上报类组件"
        _keys=$(echo "$AX_BLOAT_KEYS" | tr '|' '\n' | grep -E 'msa|analytics|adservice|adsdk|adx|unionservice|pushsdk' | paste -sd'|')
        _n=0
        for _p in $(pm list packages 2>/dev/null | sed 's/^package://' | grep -Ei "$_keys"); do
            ax_pkg_disable "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
        done
        ax_ok "已冻结 $_n 个广告/上报组件"
        ;;
    default)
        ax_step "恢复原厂：重新启用本插件冻结过的全部组件"
        _restore
        ;;
    *) return 1 ;;
    esac
    return 0
}

# 从回滚日志中取出 pkg 类型记录并重新启用
_restore() {
    [ -s "$AX_JOURNAL" ] || { ax_info "没有可恢复的记录"; return 0; }
    _n=0
    grep '^pkg	' "$AX_JOURNAL" 2>/dev/null | while IFS='	' read -r _t _p _x _y; do
        ax_pkg_enable "$_p" >/dev/null 2>&1
    done
    _n=$(grep -c '^pkg	' "$AX_JOURNAL" 2>/dev/null)
    ax_ok "已重新启用 $_n 个组件"
}

ax_custom() {
    case "$1" in
    scan)
        _f=0; _d=0
        for _p in $(_match_pkgs | sort); do
            if ax_pkg_disabled "$_p"; then
                printf '%s|%s|已冻结|warn\n' "$_p" "匹配精简规则"
                _d=$((_d + 1))
            else
                printf '%s|%s|启用中|dim\n' "$_p" "匹配精简规则"
                _f=$((_f + 1))
            fi
        done
        ax_result ok
        return 0
        ;;
    freeze)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_disable "$2" && ax_result ok || ax_result fail
        ;;
    unfreeze)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_enable "$2" && { ax_ok "已启用 $2"; ax_result ok; } || ax_result fail
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _total=$(_match_pkgs | grep -c . 2>/dev/null)
    _frozen=0
    for _p in $(_match_pkgs); do
        ax_pkg_disabled "$_p" && _frozen=$((_frozen + 1))
    done
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv total "${_total:-0}"
    ax_json_kv frozen "$_frozen"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
