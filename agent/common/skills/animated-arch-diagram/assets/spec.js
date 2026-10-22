// 図の中身。書き換えるのはこのファイルだけ。書式は SKILL.md の「spec の書き方」
// 見本: dotfiles の bw-secret load が、Bitwarden の secret を環境変数にするまで
// window.SPECS に名前で登録する。index.html の data-spec の名前と合わせる
window.SPECS = window.SPECS || {};
window.SPECS.diagram = {
  title: 'bw-secret load の仕組み',
  subtitle: 'Bitwarden の secret を、シェルの環境変数にするまで',
  grid: [3, 2], // 列数, 行数 (col / row は 0 始まり、小数も可)

  // 並び順 = 登場順
  nodes: [
    { id: 'user', label: 'あなた', sub: 'bw-secret load', color: '#3b8fd9', col: 0, row: 0 },
    { id: 'cli', label: 'bw-secret', sub: 'bin/bw', color: '#d49a00', col: 1, row: 0 },
    { id: 'rbw', label: 'rbw', sub: 'agent + cache', color: '#a066d3', col: 2, row: 0 },
    { id: 'vault', label: 'Bitwarden', sub: 'CLI フォルダ', color: '#a066d3', col: 2, row: 1 },
    { id: 'file', label: '.secrets', sub: '~/.config', color: '#d49a00', col: 1, row: 1 },
    { id: 'shell', label: 'シェル', sub: 'bash / zsh', color: '#3b8fd9', col: 0, row: 1 },
  ],

  edges: [
    { from: 'user', to: 'cli' },
    { from: 'cli', to: 'rbw' },
    { from: 'rbw', to: 'vault', dashed: true }, // load のときだけ通る
    { from: 'cli', to: 'file' },
    { from: 'file', to: 'shell' },
  ],

  // 1 ステップ = 1 つの出来事。flow の区間を札 (token) が順に運ぶ
  steps: [
    { kicker: 'LOAD', caption: 'bw-secret load を実行する', flow: [['user', 'cli']], token: 'load' },
    {
      kicker: 'SYNC',
      caption: 'まず rbw sync で、手元のキャッシュを最新にする',
      flow: [['cli', 'rbw'], ['rbw', 'vault'], ['vault', 'rbw']],
      token: '同期',
      note: { node: 'rbw', lines: ['他のマシンで消した項目も', 'ここで手元から消える'] },
    },
    {
      kicker: 'LIST',
      caption: 'CLI フォルダの項目を、名前と値で受け取る',
      flow: [['rbw', 'cli']],
      token: '項目',
      note: { node: 'cli', lines: ['API_TOKEN', 'SERVICE_KEY'] },
    },
    {
      kicker: 'WRITE',
      caption: '1 行ずつ export にして、権限 600 で書き出す',
      flow: [['cli', 'file']],
      token: 'export',
      note: { node: 'file', side: 'above', lines: ["export API_TOKEN='…'", "export SERVICE_KEY='…'"] },
    },
    { kicker: 'SOURCE', caption: 'シェルが起動時に読み込む', flow: [['file', 'shell']], token: '環境変数' },
  ],

  outro: { kicker: 'DONE', caption: '消した secret は、次の load で手元からも消える' },
};
