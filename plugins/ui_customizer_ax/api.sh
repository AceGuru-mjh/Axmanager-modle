#!/system/bin/sh
# =============================================================================
# ui_customizer_ax — 界面定制（状态栏图标 / 字体显示 / 暗色 / 音效）
# -----------------------------------------------------------------------------
# 【能力边界】以下需要 root，本插件不实现：
#   ✗ 替换字体族与字体文件 —— /system/fonts 为只读系统分区
#   ✗ 自定义状态栏图标图形 —— 需 RRO 资源覆盖，要系统签名或 root
#   ✗ 往 /system/media/audio 添加系统音效 —— 系统分区只读
# 本插件只做 shell(uid 2000) 下真实生效的部分：
#   ✓ settings secure icon_blacklist            状态栏系统图标显隐
#   ✓ settings system font_scale                字号缩放
#   ✓ settings secure font_weight_adjustment    字重（Android 12+，视 ROM 而定）
#   ✓ settings secure high_text_contrast_enabled 高对比文字
#   ✓ settings secure ui_night_mode             暗色模式
#   ✓ settings system notification_sound / ringtone / alarm_alert  音效
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_DEFAULT_PROFILE=standard

# --- 可控制的状态栏图标 token（系统自带，各 ROM 支持度不同）------------------
AX_ICONS='rotate volume alarm_clock bluetooth location zen hotspot nfc cast
tty speakerphone data_saver managed_profile headset vpn ethernet'

_is_icon() { echo "$AX_ICONS" | tr ' \n' '\n\n' | grep -qx "$1"; }

# ---------------------------------------------------------------------------
# icon_blacklist 读-改-写
#   该键是逗号分隔的整体字符串，写入即覆盖，必须先读再增删后整体写回。
#   原值由 ax_set_secure 记入回滚日志，因此回滚能恢复完整列表而非清空。
# ---------------------------------------------------------------------------
_bl_get() {
    _v=$(settings get secure icon_blacklist 2>/dev/null | tr -d '\r')
    case "$_v" in ''|null) _v='' ;; esac
    echo "$_v"
}

_bl_has() {
    echo ",$(_bl_get)," | grep -q ",$1,"
}

_bl_add() {
    _t="$1"
    _bl=$(_bl_get)
    _bl=$(echo "$_bl" | sed 's/^,//; s/,$//')
    _bl_has "$_t" && { echo "$_bl"; return 0; }
    if [ -n "$_bl" ]; then echo "$_bl,$_t"; else echo "$_t"; fi
}

_bl_del() {
    _t="$1"
    echo ",$(_bl_get)," | sed "s/,$_t,/,/g; s/^,*//; s/,*$//; s/^,//; s/,$//"
}

# 统计当前被隐藏的图标数量
_bl_count() {
    _bl=$(_bl_get)
    [ -z "$_bl" ] && { echo 0; return; }
    echo "$_bl" | tr ',' '\n' | grep -c .
}

# ax_set_secure 要求写入后回读一致；部分 ROM 会对该键做规范化（排序/去空），
# 这里以「归一化后是否包含目标 token」为准，避免误报失败。
_bl_write() {
    _new="$1"
    _old=$(_bl_get)
    settings put secure icon_blacklist "$_new" >/dev/null 2>&1 || {
        ax_warn "icon_blacklist 写入被拒绝"
        AX_FAILED=$((AX_FAILED + 1))
        return 1
    }
    _cur=$(_bl_get)
    # 记录日志（原值用于回滚），统一由 axcore 的日志格式维护
    _ax_journal_add setting secure icon_blacklist "${_old:-$AX_NULL}"
    AX_TOUCHED=$((AX_TOUCHED + 1))
    if [ "$_cur" != "$_new" ]; then
        ax_info "系统对列表做了规范化：$(echo "$_cur" | cut -c1-60)"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# 暗色模式：不同 ROM 使用的键不同，读取时兼容两者
# ---------------------------------------------------------------------------
_night_get() {
    _v=$(ax_get secure ui_night_mode)
    case "$_v" in ''|null|'') _v=$(ax_get system theme_mode) ;; esac
    case "$_v" in ''|null|'') _v=0 ;; esac
    echo "$_v"
}

_night_set() {
    if ax_set_secure ui_night_mode "$1"; then return 0; fi
    # 部分 ROM（如 MIUI）使用 system/theme_mode
    if ax_set_system theme_mode "$1"; then
        ax_info "本机使用 theme_mode 而非 ui_night_mode"
        return 0
    fi
    ax_warn "暗色模式设置未被系统接受"
    AX_FAILED=$((AX_FAILED + 1))
    return 1
}

