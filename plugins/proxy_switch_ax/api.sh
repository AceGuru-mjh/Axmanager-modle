#!/system/bin/sh
# =============================================================================
# proxy_switch_ax — 全局 HTTP 代理
# -----------------------------------------------------------------------------
# 系统级代理由 Settings.Global 维护，shell 可写，全应用生效（不含 VPN 绕过）：
#   ✓ settings global http_proxy <host>:<port>      设置代理
#   ✓ settings global http_proxy :0                 清除代理
#   ✓ settings global global_http_proxy_exclusion_list "a;b;c"  排除列表
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=direct

_set_proxy() {
    if [ "$1" = ":0" ] || [ -z "$1" ]; then
        ax_set_global http_proxy ":0" && ax_ok "已恢复直连"
        return 0
    fi
    ax_set_global http_proxy "$1" && ax_ok "代理已设置为 $1"
}

_set_exclude() {
    if [ -z "$1" ]; then
        settings delete global global_http_proxy_exclusion_list >/dev/null 2>&1
        return 0
    fi
    ax_set_global global_http_proxy_exclusion_list "$1" && ax_ok "排除列表已更新"
}

apply_profile() {
    case "$1" in
    capture)
        ax_step "抓包代理：本机 8888 端口"
        _set_proxy "127.0.0.1:8888"
        _set_exclude "localhost;127.0.0.1;*.local"
        ax_warn "需在本机运行 Charles / Fiddler / mitmproxy 等抓包工具"
        ;;

    work)
        ax_step "公司网络：本机 8080 端口"
        _set_proxy "127.0.0.1:8080"
        _set_exclude "localhost;127.0.0.1;*.local;*.internal"
        ;;

    direct)
        ax_step "直连模式：清除系统代理"
        _set_proxy ":0"
        _set_exclude ""
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    set)
        [ -z "$2" ] && { ax_err "格式：host:port"; ax_result fail; return 1; }
        _set_proxy "$2"
        ax_result ok
        ;;
    test)
        ax_head "代理与网络状态"
        ax_info "http_proxy = $(ax_get global http_proxy)"
        ax_info "exclusion = $(ax_get global global_http_proxy_exclusion_list)"
        dumpsys connectivity 2>/dev/null | grep -E 'Proxy|NetworkAgentInfo' | head -6
        ax_info "代理是否生效取决于目标服务器可达性，可配合抓包工具确认"
        ax_result ok
        ;;
    clear)
        _set_proxy ":0"
        _set_exclude ""
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv proxy "$(ax_get global http_proxy)"
    ax_json_kv exclude "$(ax_get global global_http_proxy_exclusion_list)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
