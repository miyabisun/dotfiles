// animated-arch-diagram の時間計算: どの時刻でも、場面・札・字幕・吹き出しが
// 決まった絵になり、各ステップの中身が終わる前に出そろうことを確かめる。
// 実行: node test/animated-arch-diagram.js
const test = require('node:test');
const assert = require('node:assert/strict');
const ARCH = require('../agent/common/skills/animated-arch-diagram/assets/arch.js');

const node = (id) => ({ id, label: id, col: 0, row: 0 });
const spec = (steps, extra = {}) => ({
  nodes: [node('a'), node('b'), node('c')],
  edges: [{ from: 'a', to: 'b' }, { from: 'b', to: 'c' }],
  steps,
  ...extra,
});

test('場面はノードの登場 → ステップ → 締めの順に、すき間なく並ぶ', () => {
  const tl = ARCH.timeline(spec([{ caption: 'x', dur: 2 }, { caption: 'y', dur: 3 }], { outro: { caption: 'z', dur: 4 } }));
  assert.ok(tl.introEnd > 0);
  assert.deepEqual(tl.steps.map((s) => Math.round((s.end - s.start) * 1e9) / 1e9), [2, 3]);
  assert.equal(tl.steps[0].start, tl.introEnd);
  assert.equal(tl.steps[1].start, tl.steps[0].end);
  assert.equal(tl.outro.start, tl.steps[1].end);
  assert.equal(tl.total, tl.outro.start + 4);
});

test('ノードが多いほど登場の場面は長い', () => {
  const few = ARCH.timeline(spec([]));
  const many = ARCH.timeline({ ...spec([]), nodes: [node('a'), node('b'), node('c'), node('d'), node('e')] });
  assert.ok(many.introEnd > few.introEnd);
});

test('時刻から、いまの場面が分かる', () => {
  const tl = ARCH.timeline(spec([{ caption: 'x', dur: 2 }, { caption: 'y', dur: 2 }]));
  assert.equal(ARCH.sceneAt(tl, 0), -1);
  assert.equal(ARCH.sceneAt(tl, tl.steps[0].start), 0);
  assert.equal(ARCH.sceneAt(tl, tl.steps[1].start + 1), 1);
  assert.equal(ARCH.sceneAt(tl, tl.outro.start + 0.1), 2);
});

test('ノードは並び順に現れ、線は両端が出そろってから引かれる', () => {
  assert.equal(ARCH.appearAt(0, 0), 0);
  const t = 0.3;
  assert.ok(ARCH.appearAt(0, t) > ARCH.appearAt(1, t));
  assert.equal(ARCH.appearAt(2, 10), 1);
  // a(0)–c(2) の線は、c が出きるまで引き始めない
  let t2 = 0;
  while (ARCH.appearAt(2, t2) < 1) t2 += 0.01;
  assert.equal(ARCH.drawAt(0, 2, t2 - 0.02), 0);
  assert.ok(ARCH.drawAt(0, 2, t2 + 0.2) > 0);
  assert.equal(ARCH.drawAt(0, 2, t2 + 5), 1);
});

test('札は区間を順に進み、流れ終わると最後の区間の終点に留まる', () => {
  const step = { flow: [['a', 'b'], ['b', 'c']], hop: 1 };
  assert.equal(ARCH.tokenAt({ caption: 'x' }, 0.5), null);
  const first = ARCH.tokenAt(step, 0.5);
  assert.equal(first.hop, 0);
  assert.ok(first.p > 0 && first.p < 1);
  assert.equal(ARCH.tokenAt(step, 1.5).hop, 1);
  assert.deepEqual(ARCH.tokenAt(step, 5), { hop: 1, p: 1 });
});

test('字幕は時間とともに 1 文字ずつ出て、絵文字や結合文字も割らない', () => {
  assert.equal(ARCH.typedAt('検索します', -1), '');
  const mid = ARCH.typedAt('検索します', 0.2);
  assert.ok(mid.length > 0 && mid.length < 5);
  assert.ok('検索します'.startsWith(mid));
  assert.equal(ARCH.typedAt('検索します', 60), '検索します');
  for (let t = 0; t < 2; t += 0.05) {
    const s = ARCH.typedAt('📚本を探す', t);
    assert.ok(s === '' || '📚本を探す'.startsWith(s));
    assert.notEqual(s, '\ud83d');
  }
});

test('既定の長さのステップは、終わる 1 秒前までに札・吹き出し・字幕が出そろう', () => {
  const step = {
    caption: 'クエリを 9 語に区切って、名詞だけを検索に使う',
    flow: [['a', 'b'], ['b', 'c']],
    hop: 0.9,
    note: { node: 'c', lines: ['猫 / が / 出て / くる', '小説 / を / 読み / たい', '名詞: 猫, 小説', '10 冊に点数を付ける'] },
  };
  const [s] = ARCH.timeline(spec([step])).steps;
  const local = s.end - s.start - 1;
  assert.deepEqual(ARCH.tokenAt(step, local), { hop: 1, p: 1 });
  step.note.lines.forEach((_, j) => assert.equal(ARCH.lineAt(step, j, local), 1));
  assert.equal(ARCH.typedAt(step.caption, local), step.caption);
});

test('吹き出しの行は、札が着いてから上から順に出る', () => {
  const step = { flow: [['a', 'b']], hop: 1, note: { node: 'b', lines: ['1', '2'] } };
  assert.equal(ARCH.lineAt(step, 0, 0.5), 0);
  assert.ok(ARCH.lineAt(step, 0, 1.2) > ARCH.lineAt(step, 1, 1.2));
});

test('前後のステップへの移動先', () => {
  const tl = ARCH.timeline(spec([{ caption: 'x', dur: 2 }, { caption: 'y', dur: 2 }]));
  const [s0, s1] = tl.steps;
  assert.equal(ARCH.nextStart(tl, 0), s0.start);
  assert.equal(ARCH.nextStart(tl, s0.start + 1), s1.start);
  assert.equal(ARCH.nextStart(tl, s1.start + 1), tl.outro.start);
  assert.equal(ARCH.nextStart(tl, tl.outro.start + 1), 0);
  assert.equal(ARCH.prevStart(tl, s1.start + 1), s1.start);
  // 頭の直後で戻ると、1 つ前のステップへ行く
  assert.equal(ARCH.prevStart(tl, s1.start + 0.2), s0.start);
  assert.equal(ARCH.prevStart(tl, 0.1), 0);
});

test('既定の長さの締めは、字幕が出そろって 1 秒たつまで消え始めない', () => {
  const outro = { caption: '消した secret は、次の load で手元からも消える' };
  const tl = ARCH.timeline(spec([{ caption: 'x', dur: 2 }], { outro }));
  let typed = tl.outro.start;
  while (ARCH.typedAt(outro.caption, typed - tl.outro.start) !== outro.caption) typed += 0.01;
  assert.equal(ARCH.fadeAt(tl, typed + 1), 1);
});

test('最後は消えて終わり、頭に戻ってもつなぎ目が出ない', () => {
  const tl = ARCH.timeline(spec([{ caption: 'x', dur: 2 }]));
  assert.equal(ARCH.fadeAt(tl, tl.outro.start), 1);
  assert.ok(ARCH.fadeAt(tl, tl.total - 0.01) < 0.05);
  assert.equal(ARCH.appearAt(0, 0), 0);
});
