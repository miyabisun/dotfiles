export const meta = {
  name: 'simplify-cycle',
  description: 'simplify(整理) → rev(検証) を承認が出るまで反復する。実装(dev)はしない。コミット前のリファクタに使う。args.task に対象を渡す。',
  whenToUse: 'コミット前など、実装は足さずに既存の変更コードを整理(simplify)して仕上げたいとき。',
  phases: [{ title: '整理' }, { title: '検証' }],
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

const task =
  typeof args === 'string' ? args : (args && args.task) || '直近の変更コード全体'

const MAX_ROUNDS = 5
let feedback = ''
let outcome = null

for (let round = 1; round <= MAX_ROUNDS; round++) {
  // ① 整理（simplify）。反復時は前回検証の指摘を渡す。
  await agent(
    `変更コードを simplify（機能保持のリファクタリング）せよ。\n対象:\n${task}\n\n${
      feedback ? `前回検証の指摘（simplify 起因のものは修正すること）:\n${feedback}` : ''
    }`,
    { agentType: 'simplify', phase: '整理', label: `simplify #${round}` },
  )

  // ② 検証（rev）。simplify による退行に特に注意。
  const r = await agent(
    `simplify 後のコードをレビューし承認可否を判定せよ。simplify による退行(機能破壊/ビルド失敗)に特に注意。\n対象:\n${task}`,
    { agentType: 'rev', phase: '検証', schema: REVIEW_SCHEMA, label: `rev #${round}` },
  )
  if (!r.approved) {
    feedback = r.issues.join('\n')
    log(`round ${round}: 不承認 → 再 simplify`)
    continue
  }

  outcome = { approved: true, rounds: round, summary: r.summary }
  log(`round ${round}: 承認・完了`)
  break
}

return outcome || { approved: false, rounds: MAX_ROUNDS, note: `${MAX_ROUNDS} ラウンドで未承認。手動確認が必要。` }
