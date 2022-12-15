# bashrc -*- mode: sh ; mode: sh-bash -*-

#------------------------------------------------------------------------------
# 1. 最初の疑惑は complete -p ls の結果が何だか少ない事による問題の可能性。
#
# 然し、実際に ble.sh ありなし両方試しても同じ結果だった。更に、手動で complete
# -F _fzf_path_completion ls を実行して試してみてもちゃんと期待通りに動く。また、
# 報告を見る限りは -o bashdefault -o default が指定されている物 (view) であって
# も問題が生じる様である。何が別の要因で動いたり動かなかったりするのだろう。

# source ~/.fzf.bash
# complete -p ls

# Result: complete -o bashdefault -o default -F _fzf_path_completion ls

# source out/ble.sh --norc
# ble-import fzf-completion
# ble-import fzf-key-bindings
# complete -p ls

# Result: complete -o bashdefault -o default -F _fzf_path_completion ls

#------------------------------------------------------------------------------
# 2. 次の可能性は bind -v の違いによる物
#
# これも違う様だ。

# source out/ble.sh --norc
# ble-import fzf-completion
# ble-import fzf-key-bindings
# bind -v > a.txt

# $ bash
# $ bind -v > b.txt

# Result:
#
# --- a.txt^I2022-12-13 19:43:56.254801647 +0900
# +++ b.txt^I2022-12-13 19:44:32.487842792 +0900
# @@ -36,10 +36,10 @@
#  set completion-display-width -1
#  set completion-prefix-display-length 0
#  set completion-query-items 100
# -set editing-mode emacs
# +set editing-mode vi
#  set emacs-mode-string @
#  set history-size 0
# -set keymap emacs
# -set keyseq-timeout 500
# +set keymap vi-insert
# +set keyseq-timeout 1
#  set vi-cmd-mode-string (cmd)
#  set vi-ins-mode-string (ins)

#------------------------------------------------------------------------------
# 3. 或いは -o emacs か -o vi で違うのだろうか。
#
# 関係なかった。

# $ bash
# $ set -o emacs
# $ ls ~/opt[TAB]

#------------------------------------------------------------------------------
# 4. 遅延で fzf をロードした時の問題?
#
# 関係なかった。

# source out/ble.sh --norc
# ble-import -d fzf-completion
# ble-import -d fzf-key-bindings

#------------------------------------------------------------------------------
# 5. .blerc が悪い?
#
# 関係なかった。

# source out/ble.sh --rcfile ~/.blerc

#------------------------------------------------------------------------------
# 6. .bashrc が悪い?
#
# 取り敢えずこれで再現する。というか分かった。単に bash-completion をロードして
# いるかしていないかの違いだった。

# source out/ble.sh --norc
# ble-import fzf-completion
# ble-import fzf-key-bindings

# $ NOBLE=1 bash --norc
# $ source bashrc.gh264

# source ~/.mwg/git/scop/bash-completion/bash_completion
# source out/ble.sh --norc
# ble-import fzf-completion
# ble-import fzf-key-bindings

#------------------------------------------------------------------------------
# 8. 念の為 bash-completion + fzf (without ble.sh) で動くか試す
#
# ちゃんと動いている

# source ~/.mwg/git/scop/bash-completion/bash_completion
# source ~/.fzf.bash

#------------------------------------------------------------------------------
# 7. 何が起こっているのかについて詳細に調べる

# source ~/.mwg/git/scop/bash-completion/bash_completion
# source out/ble.sh --norc
# ble-import fzf-completion
# ble-import fzf-key-bindings

# source ~/.mwg/git/scop/bash-completion/bash_completion
# source ~/.fzf.bash

# echo --------------------------------------- >> a.txt
# function compopt {
#   local IFS=$' \t\n'
#   echo "compopt $*"
#   printf 'args: '
#   printf '<%s>' "$@"
#   printf '\n'
#   builtin compopt "$@"
# } >> a.txt
# function _test1() {
#   echo "[start _fzf_path_completion $*]" >> a.txt
#   _fzf_path_completion "$@"; local ext=$?
#   declare -p COMPREPLY >> a.txt 2>&1
#   echo "[end _fzf_path_completion $*] $ext" >> a.txt
#   return "$ext"
# }
# # complete -p ls # →この時点では complete -F _fzf_path_completion ls
# complete -F _test1 ls

# 基本的には以下を呼び出している
#
# compopt -o ble/syntax-raw # fzf integration の時のみ
# compopt -o filenames
# COMPREPLY=("~/opt")
#
#------------------
# 次はこれだけを直接呼び出す設定で確認を行う
#
# → うーん。以下の test2a の様な単純な設定の時点で bash と振る舞いが異なるとい
# う事が分かってしまった。修正する必要がある。調べてみるとどうやら
# ble/complete/action:file/complete 迄ちゃんと呼び出されている様だ。と、これで
# 分かった。生成された候補が '~/opt' であるが、これはチルダ展開をしないとファイ
# ル名にならない。なので正しくディレクトリであるかどうかを判定する事ができない
# という事。

source out/ble.sh --norc

function _test2a {
  [[ ${BLE_ATTACHED-} ]] &&
    compopt -o ble/syntax-raw
  compopt -o filenames
  COMPREPLY=("~/opt")
  #COMPREPLY=("a b") # 元の bash では全体をファイル名として認識し quote もする
  #COMPREPLY=("'a b'") # 元の bash では quote removal 等する事なく ' もファイル名の一部として、quote もする。
  #COMPREPLY=("~murase/opt") # 元の bash では quote removal 等する事なく ' もファイル名の一部として、quote もする。
  #COMPREPLY=("~/o?t") # 元の bash では途中のパス名展開は実行しない。
}
complete -F _test2a test2a
function _test2b {
  [[ ${BLE_ATTACHED-} ]] &&
    compopt -o ble/syntax-raw
  compopt -o filenames
  COMPREPLY=("~/opt")
}
complete -F _test2b test2b
