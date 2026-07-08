export const meta = {
  name: 'backend-team',
  description: 'バックエンド実装チーム。dev→rev(一発網羅)→debugger/inspectorの修正ループ→simplify→退行確認→sec。不承認時にチーム全体を再実行する差し戻しはしない。',
  whenToUse: 'dev-cycle のリーダーがバックエンド変更と判断したときに呼ばれる。直接呼ぶことは想定していない。',
  phases: [
    { title: '実装' },
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

// args: { task, plan } — task は要望文、plan はリーダーの実装方針
const task = (args && args.task) || '(タスクが指定されていません)'
const plan = (args && args.plan) || ''

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

// ① 実装
await agent(
  `タスク:\n${task}\n\n${plan ? `リーダーの実装方針（これに従うこと）:\n${plan}` : ''}`,
  { agentType: 'dev', phase: '実装', label: 'dev' },
)

// ② レビュー（一発網羅 — このフローで唯一のフルレビュー）
const r1 = await agent(
  `直近の実装をレビューし、承認可否を判定せよ。これがこの実装に対する唯一のフルレビューであり、issues はそのまま修正担当(debugger)の作業リストになる。ブロッキング指摘は全件を一括で挙げること。\nタスク:\n${task}${plan ? `\n\nリーダーの実装方針（実装がこの方針に沿っているかも確認する）:\n${plan}` : ''}`,
  { agentType: 'rev', phase: 'レビュー', schema: REVIEW_SCHEMA, label: 'rev' },
)

// ③ 修正ループ
if (!r1.approved) {
  const remaining = await fixLoop(r1.issues, '修正', 'main', 3)
  if (remaining.length > 0) return unapproved('修正ループ上限。未解決項目の手動確認が必要。', remaining)
}

// ④ 整理
await agent(
  `直近の実装を simplify（機能保持のリファクタリング）せよ。\nタスク:\n${task}`,
  { agentType: 'simplify', phase: '整理', label: 'simplify' },
)

// ⑤ 退行確認（simplify は壊しがち — simplify 観点の限定レビュー）
const revd = await agent(
  `simplify（機能保持のリファクタリング）直後の状態を退行観点に限定してレビューせよ。直前にフルレビュー承認済みの実装があり、simplify は挙動を変えないはずである。テストを実行し、リファクタで壊れやすい箇所（削られた分岐・変わった依存・置き換えられたヘルパ）を中心に、挙動が変わっていないかだけを確認する。実装全体への新規指摘はしない。\nタスク:\n${task}`,
  { agentType: 'rev', phase: '退行確認', schema: REVIEW_SCHEMA, effort: 'medium', label: 'rev-diff' },
)
if (!revd.approved) {
  const remaining = await fixLoop(revd.issues, '退行確認', 'post', 2)
  if (remaining.length > 0) return unapproved('simplify 退行の修正が収束せず。手動確認が必要。', remaining)
}

// ⑥ セキュリティ
const sec = await agent(
  `直近の実装をセキュリティ観点でレビューし承認可否を判定せよ。特に外部入力→URL/SQL/FS のシンクを追え。指摘は全件を一括で挙げること。\nタスク:\n${task}`,
  { agentType: 'sec', phase: 'セキュリティ', schema: REVIEW_SCHEMA, label: 'sec' },
)
if (!sec.approved) {
  const remaining = await fixLoop(sec.issues, 'セキュリティ', 'sec', 2)
  if (remaining.length > 0) return unapproved('セキュリティ指摘の修正が収束せず。手動確認が必要。', remaining)
}

log('承認・完了')
return { approved: true, summary: r1.summary }
