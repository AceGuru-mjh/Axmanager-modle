#!/usr/bin/env node
/* ============================================================================
 * build.mjs — AxManager 插件构建器
 * ----------------------------------------------------------------------------
 * 源码布局（每个插件仅需 2 个文件，公共部分不再重复 30 遍）：
 *   plugins/<id>/plugin.json   元数据 + WebUI 声明式配置
 *   plugins/<id>/api.sh        业务逻辑（apply_profile / ax_custom / ax_status）
 *
 * 构建产物：
 *   dist/<id>/                 完整可刷入模块目录
 *   releases/<id>.zip          可在 AxManager 中直接刷入的安装包
 *
 * 关键点：
 *   - 所有 .sh / .prop / .html 一律以 LF 换行写出。AxManager 要求 module.prop
 *     使用 UNIX 换行，CRLF 会导致 versionCode 解析失败、插件不被识别。
 *   - zip 内不含顶层目录（模块文件位于压缩包根）。
 *   - 校验 id 合法性、axeronPlugin 字段、profile 与 UI 配置的一致性。
 * ========================================================================== */

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateRawSync, crc32 } from 'node:zlib';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PLUGINS = join(ROOT, 'plugins');
const COMMON = join(ROOT, 'common');
const DIST = join(ROOT, 'dist');
const RELEASES = join(ROOT, 'releases');

const ID_RE = /^[a-zA-Z][a-zA-Z0-9._-]+$/;

/* --------------------------------------------------------------- 小工具 */
const read = (p) => readFileSync(p, 'utf8');
const lf = (s) => s.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

function writeLF(p, content) {
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, lf(content), 'utf8');
}

function walk(dir, base = dir, out = []) {
    for (const name of readdirSync(dir)) {
        const full = join(dir, name);
        if (statSync(full).isDirectory()) walk(full, base, out);
        else out.push(relative(base, full).split(sep).join('/'));
    }
    return out;
}

/* ---------------------------------------------------------------- ZIP 打包
 * 手写 store/deflate ZIP，避免引入依赖。所有条目使用 UTF-8 标记位。 */
