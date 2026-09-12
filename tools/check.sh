#!/usr/bin/env bash
# =============================================================================
# check.sh — 构建产物静态校验
#   1. POSIX shell 语法检查（所有 dist 下的 .sh）
#   2. 换行符检查（AxManager 要求 module.prop 为 UNIX LF）
#   3. 必要文件检查（module.prop / webroot/index.html / scripts/api.sh）
#   4. module.prop 的 id 必须与目录名一致
# 用法：bash tools/check.sh
# =============================================================================
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
checked=0

for d in dist/*/; do
    id=$(basename "$d")
    checked=$((checked + 1))

    # 1. 语法检查
    for f in "$d"scripts/*.sh "$d"action.sh "$d"service.sh "$d"uninstall.sh "$d"customize.sh; do
        [ -f "$f" ] || continue
        if ! out=$(sh -n "$f" 2>&1); then
            echo "✖ [$id] 语法错误 $f"
            echo "  $out"
            fail=$((fail + 1))
        fi
    done

    # 2. 换行符：module.prop 不允许出现 CR
    if [ -f "$d/module.prop" ] && grep -q $'\r' "$d"/module.prop 2>/dev/null; then
        echo "✖ [$id] module.prop 含 CRLF 换行"
        fail=$((fail + 1))
    fi

    # 3. 必要文件
    for need in module.prop webroot/index.html scripts/api.sh scripts/axcore.sh scripts/dispatch.sh; do
        if [ ! -f "$d$need" ]; then
            echo "✖ [$id] 缺少 $need"
            fail=$((fail + 1))
        fi
    done

    # 4. id 与目录名一致
    if [ -f "$d/module.prop" ]; then
        pid=$(sed -n 's/^id=//p' "$d"/module.prop | head -1 | tr -d '\r')
        if [ "$pid" != "$id" ]; then
            echo "✖ [$id] module.prop 中的 id 为 $pid"
            fail=$((fail + 1))
        fi
        if ! grep -q '^axeronPlugin=' "$d"/module.prop; then
            echo "✖ [$id] module.prop 缺少 axeronPlugin"
            fail=$((fail + 1))
        fi
    fi
done

# 5. zip 完整性
if command -v unzip >/dev/null 2>&1; then
    for z in releases/*.zip; do
        [ -f "$z" ] || continue
        if ! unzip -t "$z" >/dev/null 2>&1; then
            echo "✖ zip 损坏：$z"
            fail=$((fail + 1))
        fi
    done
else
    echo "· 未找到 unzip，跳过压缩包完整性检查"
fi

echo ""
if [ "$fail" -gt 0 ]; then
    echo "校验失败：发现 $fail 个问题（共检查 $checked 个模块）"
    exit 1
fi
echo "校验通过：$checked 个模块全部符合规范"
