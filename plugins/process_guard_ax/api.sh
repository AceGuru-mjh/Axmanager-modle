#!/system/bin/sh
# =============================================================================
# process_guard_ax — 进程查看与清理
# -----------------------------------------------------------------------------
# 【边界】真正的进程守护（锁定 OOM 优先级、阻止 LMK 回收）需要 root 写入
#        /proc/<pid>/oom_score_adj，免 root 无法做到。
# 【实际能力】
#   ✓ ps / top 查看进程与内存占用
#   ✓ am kill <pkg> / kill <pid>     结束后台进程（系统关键进程受保护）
#   ✓ am set-standby-bucket active   降低被系统回收的概率（等效保活）
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=diagnose

_top() {
    ps -A -o PID,RSS,ARGS 2>/dev/null | tail -n +2 |
        sort -k2 -rn 2>/dev/null | head -"${1:-20}"
}

_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

apply_profile() {
    case "$1" in
    aggressive)
        ax_step "激进清理：结束全部可结束的后台进程"
        pm trim-caches 999999999999 2>/dev/null
        am kill-all 2>/dev/null && ax_ok "后台进程已结束"
        ax_devcfg activity_manager max_cached_processes 12
        ;;

    gentle)
        ax_step "温和清理：仅结束后台进程，保留前台应用"
        am kill-all 2>/dev/null && ax_ok "后台进程已结束"
        ;;

    diagnose)
        ax_step "仅诊断：不结束任何进程"
        ax_info "进程列表见下方「进程占用排行」"
        ;;

    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    list)
        _top 20 | while IFS= read -r _line; do
            _pid=$(echo "$_line" | awk '{print $1}')
            _rss=$(echo "$_line" | awk '{print $2}')
            _cmd=$(echo "$_line" | awk '{print $3}')
            [ -z "$_pid" ] && continue
            _mb=$(( (ax_num "$_rss") / 1024 ))
            if [ "$_mb" -ge 300 ]; then
                _pill="warn"
            elif [ "$_mb" -ge 120 ]; then
                _pill="dim"
            else
                _pill="dim"
            fi
            printf '%s|PID %s · 内存 %s MB|%s\n' "$(basename "$_cmd")" "$_pid" "$_mb" "$_pill"
        done
        ax_result ok
        ;;

    killpid)
        [ -z "$2" ] && { ax_err "缺少 PID"; ax_result fail; return 1; }
        case "$2" in
        ''|*[!0-9]*) ax_err "PID 必须是数字"; ax_result fail; return 1 ;;
        esac
        if [ "$(ax_num "$2")" -le 1 ]; then
            ax_err "拒绝结束系统关键进程"
            ax_result fail
            return 1
        fi
        if kill -9 "$2" 2>/dev/null; then
            ax_ok "已向进程 $2 发送终止信号"
            ax_result ok
        else
            ax_warn "无法结束进程 $2（属主不同或受保护），可改用包名方式"
            ax_result fail
        fi
        ;;

    killpkg)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_protected "$2" && { ax_err "系统关键组件，拒绝结束"; ax_result fail; return 1; }
        am kill --user 0 "$2" >/dev/null 2>&1 || am force-stop --user 0 "$2" >/dev/null 2>&1
        ax_ok "已结束 $2 的后台进程"
        ax_result ok
        ;;

    keepalive)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        ax_pkg_exists "$2" || { ax_err "未安装：$2"; ax_result fail; return 1; }
        am set-standby-bucket "$2" active >/dev/null 2>&1 && ax_ok "已置为活跃分组"
        appops set "$2" RUN_IN_BACKGROUND allow >/dev/null 2>&1
        appops set "$2" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
        ax_info "这只能降低回收概率，无法像 root 那样锁定 OOM 优先级"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv procs "$(ps -A 2>/dev/null | grep -c .)"
    ax_json_kv mem "$(_mem_pct)"
    ax_json_end
}

_mem_pct() {
    _t=$(ax_num "$(ax_mem_field MemTotal)")
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    [ "$_t" -le 0 ] && { echo 0; return; }
    echo $(( (_t - _a) * 100 / _t ))
}

. "$MODDIR/scripts/dispatch.sh"