function zip(files) {
    const chunks = [];
    const central = [];
    let offset = 0;

    const dosTime = () => {
        const d = new Date();
        const time = ((d.getHours() & 31) << 11) | ((d.getMinutes() & 63) << 5) | ((d.getSeconds() / 2) & 31);
        const date = (((d.getFullYear() - 1980) & 127) << 9) | (((d.getMonth() + 1) & 15) << 5) | (d.getDate() & 31);
        return { time, date };
    };
    const { time, date } = dosTime();

    for (const { name, data } of files) {
        const raw = Buffer.isBuffer(data) ? data : Buffer.from(data, 'utf8');
        const comp = deflateRawSync(raw, { level: 9 });
        const useDeflate = comp.length < raw.length;
        const body = useDeflate ? comp : raw;
        const method = useDeflate ? 8 : 0;
        const crc = crc32(raw);
        const nameBuf = Buffer.from(name, 'utf8');

        const local = Buffer.alloc(30);
        local.writeUInt32LE(0x04034b50, 0);
        local.writeUInt16LE(20, 4);
        local.writeUInt16LE(0x0800, 6);           // UTF-8 文件名
        local.writeUInt16LE(method, 8);
        local.writeUInt16LE(time, 10);
        local.writeUInt16LE(date, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(body.length, 18);
        local.writeUInt32LE(raw.length, 22);
        local.writeUInt16LE(nameBuf.length, 26);
        chunks.push(local, nameBuf, body);

        const cd = Buffer.alloc(46);
        cd.writeUInt32LE(0x02014b50, 0);
        cd.writeUInt16LE(0x031e, 4);              // Unix, zip 3.0
        cd.writeUInt16LE(20, 6);
        cd.writeUInt16LE(0x0800, 8);
        cd.writeUInt16LE(method, 10);
        cd.writeUInt16LE(time, 12);
        cd.writeUInt16LE(date, 14);
        cd.writeUInt32LE(crc, 16);
        cd.writeUInt32LE(body.length, 20);
        cd.writeUInt32LE(raw.length, 24);
        cd.writeUInt16LE(nameBuf.length, 28);
        cd.writeUInt32LE((0o100644 << 16) >>> 0, 38);  // 外部属性：普通文件 644
        cd.writeUInt32LE(offset, 42);
        central.push(cd, nameBuf);

        offset += local.length + nameBuf.length + body.length;
    }

    const cdBuf = Buffer.concat(central);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(files.length, 8);
    end.writeUInt16LE(files.length, 10);
    end.writeUInt32LE(cdBuf.length, 12);
    end.writeUInt32LE(offset, 16);

    return Buffer.concat([...chunks, cdBuf, end]);
}

/* -------------------------------------------------------------- 校验逻辑 */
function validate(id, cfg, api) {
    const errs = [];
    if (!ID_RE.test(cfg.id)) errs.push(`id "${cfg.id}" 不符合 ^[a-zA-Z][a-zA-Z0-9._-]+$`);
    if (cfg.id !== id) errs.push(`plugin.json 的 id "${cfg.id}" 与目录名 "${id}" 不一致（AxManager 以目录名定位模块，必须相同）`);
    if (!cfg.name) errs.push('缺少 name');
    if (!cfg.version) errs.push('缺少 version');
    if (!Number.isInteger(cfg.versionCode)) errs.push('versionCode 必须是整数');
    if (!Number.isInteger(cfg.axeronPlugin)) errs.push('axeronPlugin 必须是整数');
    if (!cfg.description) errs.push('缺少 description');

    const secs = cfg.ui?.sections || [];
    const profiles = secs.find((s) => s.type === 'profiles');

    // 若声明了档位，api.sh 必须实现 apply_profile 且覆盖全部分支
    if (profiles) {
        if (!/apply_profile\s*\(\)/.test(api)) errs.push('声明了 profiles 但 api.sh 未定义 apply_profile()');
        for (const it of profiles.items || []) {
            if (!new RegExp(`(^|[|(\\s])${it.id}\\)`, 'm').test(api)) {
                errs.push(`档位 "${it.id}" 在 api.sh 中没有对应的 case 分支`);
            }
        }
    } else if (cfg.ui?.apply !== false) {
        errs.push('未声明 profiles，需在 ui 中设置 "apply": false');
    }

    // 所有 UI 引用到的动词都必须能被 api.sh 处理
    const builtin = new Set(['apply', 'revert', 'current', 'action', 'reapply', 'status']);
    const verbs = new Set();
    for (const s of secs) {
        if (s.verb) verbs.add(s.verb);
        for (const it of s.items || []) if (it.verb) verbs.add(it.verb);
    }
    for (const b of cfg.ui?.extraButtons || []) if (b.verb) verbs.add(b.verb);
    const custom = [...verbs].filter((v) => !builtin.has(v));
    if (custom.length && !/ax_custom\s*\(\)/.test(api)) {
        errs.push(`使用了自定义动词 ${custom.join(', ')} 但 api.sh 未定义 ax_custom()`);
    }
    for (const v of custom) {
        if (!new RegExp(`(^|[|(\\s])${v}\\)`, 'm').test(api)) {
            errs.push(`自定义动词 "${v}" 在 ax_custom 中没有对应分支`);
        }
    }
    if (secs.some((s) => s.type === 'metrics') && !/ax_status\s*\(\)/.test(api)) {
        errs.push('声明了 metrics 面板但 api.sh 未定义 ax_status()');
    }
    return errs;
}

/* ------------------------------------------------------------------ 主流程 */
const only = process.argv.slice(2).filter((a) => !a.startsWith('-'));
const skipZip = process.argv.includes('--no-zip');

const axcore = read(join(COMMON, 'axcore.sh'));
const dispatch = read(join(COMMON, 'dispatch.sh'));
const uiCss = read(join(COMMON, 'webroot', 'ax-ui.css'));
const uiJs = read(join(COMMON, 'webroot', 'ax-ui.js'));
const htmlTpl = read(join(COMMON, 'templates', 'index.html'));
const tpl = (n) => read(join(COMMON, 'templates', n));

if (existsSync(DIST)) rmSync(DIST, { recursive: true, force: true });
mkdirSync(DIST, { recursive: true });
mkdirSync(RELEASES, { recursive: true });

const ids = readdirSync(PLUGINS)
    .filter((d) => statSync(join(PLUGINS, d)).isDirectory())
    .filter((d) => existsSync(join(PLUGINS, d, 'plugin.json')))
    .filter((d) => !only.length || only.includes(d))
    .sort();

let failed = 0;
const built = [];

for (const id of ids) {
    const src = join(PLUGINS, id);
    let cfg;
    try {
        cfg = JSON.parse(read(join(src, 'plugin.json')));
    } catch (e) {
        console.error(`✖ ${id}: plugin.json 解析失败 — ${e.message}`);
        failed++;
        continue;
    }
    const apiPath = join(src, 'api.sh');
    if (!existsSync(apiPath)) {
        console.error(`✖ ${id}: 缺少 api.sh`);
        failed++;
        continue;
    }
    const api = read(apiPath);

    const errs = validate(id, cfg, api);
    if (errs.length) {
        console.error(`✖ ${id}:`);
        errs.forEach((e) => console.error(`    - ${e}`));
        failed++;
        continue;
    }

    /* ---- module.prop ---- */
    const prop = [
        `id=${cfg.id}`,
        `name=${cfg.name}`,
        `version=${cfg.version}`,
        `versionCode=${cfg.versionCode}`,
        `author=${cfg.author || 'MJH'}`,
        `description=${cfg.description}`,
        `axeronPlugin=${cfg.axeronPlugin}`,
        ''
    ].join('\n');

    /* ---- WebUI 配置 ---- */
    const ui = {
        title: cfg.name,
        subtitle: cfg.subtitle || '',
        badge: cfg.badge || '免 Root · ADB 级',
        accent: cfg.accent || '#818cf8',
        accent2: cfg.accent2 || cfg.accent || '#a855f7',
        chips: cfg.chips || [],
        footer: cfg.footer || '仅使用 shell 级接口 · 无需 root · 全部改动可一键回滚',
        ...cfg.ui
    };

    const files = new Map();
    const put = (name, data) => files.set(name, lf(String(data)));

    put('module.prop', prop);
    put('customize.sh', tpl('customize.sh'));
    put('action.sh', tpl('action.sh'));
    put('uninstall.sh', tpl('uninstall.sh'));
    if (cfg.bootRestore !== false) put('service.sh', tpl('service.sh'));
    put('scripts/axcore.sh', axcore);
    put('scripts/dispatch.sh', dispatch);
    put('scripts/api.sh', api);
    put('webroot/ax-ui.css', uiCss);
    put('webroot/ax-ui.js', uiJs);
    put('webroot/index.html',
        htmlTpl
            .replace('__TITLE__', cfg.name)
            .replace('__CONFIG__', JSON.stringify(ui, null, 0))
    );

    // 插件可携带额外资源（如 assets/ 数据文件）
    const extraDir = join(src, 'extra');
    if (existsSync(extraDir)) {
        for (const rel of walk(extraDir)) put(rel, read(join(extraDir, rel)));
    }

    /* ---- 写 dist ---- */
    for (const [name, data] of files) writeLF(join(DIST, id, name), data);

    /* ---- 打 zip ---- */
    if (!skipZip) {
        const entries = [...files.entries()]
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([name, data]) => ({ name, data: Buffer.from(lf(data), 'utf8') }));
        writeFileSync(join(RELEASES, `${id}.zip`), zip(entries));
    }

    built.push({ id, name: cfg.name, category: cfg.category || '其它', desc: cfg.summary || cfg.description });
    console.log(`✔ ${id.padEnd(26)} ${cfg.name}`);
}

console.log('');
if (failed) {
    console.error(`构建失败：${failed} 个插件存在问题，成功 ${built.length} 个`);
    process.exit(1);
}
console.log(`构建完成：${built.length} 个插件 → dist/ 与 releases/`);

writeLF(join(ROOT, 'dist', 'index.json'), JSON.stringify({
    generated: new Date().toISOString(),
    count: built.length,
    plugins: built
}, null, 2));
