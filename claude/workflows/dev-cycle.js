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
    status: {
      type: 'string',
      enum: ['proceed', 'reject', 'clarify'],
      description:
        'proceed=要望が妥当で解釈に迷いがない / reject=プロダクトを汚す・頓珍漢 / clarify=曖昧・解釈が割れる・具体例と説明が矛盾しており聞き返す必要がある。少しでも曖昧さが残るなら proceed を選ばず clarify にする',
    },
    team: {
      type: 'string',
      enum: ['frontend', 'backend', 'both'],
      description: '変更が必要なチーム。frontend=フロントのみ、backend=バックのみ、both=両方（バックエンド先行）',
    },
    plan: {
      type: 'string',
      description: 'status=proceed 時、dev が迷わず実装できる具体的な実装方針・指示',
    },
    conditions: {
      type: 'string',
      description: 'team が frontend または both の時、UI上の達成条件を箇条書きで明記する。ブラウザで検証可能な具体的な形で書くこと（例: 「・.action ボタンの computed width がコンテナ幅と一致すること」「・DOM上で .archive ボタンが .danger ボタンの直前にあること」）',
    },
    reason: {
      type: 'string',
      description: 'status=reject 時の却下理由',
    },
    alternative: {
      type: 'string',
      description: 'status=reject 時、目的の推測と代案',
    },
    ambiguities: {
      type: 'string',
      description:
        'status=clarify 時、どこがどう曖昧か。特に「具体例（ASCII図/サンプル）と散文の説明が矛盾している」場合は矛盾する2点を引用して示す',
    },
    questions: {
      type: 'string',
      description:
        'status=clarify 時、ユーザーへの確認質問（箇条書き）。各質問にリーダー自身の推奨解釈とその根拠を添え、Yes/No か選択で即答できる形にする',
    },
  },
  required: ['status'],
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
- status=reject: プロダクトを汚す/一貫性を壊す/頓珍漢な要望。reason と代案(alternative)を示す。
- status=clarify: 要望が曖昧/解釈が割れる/具体例(ASCII図・サンプル)と散文の説明が矛盾している。
    勝手に一つの解釈に倒して進めてはならない。ambiguities に曖昧な箇所(矛盾点は両方引用)を分析し、
    questions にユーザーへの確認質問(各質問にあなたの推奨解釈と根拠を添え、Yes/No か選択で即答できる形)を書く。
    推測で突き進むより1回聞き返す方が常に安い。少しでも曖昧さが残るなら proceed を選ばず clarify にせよ。
- status=proceed: 要望が妥当で解釈に迷いがない。以下を決める:
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

if (lead.status === 'reject') {
  log('リーダー却下: ' + (lead.reason || ''))
  return { approved: false, rejected: true, reason: lead.reason, alternative: lead.alternative }
}

if (lead.status === 'clarify') {
  log('リーダー聞き返し: 仕様が曖昧なため確認が必要')
  return {
    approved: false,
    needsClarification: true,
    ambiguities: lead.ambiguities,
    questions: lead.questions,
  }
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
