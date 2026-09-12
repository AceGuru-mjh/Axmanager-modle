#!/usr/bin/env node
/* ============================================================================
 * gen-readme.mjs — 由各插件的 plugin.json 生成 README 中的统计与插件清单
 * ----------------------------------------------------------------------------
 * 用法：node tools/gen-readme.mjs
 *
 * 读取全部插件元数据，生成两个区块并写回 README.md 的标记之间：
 *   <!-- STATS:START --> ... <!-- STATS:END -->     分类分布徽章
 *   <!-- PLUGINS:START --> ... <!-- PLUGINS:END --> 插件清单表格（模块名为下载链接）
 *
 * 这样插件清单永远与源码同步，不会出现手工维护导致的漏项或版本不一致。
 * ========================================================================== */

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PLUGINS = join(ROOT, 'plugins');
const README = join(ROOT, 'README.md');

const REPO = 'AceGuru-mjh/Axmanager-modle';
const TAG = process.env.RELEASE_TAG || 'v2.0.0';
const BASE = `https://github.com/${REPO}/releases/download/${TAG}`;

// 分类展示顺序（未列出的分类排到最后）
const ORDER = ['系统调优', '网络优化', '显示与音频', '应用管理', '系统工具', '扩展插件', '新增玩法'];
const ICON = {
    '系统调优': '⚙️',
    '网络优化': '🌐',
    '显示与音频': '🎨',
    '应用管理': '📦',
    '系统工具': '🛠',
    '扩展插件': '🧩',
    '新增玩法': '✨'
};

/* ------------------------------------------------------------------ 收集 */
const items = [];
for (const dir of readdirSync(PLUGINS)) {
    const p = join(PLUGINS, dir);
    if (!statSync(p).isDirectory()) continue;
    const f = join(p, 'plugin.json');
    if (!existsSync(f)) continue;
    let cfg;
    try {
        cfg = JSON.parse(readFileSync(f, 'utf8'));
    } catch (e) {
        console.error(`跳过 ${dir}：plugin.json 解析失败 — ${e.message}`);
        continue;
    }
    if (cfg.id !== dir) console.warn(`警告：${dir} 的 id 为 ${cfg.id}，二者应一致`);
    items.push({
        id: cfg.id,
        name: cfg.name || cfg.id,
        summary: cfg.summary || (cfg.description || '').slice(0, 60),
        category: cfg.category || '其它',
        chips: cfg.chips || []
    });
}

items.sort((a, b) => a.id.localeCompare(b.id));

const groups = new Map();
for (const it of items) {
    if (!groups.has(it.category)) groups.set(it.category, []);
    groups.get(it.category).push(it);
}
const cats = [...groups.keys()].sort((a, b) => {
    const ia = ORDER.indexOf(a), ib = ORDER.indexOf(b);
    return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib) || a.localeCompare(b);
});

/* -------------------------------------------------------------- STATS 区块 */
const enc = (s) => encodeURIComponent(String(s).replace(/-/g, '--').replace(/_/g, '__'));
const badge = (label, msg, color) =>
    `![${label}](https://img.shields.io/badge/${enc(label)}-${enc(msg)}-${color}?style=flat-square)`;

const S = [];
S.push(`当前共 **${items.length}** 个插件，分为 ${cats.length} 类：`);
S.push('');
S.push(cats.map((c) => badge(`${ICON[c] || '•'} ${c}`, `${groups.get(c).length}`, 'orange')).join(' '));
S.push('');

/* ------------------------------------------------------------ PLUGINS 区块 */
const P = [];
P.push(`> 点击**模块名**即可下载对应的 zip（当前版本 \`${TAG}\`）；`);
P.push(`> 也可前往 [Releases 页面](https://github.com/${REPO}/releases/latest) 一次性下载全部。`);
P.push('');
for (const c of cats) {
    const list = groups.get(c);
    P.push(`### ${ICON[c] || '•'} ${c}`);
    P.push('');
    P.push('| 模块 | 说明 | 技术点 |');
    P.push('|------|------|--------|');
    for (const it of list) {
        // 模块名即下载链接，GitHub 渲染为蓝色可点击文字。
        // 这里特意不用反引号：code span 会覆盖链接色，
        // 加粗而不加反引号才能确保呈现为蓝色。
        const link = `[**${it.id}**](${BASE}/${it.id}.zip)`;
        const desc = String(it.summary).replace(/\|/g, '\\|');
        const tech = (it.chips || []).slice(0, 3).map((t) => `\`${t}\``).join(' ');
        P.push(`| ${link} | ${desc} | ${tech} |`);
    }
    P.push('');
}

/* ---------------------------------------------------------------- 写回文件 */
let md = readFileSync(README, 'utf8');
const swap = (name, body) => {
    const re = new RegExp(`<!-- ${name}:START -->([\\s\\S]*?)<!-- ${name}:END -->`);
    if (!re.test(md)) throw new Error(`README.md 中未找到 <!-- ${name}:START/END --> 标记`);
    md = md.replace(re, `<!-- ${name}:START -->\n${body}\n<!-- ${name}:END -->`);
};

swap('STATS', S.join('\n'));
swap('PLUGINS', P.join('\n'));

writeFileSync(README, md.replace(/\r\n/g, '\n'), 'utf8');
console.log(`已更新 README.md：${items.length} 个插件 / ${cats.length} 个分类（版本 ${TAG}）`);
