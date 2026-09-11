#!/system/bin/sh
# =============================================================================
# ad_block_ax — 广告与追踪拦截
# -----------------------------------------------------------------------------
# 【边界】修改 /system/etc/hosts 需要 root，免 root 无法使用 hosts 拦截。
# 【实际手段 —— 两条真实有效的路径】
#   ✓ 私有 DNS（DoT）指向过滤型解析器：系统级域名拦截，覆盖全部应用
#   ✓ 停用厂商与广告 SDK 组件：pm disable-user（可逆）
# 两者结合可覆盖绝大多数广告与追踪，且完全可逆。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=light

# 常用过滤型 DoT 解析器
AX_DNS_ADGUARD='dns.adguard.com'
AX_AD_KEYS='msa|analytics|adservice|adsdk|adx|admob|gms.*ads|facebook.*ads|unionservice|heytap.*ad|adhub|adnxs|mopub|ironsource|vungle|applovin|bytedance.*ad|tencent.*ad'

_ads() { pm list packages 2>/dev/null | sed 's/^package://' | grep -Ei "$AX_AD_KEYS" 2>/dev/null; }

_dns() {
    if [ -z "$1" ]; then
        ax_set_global private_dns_mode off && ax_ok "私有 DNS 已关闭"
        return 0
    fi
    ax_set_global private_dns_mode hostname && \
    ax_set_global private_dns_specifier "$1" && ax_ok "私有 DNS 已指向 $1"
}

apply_profile() {
    case "$1" in
    strong)
        ax_step "强效拦截：过滤型 DNS + 停用广告组件"
        _dns "$AX_DNS_ADGUARD"
        _n=0
        for _p in $(_ads); do ax_pkg_disable "$_p" >/dev/null 2>&1 && _n=$((_n + 1)); done
        ax_ok "已停用 $_n 个广告与追踪组件"
        ax_set_secure ad_id_enabled 0 2>/dev/null
        ;;

    light)
        ax_step "轻度拦截：仅启用过滤型 DNS"
        _dns "$AX_DNS_ADGUARD"
        ax_info "保留广告 SDK 组件，避免部分应用因缺少 SDK 而闪退"
        ;;

    default)
        ax_step "恢复原厂：关闭私有 DNS 并重新启用广告组件"
        _dns ""
        if [ -s "$AX_JOURNAL" ]; then
            grep '^pkg	' "$AX_JOURNAL" 2>/dev/null | while IFS='	' read -r _t _p _x _y; do
                ax_pkg_enable "$_p" >/dev/null 2>&1
            done
            _n=$(grep -c '^pkg	' "$AX_JOURNAL" 2>/dev/null)
            ax_ok "已重新启用 $_n 个组件"
        fi
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    scan)
        for _p in $(_ads | sort); do
            if ax_pkg_disabled "$_p"; then
                printf '%s|%s|已停用|ok\n' "$_p" "广告 / 追踪组件"
            else
                printf '%s|%s|启用中|warn\n' "$_p" "广告 / 追踪组件"
            fi
        done
        ax_result ok
        ;;
    setdns)
        [ -z "$2" ] && { ax_err "缺少 DNS 主机名"; ax_result fail; return 1; }
        _dns "$2"
        ax_result ok
        ;;
    dnsstate)
        ax_head "DNS 拦截状态"
        ax_info "private_dns_mode = $(ax_get global private_dns_mode)"
        ax_info "private_dns_specifier = $(ax_get global private_dns_specifier)"
        ax_info "提示：过滤型 DNS 会同时拦截广告与追踪域名，"
        ax_info "      但依赖第三方解析器的可用性，可用下方按钮更换。"
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(_ads | grep -c . 2>/dev/null)
    _d=0
    for _p in $(_ads); do ax_pkg_disabled "$_p" && _d=$((_d + 1)); done
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv dnsmode "$(ax_get global private_dns_mode)"
    ax_json_kv dnshost "$(ax_get global private_dns_specifier)"
    ax_json_kv total "${_t:-0}"
    ax_json_kv blocked "$_d"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
