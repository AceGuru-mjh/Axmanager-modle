#!/system/bin/sh
# =============================================================================
# auto_input_ax — 输入与手势自动化
# -----------------------------------------------------------------------------
# 系统内置 input 命令，shell 身份可直接调用：
#   input text <string>          输入文本（空格需转义）
#   input keyevent <code>        按键事件
#   input tap <x> <y>            点击坐标
#   input swipe x1 y1 x2 y2 [ms] 滑动
# 常用键值：3 主页 / 4 返回 / 187 最近任务 / 26 电源 / 24 音量+ / 25 音量-
#           164 静音 / 120 截图 / 220 亮度+ / 221 亮度- / 82 菜单
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_key() { input keyevent "$1" >/dev/null 2>&1 && return 0 || { ax_warn "按键 $1 执行失败"; return 1; }; }

ax_custom() {
    case "$1" in
    text)
        [ -z "$2" ] && { ax_err "缺少要输入的文本"; ax_result fail; return 1; }
        shift
        if input text "$*" >/dev/null 2>&1; then
            ax_ok "已输入文本"
        else
            ax_warn "输入失败：当前焦点可能不在可输入区域"
        fi
        ax_result ok
        ;;

    key)
        [ -z "$2" ] && { ax_err "缺少键值"; ax_result fail; return 1; }
        _key "$2" && ax_ok "已发送按键 $2"
        ax_result ok
        ;;

    tap)
        [ -z "$3" ] && { ax_err "格式：x y"; ax_result fail; return 1; }
        input tap "$2" "$3" >/dev/null 2>&1 && ax_ok "已点击 ($2, $3)" || ax_warn "点击失败"
        ax_result ok
        ;;

    swipe)
        [ -z "$5" ] && { ax_err "格式：x1 y1 x2 y2 [时长ms]"; ax_result fail; return 1; }
        input swipe "$2" "$3" "$4" "$5" "${6:-300}" >/dev/null 2>&1 && ax_ok "已执行滑动" || ax_warn "滑动失败"
        ax_result ok
        ;;

    home)   _key 3   && ax_ok "主页"; ax_result ok ;;
    back)   _key 4   && ax_ok "返回"; ax_result ok ;;
    recent) _key 187 && ax_ok "最近任务"; ax_result ok ;;
    power)  _key 26  && ax_ok "电源键"; ax_result ok ;;
    volup)  _key 24  && ax_ok "音量+"; ax_result ok ;;
    voldn)  _key 25  && ax_ok "音量-"; ax_result ok ;;
    mute)   _key 164 && ax_ok "静音"; ax_result ok ;;
    menu)   _key 82  && ax_ok "菜单"; ax_result ok ;;
    shotkey)
        ax_need_api 28 "系统截图键" || { ax_result fail; return 1; }
        _key 120 && ax_ok "已触发系统截图"
        ax_result ok
        ;;

    res)
        ax_head "屏幕分辨率（用于坐标定位）"
        wm size 2>/dev/null | tail -1
        ax_info "坐标原点在左上角，例如中点约为 $(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1 | awk -Fx '{printf "(%d, %d)", $1/2, $2/2}')"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    ax_json_begin
    ax_json_kv size "$(wm size 2>/dev/null | tail -1 | sed 's/.*: //')"
    ax_json_kv density "$(wm density 2>/dev/null | grep -oE '[0-9]+' | head -1)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