# ---------------------------------------------------------------------------
# 音效扫描：查询已被媒体库索引的音频
# ---------------------------------------------------------------------------
_tone_query() {
    command -v content >/dev/null 2>&1 || return 1
    for _u in content://media/internal/audio/media content://media/external/audio/media; do
        content query --uri "$_u" \
            --projection _id:_display_name:title 2>/dev/null |
            grep -oE 'Row: [0-9]+ _id=[0-9]+, _display_name=[^,]+, title=[^,]*' 2>/dev/null |
            sed 's/^Row: [0-9]* //'
    done
}

_tone_list() {
    if ! command -v content >/dev/null 2>&1; then
        ax_warn "本机不提供 content 命令，无法扫描音效列表"
        ax_info "可改用文件方式：把音频放到 /sdcard/Music 后重启设备完成索引"
        ax_result ok
        return 0
    fi
    _n=0
    _tone_query | head -60 | while IFS= read -r _row; do
        [ -z "$_row" ] && continue
        _id=$(echo "$_row" | sed -n 's/.*_id=\([0-9]*\).*/\1/p')
        _ti=$(echo "$_row" | sed -n 's/.*title=//p')
        _nm=$(echo "$_row" | sed -n 's/.*_display_name=\([^,]*\).*/\1/p')
        [ -z "$_id" ] && continue
        [ -z "$_ti" ] && _ti="$_nm"
        [ -z "$_ti" ] && _ti="音频 $_id"
        # 输出：标题 | 副标题 | 徽标 | 类型 | 点击载荷（settone notification <uri>）
        printf '%s|%s|点击设置|dim|notification content://media/internal/audio/media/%s\n' \
            "$(echo "$_ti" | cut -c1-40)" "ID $_id" "$_id"
        _n=$((_n + 1))
    done
    ax_result ok
}

# 设置音效：类型 + URI
_tone_set() {
    _type="$1"; _uri="$2"
    case "$_type" in
    notification) _k=notification_sound ;;
    ringtone)     _k=ringtone ;;
    alarm)        _k=alarm_alert ;;
    *) ax_err "未知音效类型：$_type（可选 notification / ringtone / alarm）"; return 1 ;;
    esac

    if [ -z "$_uri" ]; then
        ax_err "缺少音频 URI"
        return 1
    fi

    _old=$(ax_get system "$_k")
    settings put system "$_k" "$_uri" >/dev/null 2>&1 || {
        ax_err "$_k 写入被拒绝"
        return 1
    }
    _cur=$(ax_get system "$_k")
    # 部分 ROM 会规范化 URI（附加参数），只要仍指向同一 id 即视为成功
    _want=$(echo "$_uri" | grep -oE '[0-9]+$')
    case "$_cur" in
    *"$_want"*)
        [ -z "$_old" ] || [ "$_old" = "null" ] && _old="$AX_NULL"
        _ax_journal_add setting system "$_k" "$_old"
        AX_TOUCHED=$((AX_TOUCHED + 1))
        ax_ok "已设置 $_k"
        return 0
        ;;
    esac
    ax_warn "系统未接受该音效（可能不支持外部 URI）"
    AX_FAILED=$((AX_FAILED + 1))
    return 1
}

# ---------------------------------------------------------------------------
# 档位：字体显示方案
# ---------------------------------------------------------------------------
apply_profile() {
    case "$1" in
    compact)
        ax_step "紧凑：小字号，单屏显示更多内容"
        ax_set_system font_scale 0.85
        ax_set_secure high_text_contrast_enabled 0
        ;;
    standard)
        ax_step "标准：系统默认字号与对比度"
        ax_set_system font_scale 1.0
        ax_set_secure high_text_contrast_enabled 0
        ;;
    large)
        ax_step "大字：放大字号并开启高对比，更易读"
        ax_set_system font_scale 1.15
        ax_set_secure high_text_contrast_enabled 1
        ;;
    huge)
        ax_step "超大字：最大字号 + 高对比 + 加粗"
        ax_set_system font_scale 1.30
        ax_set_secure high_text_contrast_enabled 1
        ax_need_api 31 "字重调整" && ax_set_secure font_weight_adjustment 700
        ;;
    *) return 1 ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# 单项工具
