#!/system/bin/sh
# 由 tools/build.mjs 自动同步，请勿直接编辑（源文件：common/templates/action.sh）
# AxManager 插件列表点击「操作」按钮时执行：应用上次选择的档位，
# 若从未配置过则应用插件的推荐默认档位。
MODDIR=${0%/*}
exec sh "$MODDIR/scripts/api.sh" action
