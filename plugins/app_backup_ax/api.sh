#!/system/bin/sh
# =============================================================================
# app_backup_ax — 应用备份与恢复
# -----------------------------------------------------------------------------
# 【边界】/data/data/<pkg> 是应用私有目录，权限 0700 且属主为应用自身，
#        shell 无法读取 —— 没有 root 就备份不了应用私有数据，这一点无法绕过。
# 【可备份范围】
#   ✓ APK 本体（pm path + cat）
#   ✓ /sdcard/Android/data|media|obb/<pkg>   公共存储中的应用数据
#   ✓ 应用版本与权限清单（文本元数据）
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

AX_BK=/sdcard/ax_backup
_apps() { pm list packages -3 2>/dev/null | sed 's/^package://'; }

_backup_one() {
    _p="$1"
    ax_pkg_exists "$_p" || { ax_err "未安装：$_p"; return 1; }
    _apk=$(pm path "$_p" 2>/dev/null | head -1 | sed 's/^package://')
    _d="$AX_BK/$_p"
    mkdir -p "$_d" 2>/dev/null || { ax_err "无法创建 $_d（存储权限未授予？）"; return 1; }

    if [ -n "$_apk" ] && cat "$_apk" >"$_d/base.apk" 2>/dev/null && [ -s "$_d/base.apk" ]; then
        ax_ok "APK 已备份"
    else
        ax_warn "APK 备份失败"
    fi

    _n=0
    for _pair in "data:/sdcard/Android/data" "media:/sdcard/Android/media" "obb:/sdcard/Android/obb"; do
        _tag=$(echo "$_pair" | cut -d: -f1)
        _base=$(echo "$_pair" | cut -d: -f2)
        if [ -d "$_base/$_p" ]; then
            if tar -cf "$_d/$_tag.tar" -C "$_base" "$_p" 2>/dev/null && [ -s "$_d/$_tag.tar" ]; then
                _n=$((_n + 1))
            fi
        fi
    done
    [ "$_n" -gt 0 ] && ax_ok "公共数据已备份 $_n 个分区" || ax_info "该应用在公共存储中没有数据"

    dumpsys package "$_p" 2>/dev/null | grep -E 'versionName=|firstInstallTime=' | head -2 >"$_d/meta.txt"
    ax_ok "备份完成：$_d"
    return 0
}

apply_profile() {
    case "$1" in
    backupall)
        ax_step "备份全部第三方应用"
        _n=0
        for _p in $(_apps); do
            _backup_one "$_p" >/dev/null 2>&1 && _n=$((_n + 1))
        done
        ax_ok "已完成 $_n 个应用的备份"
        ax_info "备份目录：$AX_BK"
        ;;
    none)
        ax_info "可使用下方工具按需备份"
        ;;
    *) return 1 ;;
    esac
    return 0
}

ax_custom() {
    case "$1" in
    backup) _backup_one "$2" && ax_result ok || ax_result fail ;;

    restore)
        [ -z "$2" ] && { ax_err "缺少包名"; ax_result fail; return 1; }
        _d="$AX_BK/$2"
        [ -f "$_d/base.apk" ] || { ax_err "未找到备份：$2"; ax_result fail; return 1; }
        if pm install -r "$_d/base.apk" 2>&1 | grep -qi 'success'; then
            ax_ok "应用已重新安装"
        else
            ax_warn "安装被拒绝（部分 ROM 不允许 shell 安装应用），可手动点击 APK 安装"
        fi
        for _tag in data media obb; do
            [ -f "$_d/$_tag.tar" ] || continue
            _base=/sdcard/Android/$_tag
            mkdir -p "$_base" 2>/dev/null
            tar -xf "$_d/$_tag.tar" -C "$_base" 2>/dev/null && ax_ok "$_tag 数据已恢复"
        done
        ax_result ok
        ;;

    list)
        if [ -d "$AX_BK" ]; then
            for _d in "$AX_BK"/*; do
                [ -d "$_d" ] || continue
                _n=$(basename "$_d")
                _s=$(du -sk "$_d" 2>/dev/null | cut -f1)
                [ -f "$_d/base.apk" ] && _st="含 APK" || _st="无 APK"
                printf '%s|%s KB · %s|已备份|ok\n' "$_n" "${_s:-0}" "$_st"
            done
        fi
        ax_result ok
        ;;

    wipe)
        rm -rf "$AX_BK" 2>/dev/null && ax_ok "备份目录已清空" || ax_warn "清空失败"
        ax_result ok
        ;;

    *) return 1 ;;
    esac
}

ax_status() {
    _n=0; _s=0
    if [ -d "$AX_BK" ]; then
        _n=$(ls -1 "$AX_BK" 2>/dev/null | grep -c .)
        _s=$(du -sk "$AX_BK" 2>/dev/null | cut -f1)
    fi
    ax_json_begin
    ax_json_kv backups "$(ax_num "$_n")"
    ax_json_kv size "$(( (ax_num "$_s") / 1024 ))"
    ax_json_kv apps "$(_apps | grep -c .)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"
