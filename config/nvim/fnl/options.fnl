(let [options
      {;; === Common ===
       :shell "fish"
       :helplang "ja,en"

       ;; === no backup ===
       :backup false
       :writebackup false
       :undofile false

       ;; === Editor ===
       :number true
       :hidden true
       :expandtab true
       :smartindent true
       :tabstop 2
       :shiftwidth 2
       :autoread true
       :signcolumn "yes"
       :cursorline true

       ;; === Search ===
       :ignorecase true
       :smartcase true}]
  (each [k v (pairs options)] (tset vim.opt k v)))
