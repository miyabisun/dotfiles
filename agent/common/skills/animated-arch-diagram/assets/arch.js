// 動く構成図のエンジンと小窓プレイヤー。spec.js の window.SPEC を時刻 t の SVG に描く。
// 絵は t だけで決まる (乱数や実時間を描画に使わない) ので、どの時刻へ飛んでも同じ絵になる。
(function (root) {
  'use strict';

  // 秒単位の演出の長さ
  const GAP = 0.22; // ノードが 1 つずつ現れる間隔
  const POP = 0.45; // ノード 1 つが現れきるまで
  const DRAW = 0.5; // 線 1 本を引ききるまで
  const HOP = 0.8; // 札が 1 区間を流れる時間 (step.hop で上書き)
  const LINE = 0.35; // 吹き出しの行が次の行を出すまで
  const LINE_FADE = 0.3; // 吹き出しの 1 行が現れきるまで
  const CPS = 14; // 字幕が 1 秒に出す文字数
  const HOLD = 1.6; // 全部が出そろってから次へ移るまでの間
  const OUTRO = 3.5; // 締めの長さ (outro.dur で上書き)
  const FADE = 0.6; // 最後に消えていく時間
  const BACK = 0.6; // ステップの頭からこれ以内で「前へ」を押すと、1 つ前へ戻る

  const clamp01 = (x) => Math.min(1, Math.max(0, x));
  const ease = (x) => {
    const c = clamp01(x);
    return c * c * (3 - 2 * c);
  };

  const hopOf = (step) => step.hop ?? HOP;
  const flowEnd = (step) => (step.flow?.length ?? 0) * hopOf(step);
  const graphemes = (text) =>
    Array.from(new Intl.Segmenter('ja', { granularity: 'grapheme' }).segment(text ?? ''), (s) => s.segment);

  function stepDur(step) {
    if (step.dur != null) return step.dur;
    const lines = step.note?.lines?.length ?? 0;
    const noteEnd = lines ? flowEnd(step) + (lines - 1) * LINE + LINE_FADE : flowEnd(step);
    return Math.max(noteEnd, graphemes(step.caption).length / CPS) + HOLD;
  }

  // 各場面の開始・終了秒
  function timeline(spec) {
    const n = spec.nodes.length;
    const introEnd = n ? (n - 1) * GAP + POP + DRAW : 0;
    let t = introEnd;
    const steps = spec.steps.map((step) => {
      const span = { start: t, end: t + stepDur(step) };
      t = span.end;
      return span;
    });
    const outroDur = spec.outro?.dur ?? Math.max(OUTRO, graphemes(spec.outro?.caption).length / CPS + HOLD + FADE);
    const outro = { start: t, end: t + outroDur };
    return { introEnd, steps, outro, total: outro.end };
  }

  // -1 = ノードの登場、i = ステップ i、steps.length = 締め
  function sceneAt(tl, t) {
    if (t < tl.introEnd) return -1;
    const i = tl.steps.findIndex((s) => t < s.end);
    return i < 0 ? tl.steps.length : i;
  }

  const appearAt = (i, t) => ease((t - i * GAP) / POP);
  const drawAt = (ia, ib, t) => ease((t - (Math.max(ia, ib) * GAP + POP)) / DRAW);

  // ステップ開始から local 秒の札の位置。hop = 何番目の区間か、p = その区間の進み
  function tokenAt(step, local) {
    const n = step.flow?.length ?? 0;
    if (!n || local < 0) return null;
    const hop = hopOf(step);
    const i = Math.min(n - 1, Math.floor(local / hop));
    return { hop: i, p: local >= n * hop ? 1 : ease((local - i * hop) / hop) };
  }

  const typedAt = (text, local) => graphemes(text).slice(0, Math.max(0, Math.floor(local * CPS))).join('');
  const lineAt = (step, j, local) => ease((local - flowEnd(step) - j * LINE) / LINE_FADE);

  function nextStart(tl, t) {
    const next = [...tl.steps.map((s) => s.start), tl.outro.start].find((s) => s > t + 1e-6);
    return next ?? 0;
  }

  function prevStart(tl, t) {
    const starts = [0, ...tl.steps.map((s) => s.start), tl.outro.start].filter((s) => s <= t - BACK);
    return starts.length ? starts[starts.length - 1] : 0;
  }

  const fadeAt = (tl, t) => 1 - ease((t - (tl.total - FADE)) / FADE);

  // ---- ここから下は DOM に描く部分 ----

  const W = 1600;
  const H = 900;
  const PAD = 60;
  const NS = 'http://www.w3.org/2000/svg';

  function el(name, attrs, parent) {
    const e = document.createElementNS(NS, name);
    for (const [k, v] of Object.entries(attrs ?? {})) e.setAttribute(k, v);
    if (parent) parent.appendChild(e);
    return e;
  }

  // テキストが maxWidth に収まるよう、文字の大きさを下げる
  function fit(text, maxWidth) {
    const w = text.getComputedTextLength();
    if (w > maxWidth) text.setAttribute('font-size', (parseFloat(text.getAttribute('font-size')) * maxWidth) / w);
  }

  function layout(spec) {
    const [cols, rows] = spec.grid ?? [3, 2];
    const cw = (W - 2 * PAD) / cols;
    const ch = (H - 2 * PAD) / rows;
    return new Map(
      spec.nodes.map((n) => {
        const w = n.w ?? Math.min(420, cw - 50);
        const h = n.sub ? 136 : 100;
        const cx = PAD + (n.col + 0.5) * cw;
        const cy = PAD + (n.row + 0.5) * ch;
        return [n.id, { w, h, cx, cy, x: cx - w / 2, y: cy - h / 2 }];
      }),
    );
  }

  // 同じ行なら向かい合う辺を直線で、違う行なら上下の辺を S 字で結ぶ
  function edgePath(a, b) {
    if (Math.abs(a.cy - b.cy) < 1) {
      const dir = Math.sign(b.cx - a.cx);
      return `M ${a.cx + (dir * a.w) / 2} ${a.cy} L ${b.cx - (dir * b.w) / 2} ${b.cy}`;
    }
    const dir = Math.sign(b.cy - a.cy);
    const y1 = a.cy + (dir * a.h) / 2;
    const y2 = b.cy - (dir * b.h) / 2;
    const my = (y1 + y2) / 2;
    return `M ${a.cx} ${y1} C ${a.cx} ${my}, ${b.cx} ${my}, ${b.cx} ${y2}`;
  }

  function mount(svg, spec) {
    const tl = timeline(spec);
    const boxes = layout(spec);
    const index = new Map(spec.nodes.map((n, i) => [n.id, i]));
    const colorOf = (id) => spec.nodes[index.get(id)]?.color ?? 'var(--accent)';
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.replaceChildren();
    const scene = el('g', {}, svg);
    const edgeLayer = el('g', {}, scene);
    const nodeLayer = el('g', {}, scene);
    const fxLayer = el('g', {}, scene);

    const edges = spec.edges.map((e) => {
      const path = el('path', { d: edgePath(boxes.get(e.from), boxes.get(e.to)), class: 'edge' }, edgeLayer);
      const dot = el('circle', { r: 9, class: 'dot' }, fxLayer);
      dot.style.fill = colorOf(e.from);
      return { ...e, path, dot, len: path.getTotalLength(), ia: index.get(e.from), ib: index.get(e.to) };
    });
    const findEdge = (from, to) => {
      const fwd = edges.find((e) => e.from === from && e.to === to);
      if (fwd) return { edge: fwd, reverse: false };
      const back = edges.find((e) => e.from === to && e.to === from);
      if (back) return { edge: back, reverse: true };
      console.warn(`edge not found: ${from} → ${to}`);
      return null;
    };
    const pointOn = (route, p) => route.edge.path.getPointAtLength(route.edge.len * (route.reverse ? 1 - p : p));

    const nodes = spec.nodes.map((n) => {
      const b = boxes.get(n.id);
      const g = el('g', {}, nodeLayer);
      const pulse = el('rect', { x: b.x, y: b.y, width: b.w, height: b.h, rx: 16, class: 'pulse' }, g);
      pulse.style.stroke = n.color ?? 'var(--accent)';
      const card = el('rect', { x: b.x, y: b.y, width: b.w, height: b.h, rx: 16, class: 'card' }, g);
      card.style.stroke = n.color ?? 'var(--accent)';
      const label = el('text', { x: b.cx, y: n.sub ? b.cy - 8 : b.cy + 16, 'font-size': 48, class: 'label' }, g);
      label.textContent = n.label;
      fit(label, b.w - 32);
      if (n.sub) {
        const sub = el('text', { x: b.cx, y: b.cy + 42, 'font-size': 30, class: 'sub' }, g);
        sub.textContent = n.sub;
        fit(sub, b.w - 32);
      }
      return { g, pulse, b };
    });

    const token = el('g', { class: 'token' }, fxLayer);
    const tokenDot = el('circle', { r: 12 }, token);
    const tokenPill = el('rect', { height: 54, rx: 27 }, token);
    const tokenText = el('text', { 'font-size': 32, class: 'token-text' }, token);

    const notes = spec.steps.map((step) => {
      if (!step.note) return null;
      const b = boxes.get(step.note.node);
      const g = el('g', { class: 'note' }, fxLayer);
      const rect = el('rect', { rx: 14 }, g);
      rect.style.stroke = colorOf(step.note.node);
      const lines = step.note.lines.map((line, j) => {
        const t = el('text', { 'font-size': 34, x: 0, y: 22 + 34 + j * 50, class: 'note-line' }, g);
        t.textContent = line;
        return t;
      });
      const w = Math.min(W - 40, Math.max(...lines.map((t) => t.getComputedTextLength())) + 48);
      const h = lines.length * 50 + 34;
      const side = step.note.side ?? (b.cy < H / 2 ? 'below' : 'above');
      const x = Math.min(W - 20 - w, Math.max(20, b.cx - w / 2));
      const y = side === 'below' ? b.y + b.h + 24 : b.y - 24 - h;
      rect.setAttribute('width', w);
      rect.setAttribute('height', h);
      lines.forEach((t) => t.setAttribute('x', 24));
      g.setAttribute('transform', `translate(${x} ${y})`);
      return { g, lines };
    });

    function render(t) {
      const scn = sceneAt(tl, t);
      const step = spec.steps[scn];
      const local = step ? t - tl.steps[scn].start : 0;
      const focus = step ? new Set(step.focus ?? (step.flow ?? []).flat()) : null;

      scene.setAttribute('opacity', fadeAt(tl, t));
      nodes.forEach((n, i) => {
        const a = appearAt(i, t);
        const s = 0.85 + 0.15 * a;
        n.g.setAttribute('opacity', a * (focus && focus.size && !focus.has(spec.nodes[i].id) ? 0.3 : 1));
        n.g.setAttribute('transform', `translate(${n.b.cx} ${n.b.cy}) scale(${s}) translate(${-n.b.cx} ${-n.b.cy})`);
        n.pulse.setAttribute('opacity', 0);
      });

      edges.forEach((e, i) => {
        const p = drawAt(e.ia, e.ib, t);
        const on = !focus || !focus.size || (focus.has(e.from) && focus.has(e.to));
        if (e.dashed) {
          e.path.setAttribute('stroke-dasharray', '14 12');
          e.path.setAttribute('stroke-dashoffset', -t * 30);
          e.path.setAttribute('opacity', p * (on ? 1 : 0.3));
        } else {
          e.path.setAttribute('stroke-dasharray', e.len);
          e.path.setAttribute('stroke-dashoffset', e.len * (1 - p));
          e.path.setAttribute('opacity', on ? 1 : 0.3);
        }
        // 締めでは全部の線に粒を流して、全体が回っている絵にする
        if (scn === spec.steps.length) {
          const q = ((t - tl.outro.start) / HOP + i * 0.17) % 1;
          const pt = e.path.getPointAtLength(e.len * q);
          e.dot.setAttribute('cx', pt.x);
          e.dot.setAttribute('cy', pt.y);
          e.dot.setAttribute('opacity', 1);
        } else {
          e.dot.setAttribute('opacity', 0);
        }
      });

      token.setAttribute('opacity', 0);
      const at = step && tokenAt(step, local);
      if (at) {
        const [from, to] = step.flow[at.hop];
        const route = findEdge(from, to);
        if (route) {
          const pt = pointOn(route, at.p);
          const settle = clamp01((local - flowEnd(step)) / 0.4);
          token.setAttribute('opacity', 1 - settle);
          token.setAttribute('transform', `translate(${pt.x} ${pt.y})`);
          tokenDot.style.fill = colorOf(from);
          const label = step.token ?? '';
          tokenText.textContent = label;
          // 札の名前は区間の途中だけ出し、両端でノードの文字に重ならないようにする
          const mid = label ? clamp01(Math.min(at.p, 1 - at.p) / 0.2) : 0;
          tokenPill.setAttribute('opacity', mid);
          tokenText.setAttribute('opacity', mid);
          if (label) {
            const tw = tokenText.getComputedTextLength() + 36;
            tokenPill.setAttribute('x', -tw / 2);
            tokenPill.setAttribute('y', -84);
            tokenPill.setAttribute('width', tw);
            tokenPill.style.stroke = colorOf(from);
            tokenText.setAttribute('x', 0);
            tokenText.setAttribute('y', -46);
          }
        }
        // 札が着いた相手のノードを、波紋で反応させる
        step.flow.forEach(([, to], k) => {
          const since = local - (k + 1) * hopOf(step);
          const n = nodes[index.get(to)];
          if (n && since >= 0 && since < 0.6) {
            const r = since / 0.6;
            n.pulse.setAttribute('opacity', 0.7 * (1 - r));
            n.pulse.setAttribute('transform', `translate(${n.b.cx} ${n.b.cy}) scale(${1 + 0.18 * r}) translate(${-n.b.cx} ${-n.b.cy})`);
          }
        });
      }

      notes.forEach((note, i) => {
        if (!note) return;
        if (i !== scn) {
          note.g.setAttribute('opacity', 0);
          return;
        }
        const out = clamp01((tl.steps[i].end - t) / 0.3);
        note.g.setAttribute('opacity', lineAt(step, 0, local) * out);
        note.lines.forEach((line, j) => line.setAttribute('opacity', lineAt(step, j, local)));
      });

      if (step) {
        return { kicker: `${String(scn + 1).padStart(2, '0')}  ${step.kicker ?? ''}`, text: typedAt(step.caption, local) };
      }
      if (scn === spec.steps.length && spec.outro) {
        return { kicker: spec.outro.kicker ?? '', text: typedAt(spec.outro.caption, t - tl.outro.start) };
      }
      return { kicker: '', text: '' };
    }

    return { render, tl };
  }

  // 小窓の再生操作。ボタン、シークバー、Space と ←/→、?t=秒 で止めて開く
  function play(figure, spec) {
    const svg = figure.querySelector('svg');
    const kicker = figure.querySelector('.kicker');
    const caption = figure.querySelector('.text');
    const toggle = figure.querySelector('.toggle');
    const seek = figure.querySelector('.seek');
    const time = figure.querySelector('.time');
    const { render, tl } = mount(svg, spec);
    const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
    seek.max = tl.total;

    let t = 0;
    let playing = false;
    let last = 0;

    function draw() {
      const c = render(t);
      kicker.textContent = c.kicker;
      caption.textContent = c.text;
      figure.style.setProperty('--fade', fadeAt(tl, t));
      seek.value = t;
      time.textContent = `${fmt(t)} / ${fmt(tl.total)}`;
    }

    function frame(now) {
      if (!playing) return;
      t = (t + Math.min(0.1, (now - last) / 1000)) % tl.total;
      last = now;
      draw();
      requestAnimationFrame(frame);
    }

    function setPlaying(on) {
      playing = on;
      figure.dataset.state = on ? 'playing' : 'paused';
      toggle.setAttribute('aria-label', on ? '一時停止' : '再生');
      if (on) {
        last = performance.now();
        requestAnimationFrame(frame);
      }
    }

    function jump(to) {
      t = to;
      draw();
    }

    toggle.addEventListener('click', () => setPlaying(!playing));
    svg.addEventListener('click', () => setPlaying(!playing));
    figure.querySelector('.prev').addEventListener('click', () => jump(prevStart(tl, t)));
    figure.querySelector('.next').addEventListener('click', () => jump(nextStart(tl, t)));
    const full = figure.querySelector('.full');
    full.hidden = !document.fullscreenEnabled;
    full.addEventListener('click', () => (document.fullscreenElement ? document.exitFullscreen() : figure.requestFullscreen()));
    document.addEventListener('fullscreenchange', () =>
      full.setAttribute('aria-label', document.fullscreenElement ? '全画面を終える' : '全画面'));
    seek.addEventListener('input', () => jump(Number(seek.value)));
    document.addEventListener('keydown', (e) => {
      if (e.target.closest('button, input, textarea, select, a')) return;
      if (e.key === ' ') {
        e.preventDefault();
        setPlaying(!playing);
      } else if (e.key === 'ArrowLeft') {
        jump(prevStart(tl, t));
      } else if (e.key === 'ArrowRight') {
        jump(nextStart(tl, t));
      }
    });

    const at = Number.parseFloat(new URLSearchParams(location.search).get('t'));
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
    // ?t= はその時刻で止める。動きを減らす設定では、全体が出そろった絵で止める
    jump(Number.isFinite(at) ? Math.min(at, tl.total) : still ? tl.introEnd : 0);
    setPlaying(!Number.isFinite(at) && !still);
  }

  const api = { timeline, sceneAt, appearAt, drawAt, tokenAt, typedAt, lineAt, nextStart, prevStart, fadeAt, mount, play };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ARCH = api;

  if (typeof document !== 'undefined' && root.SPEC) {
    document.title = root.SPEC.title ?? document.title;
    document.querySelector('h1').textContent = root.SPEC.title ?? '';
    const subtitle = document.querySelector('.subtitle');
    subtitle.textContent = root.SPEC.subtitle ?? '';
    subtitle.hidden = !root.SPEC.subtitle;
    play(document.querySelector('.player'), root.SPEC);
  }
})(typeof window !== 'undefined' ? window : globalThis);
