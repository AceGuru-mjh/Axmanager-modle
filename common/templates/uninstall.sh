#!/system/bin/sh
# 由 tools/build.mjs 自动同步，请勿直接编辑（源文件：common/templates/uninstall.sh）
# AxManager 移除插件时执行：依据修改日志回滚所有改动，不留残留。
MODDIR=${0%/*}
sh "$MODDIR/scripts/api.sh" revert 2>/dev/null
rm -rf "$MODDIR/.state" 2>/dev/null
exit 0
