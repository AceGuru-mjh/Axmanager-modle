#!/system/bin/sh
# =============================================================================
# system_ui_tweak_ax — 系统界面微调
# -----------------------------------------------------------------------------
#   ✓ settings global policy_control immersive.full=*    全屏沉浸模式
#   ✓ wm density <n> / reset                             显示密度（内容疏密）
#   ✓ wm size WxH / reset                                分辨率
#   ✓ settings secure sysui_nav_bar                      导航栏按键布局
#   ✓ settings secure status_bar_show_battery_percent    电量百分比
#   ✓ settings secure sysui_qqs_count                    快捷开关列数
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=default

_density() { wm density 2>/dev/null | grep -oE '[0-9]+' | head -1; }

apply_profile() {
    case "$1" in
    immersive)
        ax_step "沉浸全屏：隐藏状态栏与导航栏"
        ax_set_global policy_control "immersive.full=*"
        ax_info "从屏幕边缘上滑可临时唤出系统栏"
        ;;

    compact)
        ax_step "紧凑布局：提高显示密度以显示更多内容"
        _c=$(_density)
        if [ -n "$_c" ] && [ "$_c" -gt 200 ]; then
            _n=$((_c + 40))
            wm density "$_n" >/dev/null 2>&1 && { _ax_journal_add meta density "$AX_NULL" "$_c"; ax_ok "密度 $_c → $_n"; }
        else
            ax_warn "无法读取当前密度（$_c），已跳过"
            AX_SKIPPED=$((AX_SKIPPED + 1))
        fi
        ax_set_secure sysui_qqs_count 8
        ax_set_secure status_bar_show_battery_percent 1
        ;;

    default)
        ax_step "原生均衡：恢复系统默认界面"
        settings delete global policy_control >/dev/null 2>&1 && ax_ok "沉浸模式已关闭"
        wm density reset >/dev/null 2>&1
        wm size reset >/dev/null 2>&1
        ax_set_secure status_bar_show_battery_percent 0
        ax_ok "界面参数已恢复默认"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    density)
        [ -z "$2" ] && { ax_err "缺少密度值"; ax_result fail; return 1; }
        if [ "$2" = "reset" ]; then
            wm density reset >/dev/null 2>&1 && ax_ok "密度已恢复默认"
        else
            wm density "$2" >/dev/null 2>&1 && ax_ok "密度已设置为 $2" || ax_warn "设置失败"
        fi
        ax_result ok
        ;;

    navbar)
        [ -z "$2" ] && { ax_err "缺少布局参数或 reset"; ax_result fail; return 1; }
        if [ "$2" = "reset" ]; then
            settings delete secure sysui_nav_bar >/dev/null 2>&1 && ax_ok "导航栏已恢复默认"
        else
            ax_set_secure sysui_nav_bar "$2" && ax_ok "导航栏布局已更新"
        fi
        ax_result ok
        ;;

    batterypercent)
        ax_set_secure status_bar_show_battery_percent "$2" && ax_ok "电量百分比已设置为 $2"
        ax_result ok
        ;;

    info)
        ax_head "界面参数"
        ax_info "密度 = $(wm density 2>/dev/null | tail -1)"
        ax_info "分辨率 = $(wm size 2>/dev/null | tail -1)"
        ax_info "沉浸模式 = $(ax_get global policy_control)"
        ax_info "电量百分比 = $(ax_get secure status_bar_show_battery_percent)"
        ax_info "导航栏布局 = $(ax_get secure sysui_nav_bar)"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv density "$(_density)"
    ax_json_kv immersive "$(ax_get global policy_control)"
    ax_json_kv battpct "$(ax_get secure status_bar_show_battery_percent)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
