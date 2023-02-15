syntax on

"=== Vim全体 ===
"バックアップファイル不要
set nobackup
set noswapfile
set noundofile
"ビープ音off
set vb t_vb=
"高速ターミナル接続
set ttyfast
"バッファ編集中にその他ファイルを開けるようにする
set hidden
"ステータスラインを常に表示
set laststatus=2
"外部変更時の自動読み込み
set autoread
"背景に暗い色を利用する
set background=dark

"=== エディタ ===
"行番号表示
set number
"カーソル位置表示
set ruler
"自動インデント
set smartindent
"バックスペースで何でも消す
set backspace=indent,eol,start
"対応する括弧を表示
set showmatch

"=== 検索 ===
"インクリメントサーチ
set incsearch
"ハイライトサーチ
set hlsearch
"大文字小文字を区別しない
set ignorecase
"大文字が入っている時のみ大文字小文字を区別
set smartcase

"=== マルチバイト文字 ===
"記号が崩れる問題を解消
set ambiwidth=double

"=== その他 ===
"diffを縦分割にする
set diffopt+=vertical
