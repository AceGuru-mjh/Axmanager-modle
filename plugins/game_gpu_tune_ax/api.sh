#!/system/bin/sh
# =============================================================================
# game_gpu_tune_ax — 游戏专项优化
# -----------------------------------------------------------------------------
# 【边界】无法强制修改游戏内的画质与帧率设置，也无法超频 GPU。
# 【实际手段】
#   ✓ cmd package compile -m speed -f <pkg>   对该游戏做 AOT 编译（真实提速）
#   ✓ am set-standby-bucket <pkg> active      避免被系统限制
#   ✓ appops WAKE_LOCK allow                  避免运行中掉锁
#   ✓ 全局刷新率与温控策略配合
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=balanced

AX_GAME_KEYS='game|miHoYo|mihoyo|hoyoverse|supercell|riot|pubg|tencent.*pubgm|freefire|moonton|netease.*game|activision|blizzard|nintendo|bandai|kurogame|hypergryph|pearlabyss|levelinfinite|proximabeta'

_games() {
    pm list packages -3 2>/dev/null | sed 's/^package://' | grep -Ei "$AX_GAME_KEYS" 2>/dev/null
}

apply_profile() {
    case "$1" in
    performance)
        ax_step "性能优先：全局高刷 + 解除节流"
        ax_set_system peak_refresh_rate 0
        ax_set_system min_refresh_rate 0
        ax_set_global adaptive_battery_management_enabled 0
        ax_set_global cached_apps_freezer disabled
        cmd thermalservice override-status 0 >/dev/null 2>&1 &&
            { _ax_journal_add thermal 0 '-' reset; ax_ok "温控节流已解除"; }
        ;;

    balanced)
        ax_step "均衡：系统自适应刷新率"
        ax_set_system peak_refresh_rate 0
        ax_set_system min_refresh_rate 0
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global cached_apps_freezer enabled
        cmd thermalservice reset >/dev/null 2>&1 && ax_ok "温控已恢复系统托管"
        ;;

    battery)
        ax_step "省电：锁定 60Hz 并加强节流"
        ax_set_system peak_refresh_rate 60
        ax_set_system min_refresh_rate 60
        ax_set_global adaptive_battery_management_enabled 1
        ax_set_global cached_apps_freezer enabled
        cmd thermalservice override-status 3 >/dev/null 2>&1 &&
            { _ax_journal_add thermal 3 '-' reset; ax_ok "温控节流加强"; }
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    scan)
        for _p in $(_games | sort); do
            _v=$(dumpsys package "$_p" 2>/dev/null | grep -m1 'versionName=' | sed 's/.*versionName=//; s/ .*//')
            printf '%s|版本 %s|已识别|ok\n' "$_p" "${_v:-未知}"
        done
        ax_result ok
        ;;

    compile)
        if [ -n "$2" ]; then
            ax_pkg_exists "$2" || { ax_err "未安装：$2"; ax_result fail; return 1; }
            cmd package compile -m speed -f "$2" >/dev/null 2>&1 && ax_ok "已对 $2 执行 speed 编译" || ax_warn "编译失败"
        else
            _n=0
            for _p in $(_games); do
                cmd package compile -m speed -f "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
            done
            ax_ok "已对 $_n 个游戏执行 speed 编译"
        fi
        ax_result ok
        ;;

    optimize)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_exists "$2" || { ax_err "未安装：$2"; ax_result fail; return 1; }
        ax_head "优化 $2"
        am set-standby-bucket "$2" active >/dev/null 2>&1 && ax_ok "已置为活跃分组"
        appops set "$2" WAKE_LOCK allow >/dev/null 2>&1
        appops set "$2" RUN_IN_BACKGROUND allow >/dev/null 2>&1
        ax_step "执行 speed 编译（可能耗时数十秒）"
        cmd package compile -m speed -f "$2" >/dev/null 2>&1 && ax_ok "编译完成" || ax_warn "编译失败"
        ax_result ok
        ;;

    clearcache)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_protected "$2" && { ax_err "系统组件拒绝操作"; ax_result fail; return 1; }
        pm trim-caches 999999999999 2>/dev/null
        ax_ok "已触发系统缓存回收"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv games "$(_games | grep -c .)"
    ax_json_kv peak "$(ax_get system peak_refresh_rate)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
