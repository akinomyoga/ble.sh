#!/bin/bash

# Note: <<-EOF の形式を使っても TAB しか削除されない様だ。
#   更に EOF の深さに関係なく各行で TAB はすべて削除される。
function check-heredoc-indent() {
  cat <<-EOF
	{
	  echo
	  hello
	}
	EOF
}
check-heredoc-indent

# Q: エイリアスに / を含む名前を指定できるか?
# A: できない
#alias ble/test/begin='cat <<EOF'

# Q: エイリアスでヒアドキュメントを開始できるか?
# A: できる。
shopt -s expand_aliases
alias BeginTest='cat <<-EndTest'
(
	BeginTest
	本当にこれで
	動くのだろうか
	EndTest
)

# Q: ヒアドキュメント内の単語に対してエイリアスは展開されるか
# A: 当然ながら展開されない。

#shopt -s expand_aliases
#alias BeginTest='cat <<EOF'
#alias EndTest='EOF'
