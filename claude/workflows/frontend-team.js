export const meta = {
  name: 'frontend-team',
  description: 'フロントエンド実装チーム。dev→UIチェック→rev(一発網羅)→debugger/inspectorの修正ループ→simplify→退行確認→sec。不承認時にチーム全体を再実行する差し戻しはしない。',
  whenToUse: 'dev-cycle のリーダーがフロントエンド変更と判断したときに呼ばれる。直接呼ぶことは想定していない。',
  phases: [
    { title: '実装' },
    { title: 'UIチェック' },
    { title: 'レビュー' },
    { title: '修正' },
    { title: '整理' },
    { title: '退行確認' },
    { title: 'セキュリティ' },
  ],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    approved: { type: 'boolean', description: 'Critical/Warning が無くテスト/ビルドが緑なら true' },
    issues: { type: 'array', items: { type: 'string' }, description: '不承認時の具体的指摘(ファイル:箇所+直し方)' },
    summary: { type: 'string' },
  },
  required: ['approved', 'issues', 'summary'],
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    done: { type: 'array', items: { type: 'string' }, description: '修正完了した項目' },
    unresolved: { type: 'array', items: { type: 'string' }, description: '直せなかった項目と理由' },
    summary: { type: 'string' },
  },
  required: ['done', 'unresolved', 'summary'],
}

// args: { task, plan, brief, conditions }
// - task: 要望文
// - plan: リーダーの実装方針（dev と rev に渡す）
// - brief: デザイナーの design brief（dev と ui-checker に渡す）
// - conditions: リーダー+デザイナーのUI達成条件（ui-checker に渡す箇条書き）
const task = (args && args.task) || '(タスクが指定されていません)'
const plan = (args && args.plan) || ''
const brief = (args && args.brief) || ''
const conditions = (args && args.conditions) || '（UI達成条件の指定なし — ビルドとE2Eテストのグリーンのみ確認）'

// 修正ループ: debugger が修正リストどおりに直し、inspector がリストの消化だけを
// 検品する。dev からの作り直しはしない（リスト外の後出し指摘は契約上存在しない）。
// 戻り値: 未解決のまま残った項目（空配列 = 全消化）。
async function fixLoop(issues, phase, tag, maxRounds) {
  let list = (issues || []).filter(Boolean)
  for (let round = 1; round <= maxRounds && list.length > 0; round++) {
    log(`${tag} 修正ループ ${round}: ${list.length} 件`)
    await agent(
      `以下の修正リストを指示どおりに修正せよ。リスト外の変更は禁止。\n\n【修正リスト】\n${list.join('\n')}\n\n【タスク文脈（参考）】\n${task}`,
      { agentType: 'debugger', phase, schema: FIX_SCHEMA, label: `debugger ${tag}#${round}` },
    )
    const check = await agent(
      `以下の修正リストの各項目が指示どおり修正されたか検品せよ。リスト外の新規指摘はしない。\n\n【修正リスト】\n${list.join('\n')}`,
      { agentType: 'inspector', phase, schema: REVIEW_SCHEMA, label: `inspector ${tag}#${round}` },
    )
    if (check.approved) return []
    list = check.issues
  }
  return list
}

const unapproved = (note, issues) => ({ approved: false, note, issues })

// ① 実装（リーダーの plan とデザイナーの brief の両方に従う）
await agent(
  `タスク:\n${task}\n\n${plan ? `リーダーの実装方針（これに従うこと）:\n${plan}\n\n` : ''}${brief ? `デザイナーの design brief（使用トークン・対象コンポーネント・禁止事項。これに従うこと）:\n${brief}` : ''}`,
  { agentType: 'dev', phase: '実装', label: 'dev' },
)

// ② UIチェック（フル — Chromium でブラウザを起動して達成条件を実測）
const ui1 = await agent(
  `以下のUI達成条件をブラウザで検証せよ。\n\n【達成条件】\n${conditions}\n\n${brief ? `【デザイナーの design brief（達成条件の解釈に迷ったらこの意図を基準にする）】\n${brief}\n\n` : ''}【タスク概要】\n${task}`,
  { agentType: 'ui-checker', phase: 'UIチェック', schema: REVIEW_SCHEMA, label: 'ui-check' },
)