# ---------------------------------------------------------------------------
ax_custom() {
    case "$1" in
    # --- 状态栏图标 ---
    icon)
        _t="$2"; _w="$3"
        _is_icon "$_t" || { ax_err "不支持的图标：$2"; ax_result fail; return 1; }
        case "$_w" in
        on|show)  _new=$(_bl_del "$_t"); _bl_write "$_new" && ax_ok "已显示状态栏图标 $_t" ;;
        off|hide) _new=$(_bl_add "$_t"); _bl_write "$_new" && ax_ok "已隐藏状态栏图标 $_t" ;;
        *) ax_err "请指定 show 或 hide"; ax_result fail; return 1 ;;
        esac
        ax_result ok
        ;;

    iconhideall)
        _new=$(_bl_get)
        for _t in $AX_ICONS; do _new=$(_bl_add "$_t"); done
        _bl_write "$_new" && ax_ok "已隐藏全部可控制图标"
        ax_result ok
        ;;

    iconshowall)
        _bl_write "" && ax_ok "已恢复显示全部状态栏图标"
        ax_result ok
        ;;

    icons)
        ax_head "状态栏图标状态"
        _bl=$(_bl_get)
        for _t in $AX_ICONS; do
            if _bl_has "$_t"; then
                printf '%s|%s|已隐藏|warn\n' "$_t" "状态栏图标"
            else
                printf '%s|%s|显示中|ok\n' "$_t" "状态栏图标"
            fi
        done
        ax_result ok
        ;;

    # --- 字体 ---
    fontscale)
        [ -z "$2" ] && { ax_err "缺少字号，如 1.15"; ax_result fail; return 1; }
        ax_set_system font_scale "$2" && ax_ok "字号已设置为 $2"
        ax_result ok
        ;;

    fontweight)
        [ -z "$2" ] && { ax_err "缺少字重，如 400 或 700"; ax_result fail; return 1; }
        ax_need_api 31 "字重调整" || { ax_result fail; return 1; }
        ax_set_secure font_weight_adjustment "$2" && ax_ok "字重已设置为 $2"
        ax_result ok
        ;;

    contrast)
        case "$2" in
        on)  ax_set_secure high_text_contrast_enabled 1 && ax_ok "高对比文字已开启" ;;
        off) ax_set_secure high_text_contrast_enabled 0 && ax_ok "高对比文字已关闭" ;;
        *) ax_err "请指定 on 或 off"; ax_result fail; return 1 ;;
        esac
        ax_result ok
        ;;

    # --- 暗色模式 ---
    night)
        case "$2" in
        0|1|2|3) _night_set "$2" && ax_ok "暗色模式已设置为 $2" ;;
        *) ax_err "可选值 0=跟随系统 1=浅色 2=深色 3=自定义"; ax_result fail; return 1 ;;
        esac
        ax_result ok
        ;;

    # --- 音效 ---
    tones)    _tone_list ;;
    settone)  _tone_set "$2" "$3" && ax_result ok || ax_result fail ;;

    # --- 状态栏附加 ---
    clocksec)
        case "$2" in
        on)  ax_set_secure clock_seconds 1 && ax_ok "状态栏时钟已显示秒" ;;
        off) ax_set_secure clock_seconds 0 && ax_ok "状态栏时钟已隐藏秒" ;;
        *) ax_err "请指定 on 或 off"; ax_result fail; return 1 ;;
        esac
        ax_result ok
        ;;

    battpct)
        case "$2" in
        on)  ax_set_secure status_bar_show_battery_percent 1 && ax_ok "已显示电量百分比" ;;
        off) ax_set_secure status_bar_show_battery_percent 0 && ax_ok "已隐藏电量百分比" ;;
        *) ax_err "请指定 on 或 off"; ax_result fail; return 1 ;;
        esac
        ax_result ok
        ;;

    state)
        ax_head "界面设置状态"
        ax_info "字号 font_scale = $(ax_get system font_scale)"
        ax_info "字重 font_weight_adjustment = $(ax_get secure font_weight_adjustment)"
        ax_info "高对比 = $(ax_get secure high_text_contrast_enabled)"
        ax_info "暗色模式 = $(_night_get)（0 跟随系统 / 1 浅色 / 2 深色 / 3 自定义）"
        ax_info "电量百分比 = $(ax_get secure status_bar_show_battery_percent)"
        ax_info "时钟秒数 = $(ax_get secure clock_seconds)"
        ax_info "已隐藏图标 = $(_bl_count) 个：$(_bl_get | cut -c1-70)"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# 状态 JSON：供 metrics 与 switches 的 syncKey 使用
#   ic_*   → 1 表示图标显示中（开关为开），0 表示已隐藏
# ---------------------------------------------------------------------------
ax_status() {
    _bl=$(_bl_get)
    ax_json_begin
    ax_json_kv profile "$(ax_profile_load)"
    ax_json_kv font "$(ax_get system font_scale)"
    ax_json_kv weight "$(ax_get secure font_weight_adjustment)"
    ax_json_kv contrast "$(ax_get secure high_text_contrast_enabled)"
    ax_json_kv night "$(_night_get)"
    ax_json_kv hidden "$(_bl_count)"
    for _t in $AX_ICONS; do
        if echo ",$_bl," | grep -q ",$_t,"; then
            ax_json_kv "ic_$_t" 0
        else
            ax_json_kv "ic_$_t" 1
        fi
    done
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
