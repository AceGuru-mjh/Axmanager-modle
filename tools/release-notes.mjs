#!/usr/bin/env node
/* ============================================================================
 * release-notes.mjs — 由构建产物生成 GitHub Release 说明
 * ----------------------------------------------------------------------------
 * 读取 dist/index.json（由 build.mjs 生成），按分类输出插件清单 Markdown。
 * 本地与 CI 均可用：node tools/release-notes.mjs > release-notes.md
 * ========================================================================== */

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const INDEX = join(ROOT, 'dist', 'index.json');

if (!existsSync(INDEX)) {
    console.error('未找到 dist/index.json，请先执行 node tools/build.mjs');
    process.exit(1);
}

const { generated, count, plugins } = JSON.parse(readFileSync(INDEX, 'utf8'));

const byCat = new Map();
for (const p of plugins) {
    const c = p.category || '其它';
    if (!byCat.has(c)) byCat.set(c, []);
    byCat.get(c).push(p);
}

const L = [];
L.push(`## AXManager 插件合集`);
L.push('');
L.push(`共 **${count}** 个插件 · 免 Root（ADB / Shell 级权限） · Material 3 WebUI`);
L.push('');
L.push('构建时间（UTC）：' + generated.replace('T', ' ').replace(/\.\d+Z$/, 'Z'));
L.push('');

L.push('### 安装');
L.push('');
L.push('1. 下载下方需要的插件 zip');
L.push('2. AxManager → 插件 → 导入，选择 zip');
L.push('3. 在插件列表中打开 **WebUI**，选择档位后应用');
L.push('');
L.push('所有改动均写入模块内 `.state/journal.tsv`，可在面板内一键回滚；');
L.push('卸载插件时会自动先回滚再移除。');
L.push('');

L.push('### 校验');
L.push('');
L.push('下载 `SHA256SUMS.txt` 后可核对文件完整性：');
L.push('');
L.push('```bash');
L.push('sha256sum -c SHA256SUMS.txt');
L.push('```');
L.push('');

L.push('### 插件清单');
L.push('');
for (const [cat, items] of byCat) {
    L.push(`#### ${cat}`);
    L.push('');
    L.push('| 插件 | 说明 |');
    L.push('|------|------|');
    for (const p of items) {
        L.push(`| \`${p.id}\` | ${(p.desc || '').replace(/\|/g, '\\|')} |`);
    }
    L.push('');
}

L.push('---');
L.push('');
L.push('**能力边界**：免 Root 环境下无法修改 CPU 调频、GPU 频率、ZRAM/Swap、');
L.push('TCP 参数、`/system/etc/hosts`、蓝牙音频编码、进程 OOM 优先级等需要 root 的项。');
L.push('插件不会伪装这些能力，而是在界面中如实说明并给出等效替代方案。');
L.push('');

process.stdout.write(L.join('\n'));
