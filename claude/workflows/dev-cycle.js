export const meta = {
  name: 'dev-cycle',
  description: 'リーダーが達成条件を定義しフロント/バックチームに振り分ける。フロント変更はUIチェッカー（Chromium）を通過するまで完了しない。',
  whenToUse: 'コードを実装し、レビューと simplify を経て「完成」状態まで自動で仕上げたいとき。',
  phases: [
    { title: '方針' },
    { title: 'バックエンド' },
    { title: 'フロントエンド' },
  ],
}

// リーダーが返す構造化判定。
const LEADER_SCHEMA = {
  type: 'object',
  properties: {
    proceed: {
      type: 'boolean',
      description: '要望が妥当なら true。プロダクトを汚す/頓珍漢なら false',
    },
    team: {
      type: 'string',
      enum: ['frontend', 'backend', 'both'],
      description: '変更が必要なチーム。frontend=フロントのみ、backend=バックのみ、both=両方（バックエンド先行）',
    },
    plan: {
      type: 'string',
      description: 'proceed=true 時、dev が迷わず実装できる具体的な実装方針・指示',
    },
    conditions: {
      type: 'string',
      description: 'team が frontend または both の時、UI上の達成条件を箇条書きで明記する。ブラウザで検証可能な具体的な形で書くこと（例: 「・.action ボタンの computed width がコンテナ幅と一致すること」「・DOM上で .archive ボタンが .danger ボタンの直前にあること」）',
    },
    reason: {
      type: 'string',
      description: 'proceed=false 時の却下理由',
    },
    alternative: {
      type: 'string',
      description: 'proceed=false 時、目的の推測と代案',
    },
  },
  required: ['proceed'],
}

// 依頼内容（文字列 or { task } の両方を受ける）。
const task =
  typeof args === 'string' ? args : (args && args.task) || '(タスクが指定されていません)'

// ⓪ リーダー: 達成条件定義 + チーム振り分け（却下権限あり）
const lead = await agent(
  `次の要望を評価し、達成条件とチーム振り分けを決めよ。

要望:
${task}

【判断基準】
- proceed=false: プロダクトを汚す/一貫性を壊す/頓珍漢な要望。reason と代案(alternative)を示す。
- proceed=true: 以下を決める:
  - team: 変更が必要なのは frontend のみか backend のみか both か
  - plan: dev が迷わず実装できる具体的な実装方針（対象ファイル・設計方針・守るべき既存パターン・テスト観点）
  - conditions: (team が frontend または both の時のみ) UI上の達成条件を箇条書きで明記する。
    Playwright のブラウザ検証で確認できる具体的な形で書くこと。
    例:
      ・.menu .action の computed width がコンテナ（.modal-content）の幅と一致すること
      ・DOM上で「アーカイブ」ボタンが「削除」ボタンの直前の兄弟要素であること
      ・モーダルの × ボタンが top/right ともに 10px 以内に位置すること`,
  { agentType: 'leader', phase: '方針', schema: LEADER_SCHEMA, label: 'leader' },
)

if (!lead.proceed) {
  log('リーダー却下: ' + (lead.reason || ''))
  return { approved: false, rejected: true, reason: lead.reason, alternative: lead.alternative }
}

const plan = lead.plan || ''
const conditions = lead.conditions || ''
const team = lead.team || 'backend'

// バックエンドが必要な場合（both のときはバックエンド先行）
if (team === 'backend' || team === 'both') {
  log('バックエンドチームに依頼')
  const backendResult = await workflow('backend-team', { task, plan })
  if (!backendResult?.approved) {
    return { approved: false, note: 'バックエンドチームが未承認', result: backendResult }
  }
}

// フロントエンドが必要な場合
if (team === 'frontend' || team === 'both') {
  log('フロントエンドチームに依頼')
  const frontendResult = await workflow('frontend-team', { task, plan, conditions })
  if (!frontendResult?.approved) {
    return { approved: false, note: 'フロントエンドチームが未承認', result: frontendResult }
  }
  return { approved: true, team, summary: frontendResult.summary }
}

return { approved: true, team }
