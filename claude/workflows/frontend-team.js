export const meta = {
  name: 'frontend-team',
  description: 'フロントエンド実装チーム。dev→UIチェック→rev→simplify→UIチェック(退行)→rev2→sec の順で承認が出るまで反復する。dev-cycle から呼ばれる。',
  whenToUse: 'dev-cycle のリーダーがフロントエンド変更と判断したときに呼ばれる。直接呼ぶことは想定していない。',
  phases: [
    { title: '実装' },
    { title: 'UIチェック' },
    { title: 'レビュー' },
    { title: '整理' },
    { title: 'UIチェック(退行確認)' },
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

// args: { task, plan, brief, conditions }
// - task: 要望文
// - plan: リーダーの実装方針（dev と rev に渡す）
// - brief: デザイナーの design brief（dev と ui-checker に渡す）
// - conditions: リーダー+デザイナーのUI達成条件（ui-checker に渡す箇条書き）
const task = (args && args.task) || '(タスクが指定されていません)'
const plan = (args && args.plan) || ''
const brief = (args && args.brief) || ''
const conditions = (args && args.conditions) || '（UI達成条件の指定なし — ビルドとE2Eテストのグリーンのみ確認）'

const MAX_ROUNDS = 6
let feedback = ''
let outcome = null

for (let round = 1; round <= MAX_ROUNDS; round++) {
  // ① 実装（リーダーの plan とデザイナーの brief の両方に従う）
  await agent(
    `タスク:\n${task}\n\n${plan ? `リーダーの実装方針（これに従うこと）:\n${plan}\n\n` : ''}${brief ? `デザイナーの design brief（使用トークン・対象コンポーネント・禁止事項。これに従うこと）:\n${brief}\n\n` : ''}${feedback ? `前回レビューの指摘（全て修正すること）:\n${feedback}` : ''}`,
    { agentType: 'dev', phase: '実装', label: `dev #${round}` },
  )

  // ② UIチェック（本格 — Chromium でブラウザを起動して達成条件を検証。
  //    デザイナーの brief を意図の文脈として渡す）
  const ui1 = await agent(
    `以下のUI達成条件をブラウザで検証せよ。\n\n【達成条件】\n${conditions}\n\n${brief ? `【デザイナーの design brief（達成条件の解釈に迷ったらこの意図を基準にする）】\n${brief}\n\n` : ''}【タスク概要】\n${task}`,
    { agentType: 'ui-checker', phase: 'UIチェック', schema: REVIEW_SCHEMA, label: `ui-check #${round}` },
  )
  if (!ui1.approved) {
    feedback = ui1.issues.join('\n')
    log(`round ${round}: UIチェック不承認 → 再実装`)
    continue
  }

  // ③ コードレビュー（論理・品質に特化。リーダーの plan を判断基準として渡す）
  const r1 = await agent(
    `直近の実装をレビューし、承認可否を判定せよ。UIの見た目・配置は別担当が確認済みのためコードの論理・品質に集中すること。\nタスク:\n${task}${plan ? `\n\nリーダーの実装方針（実装がこの方針に沿っているかも確認する）:\n${plan}` : ''}`,
    { agentType: 'rev', phase: 'レビュー', schema: REVIEW_SCHEMA, label: `rev #${round}` },
  )
  if (!r1.approved) {
    feedback = r1.issues.join('\n')
    log(`round ${round}: レビュー不承認 → 再実装`)
    continue
  }

  // ④ 整理
  await agent(
    `直近の実装を simplify（機能保持のリファクタリング）せよ。\nタスク:\n${task}`,
    { agentType: 'simplify', phase: '整理', label: `simplify #${round}` },
  )

  // ⑤ UIチェック（軽量 — simplify による退行確認のみ、フル検証は省略）
  const ui2 = await agent(
    `軽量モード: プロジェクトの既存 E2E テストを実行し、simplify による退行が無い（全件グリーン）ことを確認せよ。テストコマンドは package.json から判断すること。Chromium によるフル検証は不要。`,
    { agentType: 'ui-checker', phase: 'UIチェック(退行確認)', schema: REVIEW_SCHEMA, label: `ui-check2 #${round}` },
  )
  if (!ui2.approved) {
    feedback = ui2.issues.join('\n')
    log(`round ${round}: simplify 後UIチェック不承認 → 再実装`)
    continue
  }

  // ⑥ 再レビュー（リーダーの plan を判断基準として渡す）
  const r2 = await agent(
    `simplify 後の実装をレビューし、承認可否を判定せよ。simplify による退行(機能破壊/ビルド失敗)に特に注意。\nタスク:\n${task}${plan ? `\n\nリーダーの実装方針（実装がこの方針に沿っているかも確認する）:\n${plan}` : ''}`,
    { agentType: 'rev', phase: '再レビュー', schema: REVIEW_SCHEMA, label: `rev2 #${round}` },
  )
  if (!r2.approved) {
    feedback = r2.issues.join('\n')
    log(`round ${round}: simplify 後レビュー不承認 → 再実装`)
    continue
  }

  // ⑦ セキュリティ
  const sec = await agent(
    `直近の実装をセキュリティ観点でレビューし承認可否を判定せよ。特に外部入力→XSS/インジェクション のシンクを追え。\nタスク:\n${task}`,
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
