export const meta = {
  name: 'dev-cycle',
  description: '実装→レビュー→整理(simplify)→再レビュー を承認が出るまで自動反復する。args.task に依頼内容を渡す。',
  whenToUse: 'コードを実装し、レビューと simplify を経て「完成」状態まで自動で仕上げたいとき。',
  phases: [
    { title: '方針' },
    { title: '実装' },
    { title: 'レビュー' },
    { title: '整理' },
    { title: '再レビュー' },
    { title: 'セキュリティ' },
  ],
}

// rev が返す構造化判定。
const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    approved: { type: 'boolean', description: 'Critical/Warning が無くテスト/ビルドが緑なら true' },
    issues: { type: 'array', items: { type: 'string' }, description: '不承認時の具体的指摘(ファイル:箇所+直し方)' },
    summary: { type: 'string' },
  },
  required: ['approved', 'issues', 'summary'],
}

// 依頼内容（文字列 or { task } の両方を受ける）。
const task =
  typeof args === 'string' ? args : (args && args.task) || '(タスクが指定されていません)'

// リーダーの方針判断（却下権限あり）。
const LEADER_SCHEMA = {
  type: 'object',
  properties: {
    proceed: { type: 'boolean', description: '要望が妥当なら true。プロダクトを汚す/頓珍漢なら false' },
    plan: { type: 'string', description: 'proceed=true 時、dev 向けの具体的な実装方針・指示' },
    reason: { type: 'string', description: 'proceed=false 時の却下理由' },
    alternative: { type: 'string', description: 'proceed=false 時、目的の推測と代案' },
  },
  required: ['proceed'],
}

// ⓪ リーダー: コードベースを読み方針を決める。頓珍漢な依頼はここで却下し終了。
const lead = await agent(
  `次の要望を評価し、実装方針を決めよ。プロダクトを汚す/一貫性を壊す/頓珍漢な要望なら proceed=false で却下し、要望から目的を推測して代案(alternative)を示せ。妥当なら proceed=true とし、dev が迷わず実装できる具体的な方針を plan に書け。\n要望:\n${task}`,
  { agentType: 'leader', phase: '方針', schema: LEADER_SCHEMA, label: 'leader' },
)
if (!lead.proceed) {
  log('リーダー却下: ' + (lead.reason || ''))
  return { approved: false, rejected: true, reason: lead.reason, alternative: lead.alternative }
}
const plan = lead.plan || ''

const MAX_ROUNDS = 6
let feedback = ''
let outcome = null

for (let round = 1; round <= MAX_ROUNDS; round++) {
  // ① 実装（反復時は前回指摘を渡す）
  await agent(
    `タスク:\n${task}\n\n${plan ? `リーダーの実装方針（これに従うこと）:\n${plan}\n\n` : ''}${feedback ? `前回レビューの指摘（全て修正すること）:\n${feedback}` : ''}`,
    { agentType: 'dev', phase: '実装', label: `dev #${round}` },
  )

  // ② レビュー
  const r1 = await agent(
    `直近の実装をレビューし、承認可否を判定せよ。\nタスク:\n${task}`,
    { agentType: 'rev', phase: 'レビュー', schema: REVIEW_SCHEMA, label: `rev #${round}` },
  )
  if (!r1.approved) {
    feedback = r1.issues.join('\n')
    log(`round ${round}: レビュー不承認 → 再実装`)
    continue
  }

  // ③ 整理（simplify）— rev 承認後にのみ実行
  await agent(
    `直近の実装を simplify（機能保持のリファクタリング）せよ。\nタスク:\n${task}`,
    { agentType: 'simplify', phase: '整理', label: `simplify #${round}` },
  )

  // ④ 再レビュー（simplify が壊していないか確認）
  const r2 = await agent(
    `simplify 後の実装をレビューし、承認可否を判定せよ。simplify による退行(機能破壊/ビルド失敗)に特に注意。\nタスク:\n${task}`,
    { agentType: 'rev', phase: '再レビュー', schema: REVIEW_SCHEMA, label: `rev2 #${round}` },
  )
  if (!r2.approved) {
    feedback = r2.issues.join('\n')
    log(`round ${round}: simplify 後に不承認 → 再実装`)
    continue
  }

  // ⑤ セキュリティレビュー（SSRF/インジェクション/IDOR 等）
  const sec = await agent(
    `直近の実装をセキュリティ観点でレビューし承認可否を判定せよ。特に外部入力→URL/SQL/FS のシンクを追え。\nタスク:\n${task}`,
    { agentType: 'sec', phase: 'セキュリティ', schema: REVIEW_SCHEMA, label: `sec #${round}` },
  )
  if (!sec.approved) {
    feedback = sec.issues.join('\n')
    log(`round ${round}: セキュリティ不承認 → 再実装`)
    continue
  }

  outcome = { approved: true, rounds: round, summary: r2.summary }
  log(`round ${round}: 承認・完了`)
  break
}

return outcome || { approved: false, rounds: MAX_ROUNDS, note: `${MAX_ROUNDS} ラウンドで未承認。手動確認が必要。` }
