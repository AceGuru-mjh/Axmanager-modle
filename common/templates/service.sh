#!/system/bin/sh
# 由 tools/build.mjs 自动同步，请勿直接编辑（源文件：common/templates/service.sh）
# -----------------------------------------------------------------------------
# AxManager 在 BOOT_COMPLETED 的 late_start 阶段执行本脚本。
# 非 root 环境下 settings / prop 改动大多在重启后被系统重置，因此这里读取
# .state/profile 自动重新应用上次生效的档位 —— 旧版本插件没有这一步，
# 导致用户每次重启都要手动重新点一遍。
# -----------------------------------------------------------------------------
MODDIR=${0%/*}

[ -f "$MODDIR/disable" ] && exit 0
[ -s "$MODDIR/.state/profile" ] || exit 0

# 等待 SystemServer 与各 provider 就绪，否则 settings put 可能静默失败
(
    i=0
    while [ "$i" -lt 30 ]; do
        [ "$(getprop sys.boot_completed)" = "1" ] && break
        sleep 2
        i=$((i + 1))
    done
    sleep 12
    sh "$MODDIR/scripts/api.sh" reapply >"$MODDIR/.state/boot.log" 2>&1
) &

exit 0
