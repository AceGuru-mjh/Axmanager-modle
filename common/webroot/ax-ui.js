/* ==========================================================================
   ax-ui.js — AxManager 插件 WebUI 运行时
   --------------------------------------------------------------------------
   两部分职责：
   1) Bridge：对接 AxManager 注入的 ksu 接口（与 KernelSU WebUI API 一致）
        ksu.exec(cmd)                           -> String   同步，仅 stdout
        ksu.exec(cmd, optionsJson, callbackName) -> void     异步 (errno, out, err)
        ksu.spawn(cmd, argsJson, optionsJson, callbackName)  流式
        ksu.toast(msg) / ksu.fullScreen(bool) / ksu.moduleInfo() -> JSON
        ksu.listPackages(type) / ksu.getPackagesInfo(json)
      旧版本插件直接把 ksu.exec(cmd) 当同步字符串用，拿不到退出码与 stderr，
      出错时只能显示空白；这里统一走异步三参数形式并保留同步兜底。
   2) Renderer：由插件的声明式配置渲染统一的 M3 界面，避免 30+ 份重复代码。
   ========================================================================== */
(function (global) {
    'use strict';

    var seq = 0;
    var bridge = global.ksu || global.$axeron || global.Axeron || null;
    var hasAsyncExec = !!(bridge && typeof bridge.exec === 'function' && bridge.exec.length !== 1);

    /* ------------------------------------------------------------ 工具函数 */
    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function el(tag, cls, html) {
        var n = document.createElement(tag);
        if (cls) n.className = cls;
        if (html != null) n.innerHTML = html;
        return n;
    }

    /* KernelSU 侧使用 joinToString("\\n") 拼接多行输出，某些版本会把换行
       传成字面量的反斜杠 n。此处做一次归一化，兼容两种行为。 */
    function normalize(s) {
        s = String(s == null ? '' : s);
        if (s.indexOf('\n') === -1 && s.indexOf('\\n') !== -1) s = s.replace(/\\n/g, '\n');
        return s;
    }

    function hexToRgb(hex) {
        var h = String(hex || '').replace('#', '').trim();
        if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        var n = parseInt(h, 16);
        if (isNaN(n) || h.length !== 6) return '129 140 248';
        return ((n >> 16) & 255) + ' ' + ((n >> 8) & 255) + ' ' + (n & 255);
    }

    function haptic(ms) {
        try { if (navigator.vibrate) navigator.vibrate(ms || 8); } catch (e) { }
    }

    /* ----------------------------------------------------------- 模块目录 */
    var _moddir = null;
    function moddir() {
        if (_moddir) return _moddir;
        try {
            var info = JSON.parse(bridge.moduleInfo());
            if (info && info.moduleDir) { _moddir = info.moduleDir; return _moddir; }
        } catch (e) { }
        // 兜底：由页面自身路径反推（webroot 的父目录即模块根目录）
        try {
            var p = decodeURIComponent(location.pathname).replace(/\/[^/]*$/, '');
            _moddir = p.replace(/\/webroot$/, '');
        } catch (e) { _moddir = ''; }
        return _moddir;
    }

    /* ------------------------------------------------------------ exec */
    function exec(cmd, options) {
        return new Promise(function (resolve) {
            if (!bridge || typeof bridge.exec !== 'function') {
                resolve({ errno: -1, stdout: '', stderr: '未检测到 AxManager 运行环境，请在 AxManager 中打开本页面。' });
                return;
            }
            if (!hasAsyncExec) {
                try {
                    resolve({ errno: 0, stdout: normalize(bridge.exec(cmd)), stderr: '' });
                } catch (e) {
                    resolve({ errno: -1, stdout: '', stderr: String(e && e.message || e) });
                }
                return;
            }
            var name = '__axcb' + (++seq);
            var done = false;
            var timer = setTimeout(function () {
                if (done) return;
                done = true;
                try { delete global[name]; } catch (e) { global[name] = undefined; }
                resolve({ errno: -2, stdout: '', stderr: '命令执行超时（120s）' });
            }, 120000);

            global[name] = function (errno, stdout, stderr) {
                if (done) return;
                done = true;
                clearTimeout(timer);
                try { delete global[name]; } catch (e) { global[name] = undefined; }
                resolve({ errno: Number(errno), stdout: normalize(stdout), stderr: normalize(stderr) });
            };

            try {
                bridge.exec(cmd, JSON.stringify(options || {}), name);
            } catch (e) {
                // 部分实现只提供 (cmd, callbackName) 双参数形式
                try {
                    bridge.exec(cmd, name);
                } catch (e2) {
                    if (!done) {
                        done = true;
                        clearTimeout(timer);
                        try { delete global[name]; } catch (e3) { }
                        try {
                            resolve({ errno: 0, stdout: normalize(bridge.exec(cmd)), stderr: '' });
                        } catch (e4) {
                            resolve({ errno: -1, stdout: '', stderr: String(e4 && e4.message || e4) });
                        }
                    }
                }
            }
        });
    }

    /* ---------------------------------------------------------- spawn 流式 */
    function emitter() {
        return {
            _l: {},
            on: function (ev, fn) { (this._l[ev] = this._l[ev] || []).push(fn); return this; },
            emit: function (ev, d) { (this._l[ev] || []).forEach(function (f) { try { f(d); } catch (e) { } }); }
        };
    }

    function spawn(cmd, args, options) {
        var name = '__axsp' + (++seq);
        var obj = emitter();
        obj.stdout = emitter();
        obj.stderr = emitter();
        global[name] = obj;
        obj.on('exit', function () {
            setTimeout(function () { try { delete global[name]; } catch (e) { } }, 1500);
        });
        try {
            bridge.spawn(cmd, JSON.stringify(args || []), JSON.stringify(options || {}), name);
        } catch (e) {
            setTimeout(function () { obj.emit('error', new Error('当前环境不支持流式执行')); obj.emit('exit', -1); }, 0);
        }
        return obj;
    }

    function toast(msg) {
        try { bridge.toast(String(msg)); } catch (e) { }
    }

    /* =====================================================================
       UI 层
       ===================================================================== */
    var UI = {
        cfg: null,
        _snackT: null,
        logBuf: [],

        /* ------------------------------------------------------- Snackbar */
        snack: function (msg, type, keep) {
            var sb = document.getElementById('axSnack');
            if (!sb) return;
            clearTimeout(UI._snackT);
            var icons = {
                ok: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M20 6 9 17l-5-5"/></svg>',
                err: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>',
                warn: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg>',
                busy: '<div class="ax-spin" style="border-color:rgb(var(--ax-a)/.3);border-top-color:rgb(var(--ax-a))"></div>'
            };
            type = type || 'busy';
            sb.className = 'ax-snack ' + type;
            sb.querySelector('.ax-snack-i').innerHTML = icons[type] || icons.busy;
            sb.querySelector('.ax-snack-t').textContent = msg;
            sb.querySelector('.ax-snack-more').style.display = UI.logBuf.length ? '' : 'none';
            requestAnimationFrame(function () { sb.classList.add('show'); });
            if (!keep && type !== 'busy') {
                UI._snackT = setTimeout(function () { sb.classList.remove('show'); }, 4200);
            }
        },

        /* ----------------------------------------------------- 日志抽屉 */
        log: function (text, append) {
            if (!append) UI.logBuf = [];
            if (text) UI.logBuf = UI.logBuf.concat(String(text).split('\n'));
            var box = document.getElementById('axLog');
            if (!box) return;
            box.innerHTML = UI.logBuf.map(function (line) {
                var t = line.replace(/^::result:.*$/, '');
                if (!t.trim()) return '';
                var c = 'l-info';
                if (/^✔/.test(t)) c = 'l-ok';
                else if (/^✖/.test(t)) c = 'l-err';
                else if (/^⚠/.test(t)) c = 'l-warn';
                else if (/^▸/.test(t)) c = 'l-step';
                else if (/^──/.test(t)) c = 'l-head';
                return '<span class="' + c + '">' + esc(t) + '</span>';
            }).join('\n');
            box.scrollTop = box.scrollHeight;
        },

        sheet: function (open) {
            var s = document.getElementById('axSheet');
            var sc = document.getElementById('axScrim');
            if (!s) return;
            s.classList.toggle('open', open);
            sc.classList.toggle('open', open);
            if (open) UI.log(null, true);
        },

        confirm: function (title, msg, okText) {
            return new Promise(function (resolve) {
                var d = document.getElementById('axDlg');
                d.querySelector('.ax-dlg-t').textContent = title;
                d.querySelector('.ax-dlg-m').textContent = msg;
                var ok = d.querySelector('.ax-dlg-ok');
                var cancel = d.querySelector('.ax-dlg-cancel');
                ok.textContent = okText || '确认';
                function close(v) {
                    d.classList.remove('open');
                    ok.onclick = cancel.onclick = null;
                    resolve(v);
                }
                ok.onclick = function () { haptic(12); close(true); };
                cancel.onclick = function () { close(false); };
                d.classList.add('open');
            });
        },

        busy: function (btn, on, label) {
            if (!btn) return;
            if (on) {
                btn.dataset.html = btn.innerHTML;
                btn.disabled = true;
                btn.innerHTML = '<div class="ax-spin"></div>' + esc(label || '执行中…');
            } else {
                btn.disabled = false;
                if (btn.dataset.html) btn.innerHTML = btn.dataset.html;
            }
        },

        ripple: function (e, node) {
            var r = node.getBoundingClientRect();
            var d = Math.max(r.width, r.height);
            var s = el('span', 'ax-ripple');
            s.style.width = s.style.height = d + 'px';
            s.style.left = ((e.clientX || r.left + r.width / 2) - r.left - d / 2) + 'px';
            s.style.top = ((e.clientY || r.top + r.height / 2) - r.top - d / 2) + 'px';
            node.appendChild(s);
            setTimeout(function () { s.remove(); }, 560);
        }
    };

    /* =====================================================================
       API 调用：统一走 scripts/api.sh <verb> [args...]
       ===================================================================== */
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    function call(verb) {
        var args = Array.prototype.slice.call(arguments, 1);
        var cmd = 'sh ' + shq(moddir() + '/scripts/api.sh') + ' ' + shq(verb);
        args.forEach(function (a) { cmd += ' ' + shq(a); });
        return exec(cmd);
    }

    /* 执行一次动作并把输出接到 UI（日志 + snackbar） */
    function run(opts) {
        var verb = opts.verb;
        var args = opts.args || [];
        var btn = opts.btn;
        UI.busy(btn, true, opts.busyLabel);
        UI.snack(opts.busyLabel || '正在执行…', 'busy', true);
        return call.apply(null, [verb].concat(args)).then(function (r) {
            UI.busy(btn, false);
            var out = (r.stdout || '') + (r.stderr ? '\n' + r.stderr : '');
            UI.log(out, false);
            var m = /^::result:(\S+)/m.exec(r.stdout || '');
            var okFlag = m ? m[1] === 'ok' : r.errno === 0;
            // 取最后一条有语义的输出行作为提示
            var lines = (r.stdout || '').split('\n').filter(function (l) {
                return l.trim() && l.indexOf('::result:') !== 0;
            });
            var tip = opts.okLabel || (lines.length ? lines[lines.length - 1].replace(/^[✔✖⚠·▸]\s*/, '') : '执行完成');
            if (r.errno !== 0 && r.errno !== undefined && !m) {
                UI.snack(r.stderr ? r.stderr.split('\n')[0] : '执行失败（退出码 ' + r.errno + '）', 'err');
            } else {
                UI.snack(tip, okFlag ? 'ok' : 'warn');
            }
            haptic(okFlag ? 10 : 25);
            if (opts.then) opts.then(r, okFlag);
            return r;
        });
    }

    /* =====================================================================
       声明式渲染
       ===================================================================== */
    function renderShell(cfg) {
        document.title = cfg.title;
        var root = document.getElementById('ax-root') || document.body;

        var accent = hexToRgb(cfg.accent || '#818cf8');
        var accent2 = hexToRgb(cfg.accent2 || cfg.accent || '#a855f7');
        document.documentElement.style.setProperty('--ax-a', accent);
        document.documentElement.style.setProperty('--ax-a2', accent2);

        var h = '';
        h += '<header class="ax-hero"><div class="ax-hero-in">';
        h += '<div class="ax-hero-badge"><span class="ax-dot"></span>' + esc(cfg.badge || '免 Root · ADB 级') + '</div>';
        h += '<h1>' + esc(cfg.title) + '</h1>';
        if (cfg.subtitle) h += '<div class="ax-sub">' + esc(cfg.subtitle) + '</div>';
        if (cfg.chips && cfg.chips.length) {
            h += '<div class="ax-chips">' + cfg.chips.map(function (c) {
                return '<span class="ax-chip">' + esc(c) + '</span>';
            }).join('') + '</div>';
        }
        h += '</div></header>';
        h += '<main id="axBody"></main>';
        h += '<footer class="ax-foot"><b>' + esc(cfg.title) + '</b> · AxManager 插件<br>'
            + esc(cfg.footer || '仅使用 shell 级接口 · 无需 root · 全部改动可一键回滚') + '</footer>';

        // 全局部件
        h += '<div class="ax-snack" id="axSnack"><div class="ax-snack-i"></div>'
            + '<div class="ax-snack-t"></div>'
            + '<button class="ax-snack-more" type="button">详情</button></div>';
        h += '<div class="ax-scrim" id="axScrim"></div>';
        h += '<section class="ax-sheet" id="axSheet"><div class="ax-sheet-grip"></div>'
            + '<div class="ax-sheet-h"><h3>执行日志</h3>'
            + '<button class="ax-sheet-x" type="button" aria-label="关闭">✕</button></div>'
            + '<pre class="ax-log" id="axLog"></pre></section>';
        h += '<div class="ax-dlg" id="axDlg"><div class="ax-dlg-box">'
            + '<div class="ax-dlg-t"></div><div class="ax-dlg-m"></div>'
            + '<div class="ax-dlg-a"><button class="ax-dlg-cancel" type="button">取消</button>'
            + '<button class="ax-dlg-ok" type="button">确认</button></div></div></div>';

        root.innerHTML = h;

        document.querySelector('.ax-snack-more').onclick = function () { UI.sheet(true); };
        document.querySelector('.ax-sheet-x').onclick = function () { UI.sheet(false); };
        document.getElementById('axScrim').onclick = function () { UI.sheet(false); };

        // 全局波纹
        document.addEventListener('click', function (e) {
            var t = e.target.closest('.ax-btn, .ax-act, .ax-opt');
            if (t && !t.disabled) { UI.ripple(e, t); haptic(6); }
        }, true);
    }

    var state = {};   // 各 section 的选中值

    function renderSection(sec, idx) {
        var body = document.getElementById('axBody');
        var wrapId = 'axSec' + idx;
        var frag = el('div', 'ax-in');
        frag.style.animationDelay = Math.min(idx * 60, 400) + 'ms';
        frag.id = wrapId;

        if (sec.title) {
            var st = el('div', 'ax-sect');
            st.innerHTML = '<span>' + esc(sec.title) + '</span>';
            frag.appendChild(st);
        }

        var box = el('div', 'ax-wrap');
        frag.appendChild(box);

        switch (sec.type) {
            case 'note': {
                var n = el('div', 'ax-note');
                n.style.margin = '0';
                n.innerHTML = '<div class="ax-note-i"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" '
                    + 'stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/>'
                    + '<path d="M12 8v4M12 16h.01"/></svg></div>'
                    + '<div><strong>' + esc(sec.heading || '使用须知') + '</strong><span>' + esc(sec.text) + '</span></div>';
                box.appendChild(n);
                break;
            }

            case 'profiles': {
                state[sec.id || 'profile'] = sec.value || (sec.items[0] && sec.items[0].id);
                sec.items.forEach(function (it) {
                    var b = el('button', 'ax-opt' + (it.id === state[sec.id || 'profile'] ? ' sel' : ''));
                    b.type = 'button';
                    b.dataset.v = it.id;
                    b.innerHTML = '<div class="ax-opt-row">'
                        + '<div class="ax-opt-ico">' + esc(it.icon || '◆') + '</div>'
                        + '<div class="ax-opt-txt"><div class="ax-opt-t">' + esc(it.title) + '</div>'
                        + '<div class="ax-opt-d">' + esc(it.desc || '') + '</div></div></div>'
                        + '<div class="ax-opt-tags">' + (it.tags || []).map(function (t) {
                            return '<span class="ax-tag">' + esc(t) + '</span>';
                        }).join('') + '</div>'
                        + '<div class="ax-opt-check"></div>';
                    b.onclick = function () {
                        box.querySelectorAll('.ax-opt').forEach(function (x) { x.classList.remove('sel'); });
                        b.classList.add('sel');
                        state[sec.id || 'profile'] = it.id;
                    };
                    box.appendChild(b);
                });
                break;
            }

            case 'actions': {
                var g = el('div', 'ax-grid');
                sec.items.forEach(function (it) {
                    var b = el('button', 'ax-act' + (it.danger ? ' danger' : ''));
                    b.type = 'button';
                    b.innerHTML = '<div class="ax-act-ico">' + esc(it.icon || '⚙') + '</div>'
                        + '<div class="ax-act-l">' + esc(it.label) + '</div>';
                    b.onclick = function () {
                        (it.confirm
                            ? UI.confirm(it.label, it.confirm, '继续')
                            : Promise.resolve(true)
                        ).then(function (go) {
                            if (!go) return;
                            run({
                                verb: it.verb, args: it.args || [], btn: null,
                                busyLabel: it.label + '…',
                                then: function (r, ok) {
                                    if (it.showLog !== false && (r.stdout || '').split('\n').length > 3) UI.sheet(true);
                                    if (it.refresh) refreshAll();
                                }
                            });
                        });
                    };
                    g.appendChild(b);
                });
                box.appendChild(g);
                break;
            }

            case 'metrics': {
                var mg = el('div', 'ax-metrics');
                mg.id = wrapId + 'M';
                sec.fields.forEach(function (f) {
                    var c = el('div', 'ax-metric');
                    c.dataset.k = f.key;
                    c.innerHTML = '<div class="ax-metric-h">' + esc(f.icon || '') + '<span>' + esc(f.label) + '</span></div>'
                        + '<div class="ax-metric-v"><span class="v">—</span>'
                        + (f.unit ? '<span class="ax-metric-u">' + esc(f.unit) + '</span>' : '') + '</div>'
                        + (f.bar ? '<div class="ax-bar"><div class="ax-bar-f"></div></div>' : '');
                    mg.appendChild(c);
                });
                box.appendChild(mg);
                registerPoll(sec, mg);
                break;
            }

            case 'list': {
                var lc = el('div', 'ax-card');
                lc.style.padding = '4px 0';
                lc.id = wrapId + 'L';
                lc.innerHTML = '<div class="ax-empty">加载中…</div>';
                box.appendChild(lc);
                registerList(sec, lc);
                break;
            }

            case 'switches': {
                sec.items.forEach(function (it) {
                    var r = el('div', 'ax-row');
                    r.innerHTML = '<div class="ax-row-txt"><div class="ax-row-t">' + esc(it.label) + '</div>'
                        + (it.desc ? '<div class="ax-row-d">' + esc(it.desc) + '</div>' : '') + '</div>';
                    var sw = el('div', 'ax-sw' + (it.value ? ' on' : ''));
                    state[it.id] = !!it.value;
                    sw.onclick = function () {
                        var on = !sw.classList.contains('on');
                        sw.classList.toggle('on', on);
                        state[it.id] = on;
                        haptic(10);
                        if (it.verb) {
                            // 向后兼容：未声明 args 时仍只传 on/off
                            var a = (it.args ? it.args.concat([on ? 'on' : 'off']) : [on ? 'on' : 'off']);
                            run({
                                verb: it.verb, args: a, busyLabel: it.label,
                                then: function () { if (it.syncKey) refreshAll(); }
                            });
                        }
                    };
                    // 可选：由 status 轮询同步设备真实状态（仅同步视觉，不触发动词）
                    if (it.syncKey) {
                        var tgt = { el: sw, id: it.id, key: it.syncKey, invert: !!it.invert };
                        syncTargets.push(tgt);
                        if (lastStatus && lastStatus[it.syncKey] !== undefined) {
                            applySyncOne(tgt, lastStatus);
                        }
                    }
                    r.appendChild(sw);
                    box.appendChild(r);
                });
                break;
            }

            case 'slider': {
                var c2 = el('div', 'ax-card');
                state[sec.id] = sec.value;
                c2.innerHTML = '<div class="ax-slider-head"><div><div class="ax-row-t">' + esc(sec.label) + '</div>'
                    + (sec.desc ? '<div class="ax-row-d">' + esc(sec.desc) + '</div>' : '') + '</div>'
                    + '<div class="ax-slider-val">' + esc(sec.value) + esc(sec.unit || '') + '</div></div>';
                var r2 = el('input');
                r2.type = 'range';
                r2.min = sec.min; r2.max = sec.max; r2.step = sec.step || 1; r2.value = sec.value;
                r2.oninput = function () {
                    state[sec.id] = r2.value;
                    c2.querySelector('.ax-slider-val').textContent = r2.value + (sec.unit || '');
                };
                c2.appendChild(r2);
                box.appendChild(c2);
                break;
            }

            case 'input': {
                var c3 = el('div', 'ax-card');
                var lab = el('div', 'ax-row-t', esc(sec.label || ''));
                c3.appendChild(lab);
                if (sec.hint) c3.appendChild(el('div', 'ax-row-d', esc(sec.hint)));
                var inp = el('input', 'ax-input');
                inp.type = 'text';
                inp.id = 'axIn' + idx;
                inp.placeholder = sec.placeholder || '';
                inp.value = sec.value || '';
                state[sec.id] = inp.value;
                inp.oninput = function () { state[sec.id] = inp.value; };
                c3.appendChild(inp);
                var sub = el('button', 'ax-btn ax-btn-primary');
                sub.type = 'button';
                sub.style.marginTop = '12px';
                sub.textContent = sec.buttonLabel || '执行';
                sub.onclick = function () {
                    var v = (state[sec.id] || '').trim();
                    if (sec.required && !v) { UI.snack('请先输入内容', 'warn'); return; }
                    run({
                        verb: sec.verb, args: v ? v.split(/\s+/) : [], btn: sub,
                        busyLabel: (sec.buttonLabel || '执行') + '…'
                    });
                };
                c3.appendChild(sub);
                box.appendChild(c3);
                break;
            }

            case 'html': {
                box.innerHTML = sec.html;
                break;
            }
        }

        body.appendChild(frag);
    }

    /* ---------------------------------------------------- 监控轮询 / 列表 */
    var polls = [];

    /* status 轮询结果缓存 + 开关同步目标表。
       仅当 switch 声明了 syncKey 时才会注册，不影响既有插件。 */
    var lastStatus = null;
    var syncTargets = [];

    function syncTruthy(v) {
        if (v === true) return true;
        var s = String(v == null ? '' : v).trim().toLowerCase();
        return s === '1' || s === 'true' || s === 'on' || s === 'yes' || s === 'shown';
    }

    function applySyncOne(tgt, data) {
        var v = syncTruthy(data[tgt.key]);
        var on = tgt.invert ? !v : v;
        tgt.el.classList.toggle('on', on);
        state[tgt.id] = on;
    }

    function applySync(data) {
        syncTargets.forEach(function (t) { applySyncOne(t, data); });
    }

    function registerPoll(sec, node) {
        function tick() {
            return call(sec.verb || 'status').then(function (r) {
                var data;
                try { data = JSON.parse((r.stdout || '').trim().split('\n').pop()); } catch (e) { return; }
                sec.fields.forEach(function (f) {
                    var card = node.querySelector('[data-k="' + f.key + '"]');
                    if (!card) return;
                    var v = data[f.key];
                    card.querySelector('.v').textContent = (v == null || v === '') ? '—' : v;
                    var bar = card.querySelector('.ax-bar-f');
                    if (bar) {
                        var pct = Math.max(0, Math.min(100, parseFloat(data[f.barKey || f.key]) || 0));
                        bar.style.width = pct + '%';
                    }
                });
                lastStatus = data;
                applySync(data);
            });
        }
        polls.push(tick);
        tick();
        if (sec.interval) setInterval(tick, Math.max(1000, sec.interval));
    }

    function registerList(sec, node) {
        function load() {
            node.innerHTML = '<div style="padding:16px 14px"><div class="ax-skel" style="width:70%"></div>'
                + '<div class="ax-skel" style="width:45%;margin-top:10px"></div></div>';
            return call.apply(null, [sec.verb].concat(sec.args || [])).then(function (r) {
                var lines = (r.stdout || '').split('\n').filter(function (l) {
                    return l.trim() && l.indexOf('::result:') !== 0;
                });
                if (!lines.length) {
                    node.innerHTML = '<div class="ax-empty">' + esc(sec.empty || '暂无数据') + '</div>';
                    return;
                }
                node.innerHTML = '';
                // 约定格式： 标题 | 副标题 | 徽标 | 徽标类型 | 点击载荷
                lines.slice(0, sec.limit || 200).forEach(function (l) {
                    var p = l.split('|');
                    var row = el('div', 'ax-li' + (sec.clickVerb ? ' ax-li-tap' : ''));
                    var pill = p[2] ? '<span class="ax-pill ' + esc((p[3] || 'dim').trim()) + '">'
                        + esc(p[2].trim()) + '</span>' : '';
                    row.innerHTML = '<div class="ax-li-txt"><div class="ax-li-t">' + esc((p[0] || '').trim())
                        + '</div>' + (p[1] ? '<div class="ax-li-d">' + esc(p[1].trim()) + '</div>' : '')
                        + '</div>' + pill;
                    if (sec.clickVerb) {
                        // 载荷缺省用第 1 段（标题），旧格式无需改动即可兼容
                        var payload = (p[4] !== undefined ? p[4] : (p[0] || '')).trim();
                        row.onclick = function () {
                            haptic(8);
                            run({
                                verb: sec.clickVerb,
                                args: payload ? payload.split(/\s+/) : [],
                                busyLabel: sec.clickLabel || '正在设置…'
                            });
                        };
                    }
                    node.appendChild(row);
                });
            });
        }
        polls.push(load);
        load();
    }

    function refreshAll() { polls.forEach(function (f) { try { f(); } catch (e) { } }); }

    /* --------------------------------------------------------- 主操作区 */
    function renderCta(cfg) {
        var body = document.getElementById('axBody');
        var wrap = el('div', 'ax-cta ax-in');
        wrap.style.animationDelay = '420ms';

        if (cfg.apply !== false) {
            var ap = el('button', 'ax-btn ax-btn-primary');
            ap.type = 'button';
            ap.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
                + 'stroke-width="2.6" stroke-linecap="round"><path d="M20 6 9 17l-5-5"/></svg>'
                + esc(cfg.applyLabel || '应用所选方案');
            ap.onclick = function () {
                var pid = state[cfg.profileId || 'profile'];
                run({
                    verb: cfg.applyVerb || 'apply',
                    args: pid ? [pid] : [],
                    btn: ap,
                    busyLabel: '正在应用…',
                    then: function (r) { refreshAll(); }
                });
            };
            wrap.appendChild(ap);
        }

        (cfg.extraButtons || []).forEach(function (b) {
            var n = el('button', 'ax-btn ax-btn-tonal');
            n.type = 'button';
            n.textContent = b.label;
            n.onclick = function () {
                run({ verb: b.verb, args: b.args || [], btn: n, busyLabel: b.label + '…', then: function () { refreshAll(); } });
            };
            wrap.appendChild(n);
        });

        if (cfg.revert !== false) {
            var rv = el('button', 'ax-btn ax-btn-ghost');
            rv.type = 'button';
            rv.innerHTML = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
                + 'stroke-width="2.2" stroke-linecap="round"><path d="M3 12a9 9 0 1 0 9-9 9.7 9.7 0 0 0-6.7 2.7L3 8"/>'
                + '<path d="M3 3v5h5"/></svg>' + esc(cfg.revertLabel || '一键回滚全部改动');
            rv.onclick = function () {
                UI.confirm('回滚全部改动',
                    '将依据修改日志把本插件改过的每一项设置恢复到原始值，未被本插件修改的内容不受影响。',
                    '确认回滚'
                ).then(function (go) {
                    if (!go) return;
                    run({ verb: 'revert', btn: rv, busyLabel: '正在回滚…', then: function () { refreshAll(); } });
                });
            };
            wrap.appendChild(rv);
        }

        body.appendChild(wrap);
    }

    /* --------------------------------------------------------------- app */
    function app(cfg) {
        UI.cfg = cfg;
        function boot() {
            renderShell(cfg);
            (cfg.sections || []).forEach(renderSection);
            renderCta(cfg);
            // 同步设备端当前生效档位，让界面反映真实状态而非默认值
            if (cfg.apply !== false) {
                call('current').then(function (r) {
                    var v = (r.stdout || '').trim().split('\n').pop().trim();
                    if (!v) return;
                    var t = document.querySelector('.ax-opt[data-v="' + v + '"]');
                    if (!t) return;
                    t.parentNode.querySelectorAll('.ax-opt').forEach(function (x) { x.classList.remove('sel'); });
                    t.classList.add('sel');
                    state[cfg.profileId || 'profile'] = v;
                });
            }
            if (!bridge) {
                UI.snack('未检测到 AxManager 环境，界面为预览模式', 'warn');
            }
        }
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', boot);
        } else boot();
    }

    global.AX = {
        app: app, exec: exec, spawn: spawn, call: call, run: run,
        moddir: moddir, toast: toast, ui: UI, state: state,
        refresh: refreshAll, esc: esc, haptic: haptic
    };
})(window);
