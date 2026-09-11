#!/system/bin/sh
# =============================================================================
# dispatch.sh — 插件统一命令分发器
# -----------------------------------------------------------------------------
# 由各插件的 scripts/api.sh 在定义完 apply_profile()（以及可选的 ax_custom()、
# ax_status()）之后 source 引入，负责把 WebUI / action 按钮 / 开机服务传入的
# 动词路由到具体实现，并统一处理回滚、档位记忆与错误码。
#
# 支持的动词：
#   apply <profile>  应用指定档位
#   revert           依据日志回滚全部改动
#   current          输出当前生效档位（供 WebUI 高亮）
#   action           AxManager 操作按钮：应用上次档位或默认档位
#   reapply          开机自恢复：静默重新应用上次档位
#   status           输出 JSON 状态（由插件的 ax_status 提供）
#   其它             交给插件的 ax_custom 处理
# =============================================================================

AX_VERB="${1:-action}"
shift 2>/dev/null

# 未实现时的占位
ax_has_func() { type "$1" 2>/dev/null | grep -q function; }

_ax_apply() {
    _p="$1"
    if [ -z "$_p" ]; then
        ax_err "未指定档位"
        ax_result fail
        exit 1
    fi
    ax_check_privilege
    # 先回滚旧档位，确保不同档位之间不会互相污染残留
    if [ -s "$AX_JOURNAL" ]; then
        ax_step "清理上一档位的改动"
        ax_revert_all
        AX_TOUCHED=0
        AX_FAILED=0
        AX_SKIPPED=0
    fi
    apply_profile "$_p" || {
        ax_err "档位 $_p 不存在"
        ax_result fail
        exit 1
    }
    ax_finish "$_p"
}

case "$AX_VERB" in
apply)
    ax_head "应用档位：$1"
    _ax_apply "$1"
    ;;

revert)
    ax_head "回滚全部改动"
    ax_revert_all
    ax_result ok
    ;;

current)
    ax_profile_load
    ;;

action)
    _p=$(ax_profile_load)
    [ -z "$_p" ] && _p="${AX_DEFAULT_PROFILE:-balanced}"
    ax_head "应用档位：$_p"
    _ax_apply "$_p"
    ;;

reapply)
    _p=$(ax_profile_load)
    [ -z "$_p" ] && exit 0
    # 开机自恢复：此时日志中记录的是重启前的值，直接重放档位即可，
    # 不做 revert（重启后系统已自行重置，revert 会写回过期的旧值）
    rm -f "$AX_JOURNAL" 2>/dev/null
    apply_profile "$_p" >/dev/null 2>&1
    ax_profile_save "$_p"
    ;;

status)
    if ax_has_func ax_status; then
        ax_status "$@"
    else
        ax_json_begin
        ax_json_kv profile "$(ax_profile_load)"
        ax_json_end
    fi
    ;;

*)
    # 优先交给插件自定义处理；未匹配时再按档位名尝试，
    # 这样 WebUI 的动作按钮可以直接复用 apply_profile 中已有的档位逻辑。
    if ax_has_func ax_custom && ax_custom "$AX_VERB" "$@"; then
        exit 0
    fi
    if ax_has_func apply_profile && apply_profile "$AX_VERB"; then
        ax_finish "$AX_VERB"
        exit 0
    fi
    if ax_has_func ax_custom; then
        ax_err "未知指令：$AX_VERB"
    else
        ax_err "插件未实现 ax_custom()，无法处理指令：$AX_VERB"
    fi
    ax_result fail
    exit 1
    ;;
esac
