#!/system/bin/sh
# =============================================================================
# ota_guard_ax — OTA 升级阻断守护
# -----------------------------------------------------------------------------
# 通过停用系统更新相关组件来阻断静默升级：
#   ✓ 扫描已安装的 OTA / FOTA / 更新服务包名
#   ✓ pm disable-user 停用（可逆，不删除数据）
#   ✓ 组件级停用 GMS 系统更新服务（保留 GMS 其余功能）
# 保护名单由 axcore.sh 提供，系统关键组件不会被停用。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=light

AX_OTA_KEYS='ota|fota|systemupdate|system_update|updateservice|update.service|dmclient|omadm|wssyncml|sprd.*updater|oplus.*ota|miui.*updater|heytap.*update|vivo.*updater|huawei.*ota|softwareupdate|soter.*update'

# 已知的系统更新组件（组件级停用，不影响应用本体）
AX_OTA_COMPS='com.google.android.gms/com.google.android.gms.update.SystemUpdateService
com.google.android.gms/com.google.android.gms.update.SystemUpdateActivity
com.google.android.gms/com.google.android.gms.update.SystemUpdateService$ActiveReceiver
com.google.android.gms/com.google.android.gms.update.SystemUpdateService$Receiver
com.google.android.gms/com.google.android.gms.update.SystemUpdateService$SecretCodeReceiver'

_match_ota() {
    pm list packages 2>/dev/null | sed 's/^package://' | grep -Ei "$AX_OTA_KEYS" 2>/dev/null
}

_disable_all() {
    _n=0
    for _p in $(_match_ota); do
        ax_pkg_disable "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
    done
    [ "$_n" -gt 0 ] && ax_ok "已停用 $_n 个更新组件" || ax_info "未发现可停用的更新组件"
}

apply_profile() {
    case "$1" in
    blockall)
        ax_step "全面阻断：停用全部匹配到的更新组件与 GMS 更新服务"
        _disable_all
        _n=0
        for _c in $AX_OTA_COMPS; do
            ax_comp_disable "$_c" >/dev/null 2>&1 && _n=$((_n + 1))
        done
        [ "$_n" -gt 0 ] && ax_ok "已停用 $_n 个 GMS 更新组件"
        ;;

    light)
        ax_step "轻度拦截：仅停用自动下载与静默安装相关组件"
        _n=0
        for _p in $(_match_ota | grep -Ei 'ota|fota|update' | grep -Evi 'manual|settings'); do
            ax_pkg_disable "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
        done
        [ "$_n" -gt 0 ] && ax_ok "已停用 $_n 个自动更新组件" || ax_info "未发现可停用的组件"
        ax_info "系统设置中的「检查更新」入口仍可手动使用"
        ;;

    allowall)
        ax_step "临时放行：重新启用此前停用的全部更新组件"
        if [ -s "$AX_JOURNAL" ]; then
            _n=0
            grep '^pkg	' "$AX_JOURNAL" 2>/dev/null | while IFS='	' read -r _t _p _x _y; do
                ax_pkg_enable "$_p" >/dev/null 2>&1
            done
            _n=$(grep -c '^pkg	' "$AX_JOURNAL" 2>/dev/null)
            for _c in $AX_OTA_COMPS; do ax_comp_enable "$_c" >/dev/null 2>&1; done
            ax_ok "已重新启用 $_n 个更新组件"
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
        for _p in $(_match_ota | sort); do
            if ax_pkg_disabled "$_p"; then
                printf '%s|%s|已阻断|ok\n' "$_p" "系统更新组件"
            else
                printf '%s|%s|允许更新|warn\n' "$_p" "系统更新组件"
            fi
        done
        ax_result ok
        ;;
    comps)
        for _c in $AX_OTA_COMPS; do
            _p=$(echo "$_c" | cut -d/ -f1)
            ax_pkg_exists "$_p" || continue
            printf '%s|%s|候选项|dim\n' "$_c" "GMS 更新组件"
        done
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(_match_ota | grep -c . 2>/dev/null)
    _d=0
    for _p in $(_match_ota); do ax_pkg_disabled "$_p" && _d=$((_d + 1)); done
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv total "${_t:-0}"
    ax_json_kv blocked "$_d"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
