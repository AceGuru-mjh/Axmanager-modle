#!/system/bin/sh
# 由 tools/build.mjs 自动同步，请勿直接编辑（源文件：common/templates/customize.sh）
# -----------------------------------------------------------------------------
# 安装期校验：AxManager 会在解压并套用默认权限后 source 本脚本。
# 这里只做环境检查与权限修正，不做任何系统设置改动 ——
# 系统改动一律由用户在 WebUI 中显式触发，避免「装上就偷偷改设置」。
# -----------------------------------------------------------------------------

ui_print " "
ui_print "  ┌────────────────────────────────────────┐"
ui_print "  │  $(sed -n 's/^name=//p' "$MODPATH/module.prop" | head -1)"
ui_print "  │  版本 $(sed -n 's/^version=//p' "$MODPATH/module.prop" | head -1)  ·  作者 MJH"
ui_print "  └────────────────────────────────────────┘"
ui_print " "

# --- 环境校验 --------------------------------------------------------------
if [ "$AXERON" != "true" ]; then
    ui_print "⚠ 未检测到 AxManager 环境标记"
    ui_print "  本插件专为 AxManager 非 root 环境设计，"
    ui_print "  在 Magisk / KernelSU 中安装不会报错但功能受限。"
fi

if [ -n "$API" ] && [ "$API" -lt 26 ]; then
    abort "✖ 需要 Android 8.0 (API 26) 及以上，当前 API $API"
fi

if [ -n "$API" ] && [ "$API" -lt 29 ]; then
    ui_print "⚠ 当前 Android API $API 低于 29"
    ui_print "  device_config 运行时开关不可用，部分档位效果会被跳过。"
fi

ui_print "· 架构 $ARCH · API $API"

# --- 权限 ------------------------------------------------------------------
# webroot 由 AxManager 自行设置权限与 SELinux 上下文，切勿在此覆盖。
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
[ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
[ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755

mkdir -p "$MODPATH/.state" 2>/dev/null

ui_print " "
ui_print "✔ 安装完成"
ui_print " "
ui_print "  下一步：在 AxManager 插件列表中打开本插件的"
ui_print "  「WebUI」面板，选择档位后点击应用。"
ui_print " "
ui_print "  所有改动均写入修改日志，可在面板内一键回滚。"
ui_print " "