// ③ コードレビュー（一発網羅 — このフローで唯一のフルレビュー）
const r1 = await agent(
  `直近の実装をレビューし、承認可否を判定せよ。これがこの実装に対する唯一のフルレビューであり、issues はそのまま修正担当(debugger)の作業リストになる。ブロッキング指摘は全件を一括で挙げること。UIの見た目・配置は別担当が実測済みのためコードの論理・品質に集中すること。\nタスク:\n${task}${plan ? `\n\nリーダーの実装方針（実装がこの方針に沿っているかも確認する）:\n${plan}` : ''}`,
  { agentType: 'rev', phase: 'レビュー', schema: REVIEW_SCHEMA, label: 'rev' },
)

// ④ 修正ループ（UIチェックとレビューの指摘を合流して一括消化）
{
  const list = [...(ui1.approved ? [] : ui1.issues), ...(r1.approved ? [] : r1.issues)]
  const remaining = await fixLoop(list, '修正', 'main', 3)
  if (remaining.length > 0) return unapproved('修正ループ上限。未解決項目の手動確認が必要。', remaining)
}

// ④b UI差分再検証（UIチェックが落ちていた場合のみ、落ちた条件だけブラウザで再実測）
if (!ui1.approved) {
  let toVerify = ui1.issues
  for (let pass = 1; pass <= 2 && toVerify.length > 0; pass++) {
    const uiv = await agent(
      `前回のUIチェックで不合格だった以下の項目のみをブラウザで再検証せよ。フル検証は不要。\n\n【再検証項目】\n${toVerify.join('\n')}\n\n${brief ? `【デザイナーの design brief】\n${brief}` : ''}`,
      { agentType: 'ui-checker', phase: 'UIチェック', schema: REVIEW_SCHEMA, label: `ui-verify #${pass}` },
    )
    if (uiv.approved) {
      toVerify = []
      break
    }
    const remaining = await fixLoop(uiv.issues, '修正', `ui${pass}`, 2)
    if (remaining.length > 0) return unapproved('UI再検証の修正が収束せず。手動確認が必要。', remaining)
    toVerify = uiv.issues
  }
  if (toVerify.length > 0) return unapproved('UI再検証が上限内に収束せず。手動確認が必要。', toVerify)
}

// ⑤ 整理
await agent(
  `直近の実装を simplify（機能保持のリファクタリング）せよ。\nタスク:\n${task}`,
  { agentType: 'simplify', phase: '整理', label: 'simplify' },
)

// ⑥ 退行確認（simplify は壊しがち — E2E の緑 + simplify 観点の限定レビュー）
const ui2 = await agent(
  `軽量モード: プロジェクトの既存 E2E テストを実行し、simplify による退行が無い（全件グリーン）ことを確認せよ。テストコマンドは package.json から判断すること。Chromium によるフル検証は不要。`,
  { agentType: 'ui-checker', phase: '退行確認', schema: REVIEW_SCHEMA, label: 'ui-check2' },
)
const revd = await agent(
  `simplify（機能保持のリファクタリング）直後の状態を退行観点に限定してレビューせよ。直前にフルレビュー承認済みの実装があり、simplify は挙動を変えないはずである。テスト/ビルドを実行し、リファクタで壊れやすい箇所（削られた分岐・変わった依存・置き換えられたヘルパ）を中心に、挙動が変わっていないかだけを確認する。実装全体への新規指摘はしない。\nタスク:\n${task}`,
  { agentType: 'rev', phase: '退行確認', schema: REVIEW_SCHEMA, effort: 'medium', label: 'rev-diff' },
)
{
  const list = [...(ui2.approved ? [] : ui2.issues), ...(revd.approved ? [] : revd.issues)]
  const remaining = await fixLoop(list, '退行確認', 'post', 2)
  if (remaining.length > 0) return unapproved('simplify 退行の修正が収束せず。手動確認が必要。', remaining)
}

// ⑦ セキュリティ
const sec = await agent(
  `直近の実装をセキュリティ観点でレビューし承認可否を判定せよ。特に外部入力→XSS/インジェクション のシンクを追え。指摘は全件を一括で挙げること。\nタスク:\n${task}`,
  { agentType: 'sec', phase: 'セキュリティ', schema: REVIEW_SCHEMA, label: 'sec' },
)
if (!sec.approved) {
  const remaining = await fixLoop(sec.issues, 'セキュリティ', 'sec', 2)
  if (remaining.length > 0) return unapproved('セキュリティ指摘の修正が収束せず。手動確認が必要。', remaining)
}

log('承認・完了')
return { approved: true, summary: r1.summary }
