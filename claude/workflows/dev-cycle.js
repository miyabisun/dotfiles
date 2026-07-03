export const meta = {
  name: 'dev-cycle',
  description: 'リーダーが達成条件を定義しフロント/バックチームに振り分ける。フロント変更はUIチェッカー（Chromium）を通過するまで完了しない。',
  whenToUse: 'コードを実装し、レビューと simplify を経て「完成」状態まで自動で仕上げたいとき。',
  phases: [
    { title: '方針' },
    { title: 'デザイン' },
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

// デザイナーが返す構造化判定。リーダーと同格の停止権限を持つ。
const DESIGNER_SCHEMA = {
  type: 'object',
  properties: {
    status: {
      type: 'string',
      enum: ['proceed', 'reject', 'clarify'],
      description:
        'proceed=デザイン的に成立する / reject=デザインシステムを壊す・UI表現として成立しない / clarify=デザイン的に解釈が割れる・使うテンプレートが判断できない。迷いが残るなら proceed を選ばない',
    },
    brief: {
      type: 'string',
      description:
        'status=proceed 時の design brief。使用トークン(色/タイポ/スペーシング/角丸)と根拠、対象コンポーネントと適用レシピ、このタスクでやってはいけないこと、を DESIGN.md の語彙で書く。dev と ui-checker がそのまま読む',
    },
    conditions: {
      type: 'string',
      description:
        'status=proceed 時、リーダーの達成条件に追記するデザイン達成条件（箇条書き）。ブラウザで機械的に検証可能な形で書くこと（例: 「.post-submit の computed background-color が var(--accent) の解決値と一致すること」）',
    },
    reason: { type: 'string', description: 'status=reject 時の却下理由' },
    alternative: {
      type: 'string',
      description: 'status=reject 時、目的の推測とデザイン的に成立する代案',
    },
    ambiguities: {
      type: 'string',
      description: 'status=clarify 時、デザイン的にどこがどう曖昧か',
    },
    questions: {
      type: 'string',
      description:
        'status=clarify 時、ユーザーへの確認質問（推奨案つき、Yes/No か選択で即答できる形）',
    },
  },
  required: ['status'],
}

// 依頼内容（文字列 or { task } の両方を受ける）。
const task =
  typeof args === 'string' ? args : (args && args.task) || '(タスクが指定されていません)'

// ⓪ リーダー: 達成条件定義 + チーム振り分け（却下・聞き返し権限あり）
// 判断基準と出力要件は leader の役割定義（agents/leader.md）と schema が持つ。ここは入力のみ渡す。
const lead = await agent(
  `次の要望を評価し、実装方針とチーム振り分け（または reject / clarify）を構造化出力で返せ。

要望:
${task}`,
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
let conditions = lead.conditions || ''
const team = lead.team || 'backend'

// ① デザイナー: フロントエンド変更を含む場合のみ。リーダーと同格の停止権限を持ち、
// UI表現が困難・デザインシステムと矛盾する要望は実装前にサイクルを止める。
// proceed 時は design brief（dev/ui-checker に配線）とデザイン達成条件（conditions に追記）を作る。
let brief = ''
if (team === 'frontend' || team === 'both') {
  // 探索手順・判断基準・single writer 規則は designer の役割定義（agents/designer.md）が持つ。
  const design = await agent(
    `次のタスクとリーダーの実装方針をデザインシステムに照らして評価し、brief とデザイン達成条件（または reject / clarify）を構造化出力で返せ。

タスク:
${task}

リーダーの実装方針:
${plan}

リーダーのUI達成条件:
${conditions}`,
    { agentType: 'designer', phase: 'デザイン', schema: DESIGNER_SCHEMA, label: 'designer' },
  )

  if (design.status === 'reject') {
    log('デザイナー却下: ' + (design.reason || ''))
    return {
      approved: false,
      rejected: true,
      rejectedBy: 'designer',
      reason: design.reason,
      alternative: design.alternative,
    }
  }

  if (design.status === 'clarify') {
    log('デザイナー聞き返し: デザイン仕様が曖昧なため確認が必要')
    return {
      approved: false,
      needsClarification: true,
      clarifyFrom: 'designer',
      ambiguities: design.ambiguities,
      questions: design.questions,
    }
  }

  brief = design.brief || ''
  if (design.conditions) {
    conditions = conditions
      ? `${conditions}\n\n【デザイン達成条件（designer）】\n${design.conditions}`
      : design.conditions
  }
}

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
  const frontendResult = await workflow('frontend-team', { task, plan, brief, conditions })
  if (!frontendResult?.approved) {
    return { approved: false, note: 'フロントエンドチームが未承認', result: frontendResult }
  }
  return { approved: true, team, summary: frontendResult.summary }
}

return { approved: true, team }
