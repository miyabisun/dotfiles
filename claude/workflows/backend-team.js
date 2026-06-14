export const meta = {
  name: 'backend-team',
  description: 'バックエンド実装チーム。dev→rev→simplify→rev2→sec の順で承認が出るまで反復する。dev-cycle から呼ばれる。',
  whenToUse: 'dev-cycle のリーダーがバックエンド変更と判断したときに呼ばれる。直接呼ぶことは想定していない。',
  phases: [
    { title: '実装' },
    { title: 'レビュー' },
    { title: '整理' },
    { title: '再レビュー' },
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

// args: { task, plan } — task は要望文、plan はリーダーの実装方針
const task = (args && args.task) || '(タスクが指定されていません)'
const plan = (args && args.plan) || ''

const MAX_ROUNDS = 6
let feedback = ''
let outcome = null

for (let round = 1; round <= MAX_ROUNDS; round++) {
  // ① 実装
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

  // ③ 整理
  await agent(
    `直近の実装を simplify（機能保持のリファクタリング）せよ。\nタスク:\n${task}`,
    { agentType: 'simplify', phase: '整理', label: `simplify #${round}` },
  )

  // ④ 再レビュー
  const r2 = await agent(
    `simplify 後の実装をレビューし、承認可否を判定せよ。simplify による退行(機能破壊/ビルド失敗)に特に注意。\nタスク:\n${task}`,
    { agentType: 'rev', phase: '再レビュー', schema: REVIEW_SCHEMA, label: `rev2 #${round}` },
  )
  if (!r2.approved) {
    feedback = r2.issues.join('\n')
    log(`round ${round}: simplify 後レビュー不承認 → 再実装`)
    continue
  }

  // ⑤ セキュリティ
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
