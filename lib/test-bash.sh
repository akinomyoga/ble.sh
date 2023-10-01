# -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test

ble/test/start-section 'bash' 49

# case $word を quote する必要がある条件は?

# 当然 bash の文法的に特別な意味がある文字を直接記述する時は quote が必要。word
# splitting 及び pathname expansions は発生しない。$* や ${arr[*]} が含まれる場
# 合は quote していてもしていなくても要素が IFS で連結されるので IFS には注意が
# 必要。
(
  # word splitting does not happen
  a='x y'
  ble/test code:'ret=$a' ret="x y"
  ble/test '[[ $a == "x y" ]]'
  ble/test 'case $a in ("x y") true ;; (*) false ;; esac'
  a='x  y'
  ble/test code:'ret=$a' ret="x  y"
  ble/test '[[ $a == "x  y" ]]'
  ble/test 'case $a in ("x  y") true ;; (*) false ;; esac'
  IFS=abc a='xabcy'
  ble/test code:'ret=$a' ret="xabcy"
  ble/test '[[ $a == "xabcy" ]]'
  ble/test 'case $a in ("xabcy") true ;; (*) false ;; esac'
  IFS=$' \t\n'

  # BUG bash-3.0..4.3
  #   word splitting happens in here strings.
  a='x y'
  ble/test 'read -r ret <<< $a' ret="x y"
  a='x  y'
  if ((_ble_bash<40400)); then
    ble/test 'read -r ret <<< $a' ret="x y"
  else
    ble/test 'read -r ret <<< $a' ret="x  y"
  fi
  IFS=abc a='xabcy'
  if ((_ble_bash<40400)); then
    ble/test 'read -r ret <<< $a' ret="x   y"
  else
    ble/test 'read -r ret <<< $a' ret="xabcy"
  fi
  IFS=$' \t\n'

  # pathname expansion does not happen
  b='/*'
  ble/test code:'ret=$b' ret="/*"
  ble/test 'case $b in ("/*") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< $b' ret="/*"
)

# Variable bugs
(
  # BUG bash-3.1
  #   a=(""); echo "a${a[*]}b" | cat -A とするとa^?b となって謎の文字が入る。
  #   echo "a""${a[*]}""b" 等とすれば大丈夫。
  a=("")
  function f1 { ret=$1; }
  if ((30100<=_ble_bash&&_ble_bash<30200)); then
    ble/test 'f1 "a${a[*]}b"' ret=$'a\177b'
    ble/test code:'ret="a${a[*]}b"' ret=$'a\177b'
    ble/test 'case "a${a[*]}b" in ($'\''a\177b'\'') true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< "a${a[*]}b"' ret=$'a\177b'
  else
    ble/test 'f1 "a${a[*]}b"' ret='ab'
    ble/test code:'ret="a${a[*]}b"' ret='ab'
    ble/test 'case "a${a[*]}b" in (ab) true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< "a${a[*]}b"' ret=ab
  fi

  # BUG bash-3.0..3.1
  #   "${var//%d/123}" は動かない。"${var//'%d'/123}" 等とすればOK。
  var=X%dX%dX
  if ((_ble_bash<30200)); then
    ble/test code:'ret=${var//%d/.}' ret='X%dX%dX'
  else
    ble/test code:'ret=${var//%d/.}' ret='X.X.X'
  fi

  # BUG bash-3.0..3.1
  #   local GLOBIGNORE すると、関数を出てもパス名展開の時にその影響が残っている。
  #   (直接変数の中身を見ても何もない様に見えるが。) unset GLOBIGNORE などとす
  #   ると直る。
  ble/test/chdir
  touch {a..c}.txt
  function f1 { local GLOBIGNORE='*.txt'; }
  if ((_ble_bash<30200)); then
    ble/test 'f1; echo *' stdout='*'
  else
    ble/test 'f1; echo *' stdout='a.txt b.txt c.txt'
  fi

  # BUG bash-3.0
  #   ${#param} は文字数ではなくバイト数を返す、という事になっているらしいが、
  #   実際に試してみると文字数になっている (bash-3.0.22)。何処かで patch が当たっ
  #   たのだろうか → これは bash-3.0.4 で修正された様だ。
  #
  #   (※${param:ofs:len} は 3.0-beta1 以降であれば文字数でカウントされる)
  if ((_ble_bash<30004)); then
    ble/test code:'a=あ ret=${#a}' ret=3
  else
    ble/test code:'a=あ ret=${#a}' ret=1
  fi

  # BUG bash-3.0
  #   declare -p A で改行を含む変数を出力すると改行が消える。例: 一見正しく出力
  #   されている様に錯覚するが "\ + 改行" は改行のエスケープではなく、長い文字
  #   列リテラルを二行に書く為の記法である。つまり、無視される。
  #
  #   $ A=$'\n'; declare -p A
  #   | A="\
  #   | "
  builtin unset -v v
  v=$'a\nb'
  if ((_ble_bash<30100)); then
    ble/test code:'declare -p v' stdout=$'declare -- v="a\\\nb"'
  elif ((_ble_bash<50200)); then
    ble/test code:'declare -p v' stdout=$'declare -- v="a\nb"'
  else
    ble/test code:'declare -p v' stdout='declare -- v=$'\''a\nb'\'
  fi

  # BUG bash-3.0 [Ref #D1774]
  #   "${...#$'...'}" (#D1774) という形を使うと $'...' の展開結果が ... ではな
  #   く '...'  の様に、余分な引用符が入ってしまう。extquote を設定しても結果は
  #   変わらない。
  builtin unset -v scalar
  if ((_ble_bash<30100)); then
    ble/test code:'ret="[${scalar-$'\''hello'\''}]"' ret="['hello']" # disable=#D1774
  else
    ble/test code:'ret="[${scalar-$'\''hello'\''}]"' ret='[hello]'   # disable=#D1774
  fi
)

# Array bugs
(
  # BUG bash-4.0..4.4 [Ref #D0924]
  #   ローカルで local -a x; local -A x とすると segfault する。
  #   ref http://lists.gnu.org/archive/html/bug-bash/2019-02/msg00047.html,
  #   f() { local -a a; local -A a; }; f # これで segfault する
  #
  #   - 別のスコープで定義された配列を -A とした場合には起こらない。
  #   - 同じスコープの場合でも unset a してから local -A a すれば大丈夫。
  #   - グローバルでは起こらない。
  function f1 { local -a a; local -A a; }
  if ((_ble_bash<40000)); then
    ble/test f1 exit=2
  elif ((_ble_bash<50000)); then
    ble/test '(f1)' exit=139 # SIGSEGV
  else
    ble/test f1 exit=1
  fi

  # BUG bash-3.0..4.4
  #   配列要素または $* を case 単語もしくは here strings で連結する時 IFS が "
  #   " に置き換わる。
  c=(a b c)
  IFS=x
  if ((_ble_bash<50000)); then
    # bash-3.0..4.4 bug
    ble/test 'case ${c[*]} in ("a b c") true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< ${c[*]}' ret="a b c"
  else
    ble/test 'case ${c[*]} in ("axbxc") true ;; (*) false ;; esac'
    ble/test 'read -r ret <<< ${c[*]}' ret="axbxc"
  fi
  ble/test 'case "${c[*]}" in ("axbxc") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< "${c[*]}"' ret="axbxc"
  IFS=$' \t\n'

  # BUG bash-3.0..4.2
  #   配列要素を代入右辺で連結する時 IFS が " " に置き換わる。
  #   動く例:
  #     IFS= eval 'value=${arr[*]}'
  #     IFS= eval 'value="${arr[*]}"'
  #     IFS= eval 'local value="${arr[*]}"'
  #   動かない例 (間に空白が入ってしまう):
  #     IFS= eval 'local value=${arr[*]}'
  c=(a b c)
  ble/test code:'ret=${c[*]}' ret="a b c"
  ble/test 'case ${c[*]} in ("a b c") true ;; (*) false ;; esac'
  ble/test 'read -r ret <<< ${c[*]}' ret="a b c"
  # ${c[*]} is affected by IFS
  IFS=x
  if ((_ble_bash<40300)); then
    # bash-3.0..4.2 bug
    ble/test code:'ret=${c[*]}' ret="a b c"
  else
    ble/test code:'ret=${c[*]}' ret="axbxc"
  fi
  ble/test code:'ret="${c[*]}"' ret="axbxc"
  IFS=$' \t\n'

  # BUG bash-3.0..4.1
  #   宣言されているが unset の変数について ${#a[*]} が 1 を返す。
  #   a[${#a[*}]=value もしくは ble/array#push a value するとき、その配列を事前
  #   に宣言したければ local -a a のように -a を指定する必要がある。
  #
  #   [問題]
  #
  #   bash-4.0, 4.1 (local): bash-4.1 以下で関数内で local arr しただけで
  #   ${#arr[*]} が 1 になる。その後、要素 #1 を設定しても ${#arr[*]} は 1 のま
  #   まである。これの所為で arr[${#arr[*]}]=... としても常に要素 #1 にしか代入
  #   されない事になる。
  #
  #   bash-3.0 ～ 3.2 (declare): bash-3.2 以下では関数内に限らず declare arr し
  #   ただけで ${#arr[*]} が 1 になる。但し、要素[1] に設定をすると ${#arr[*]}
  #   は 2 に増加する。従って余分な空要素があるものの ble/array#push は失敗しな
  #   い。
  #
  #   [解決]
  #
  #   local -a arr とすれば問題は起きない。※local arr=() (#D0184) としても問題
  #   は起きないがこの記述だと今度は bash-3.0 で文字列 '()' が代入されて問題で
  #   ある。
  builtin unset -v arr1 arr2
  local arr1
  local -a arr2
  if ((_ble_bash<40200)); then
    ble/test code:'ret=${#arr1[@]}' ret=1
  else
    ble/test code:'ret=${#arr1[@]}' ret=0
  fi
  ble/test code:'ret=${#arr2[@]}' ret=0

  # BUG bash-3.0..3.2 [Ref #D1241]
  #   ^? や ^A の値が declare -p で ^A^? や ^A^A に変換されてしまう。
  a=($'\x7F' $'\x01')
  if ((_ble_bash<40000)); then
    ble/test 'declare -p a' stdout=$'declare -a a=\'([0]="\x01\x01\x01\x7F" [1]="\x01\x01\x01\x01")\'' # '
  elif ((_ble_bash<40400)); then
    ble/test 'declare -p a' stdout=$'declare -a a=\'([0]="\x01\x7F" [1]="\x01\x01")\'' # '
  else
    ble/test 'declare -p a' stdout='declare -a a=([0]=$'\''\177'\'' [1]=$'\''\001'\'')' # disable=#D0525
  fi

  # BUG bash-3.1
  #   呼出先の関数で、呼出元で定義されているのと同名の配列を作っても、中が空になる。
  #   > $ function dbg/test2 { local -a hello=(1 2 3); echo "hello=(${hello[*]})";}
  #   > $ function dbg/test1 { local -a hello=(3 2 1); dbg/test2;}
  #   > $ dbg/test1
  #   > hello=()
  #
  #   これは bash-3.1-patches/bash31-004 で修正されている様だ。
  function f1 { local -a arr=(b b b); ble/util/print "(${arr[*]})"; }
  function f2 { local -a arr=(a a a); f1; }
  if ((30100<=_ble_bash&&_ble_bash<30104)); then
    ble/test f2 stdout='()'
  else
    ble/test f2 stdout='(b b b)'
  fi

  # BUG bash-3.1
  #   そもそも bash-3.1 は function a { local -a alpha=() beta=(); } を parse
  #   できないので ble.sh のテストを起動するのもままならない。
  if ((30100<=_ble_bash&&_ble_bash<30104)); then
    ble/test 'function f1 { local -a alpha=(); local -a beta=(); }'
  else
    ble/test 'function f1 { local -a alpha=() beta=(); }'
  fi

  # BUG bash-3.0..3.1 [Ref #D0182]
  #   ${#arr[n]} が文字数ではなくバイト数を返す
  if ((_ble_bash<30200)); then
    ble/test code:'ret=あ ret=${#ret[0]}' ret=3 # disable=#D0182
  else
    ble/test code:'ret=あ ret=${#ret[0]}' ret=1 # disable=#D0182
  fi

  # BUG bash-3.0 [Ref #D0184]
  #   local a=(...) や declare a=(...) (#D0184) とすると、a="(...)" と同じ事に
  #   なる。a=() の形式ならば問題ない。
  declare ret=(1 2 3) # disable=#D0184
  if ((_ble_bash<30100)); then
    ble/test ret='(1 2 3)'
  else
    ble/test ret='1'
  fi

  # BUG bash-3.0 [Ref #D0525]
  #   今まで local -a a=() の形式ならば問題ないと信じてきたが、どうやらlocal -a
  #   a=('1 2') (#D0525) が local -a a=(1 2) と同じ意味になってしまうようだ。
  #   a="123 345"; declare -a arr=("$a"); (#D0525) このようにしても駄目だ。
  #   a="123 345"; declare -a arr; arr=("$a"); こうする必要がある。
  declare -a ret=("1 2") # disable=#D0525
  if ((_ble_bash<30100)); then
    ble/test ret='1'
  else
    ble/test ret='1 2'
  fi
  v="1 2 3"
  declare -a ret=("$v") # disable=#D0525
  if ((_ble_bash<30100)); then
    ble/test ret='1'
  else
    ble/test ret='1 2 3'
  fi

  # BUG bash-3.0 [Ref #D1570]
  #   * "${var[@]/xxx/yyy}" (#D1570) はスカラー変数に対して空の結果を生む。
  #     ${var[@]//xxx/yyy}, ${var[@]/%/yyy}, ${var[@]/#/yyy} (#D1570) について
  #     も同様である。
  #   * "${scalar[@]/xxxx}" (#D1570) は全て空になる。変数名が配列である事が保証
  #     されている必要がある。
  builtin unset -v scalar
  scalar=abcd
  if ((_ble_bash<30100)); then
    ble/test code:'ret=${scalar[@]//[bc]}' ret=''   # disable=#D1570
  elif ((40300<=_ble_bash&&_ble_bash<40400)); then
    ble/test code:'ret=${scalar[@]//[bc]}' ret=$'\001a\001\001\001d' # disable=#D1570
  else
    ble/test code:'ret=${scalar[@]//[bc]}' ret='ad' # disable=#D1570
  fi
)

# Other bugs
(
  # BUG bash-3.0..4.0 (3.0..5.2 in 非対話セッション)

  # $'' 内に \' を入れていると履歴展開が '' の中で起こる? 例えば
  # rex='a'$'\'\'''!a' とすると !a の部分が展開される (9f0644470 OK)。
  #
  # 因みに対応する履歴がない場合には 4.1 以下でエラーメッセージが表示される。
  #
  # Note: bash -c や独立したスクリプト実行の中だと 3.0..5.2 および devel の全バー
  # ジョンで問題は再現する。対話セッションや set +H を指定した場合には問題は
  # 3.0..4.0 でしか発生しない。
  #
  # Note: 遡ってみるとこの項目は memo.txt に commit 9f064447 (2015-03-08) で追
  # 加されている。但し対応する項目は memo.txt には記述されていない。#D0206 が近
  # いが微妙に異なることを議論している。
  #
  q=\' line='$'$q'\'$q'!!'$q'\'$q
  ble/util/assign ret '(builtin history -s histentry; builtin history -p "$line")'
  if ((_ble_bash<30100)); then
    # 3.0 ではそもそも失敗する。
    ble/test code:'' ret=
  elif ((_ble_bash<40100)) || [[ $- != *[iH]* ]]; then
    # 非対話セッション または 3.1..4.0 では意図せず展開が起こる
    ble/test code:'' ret="${line//!!/histentry}"
  else
    # 期待した振る舞い
    ble/test code:'' ret="$line"
  fi
  ble/test '(builtin history -c; builtin history -p "$line")' stdout=

  # BUG bash-3.0 [Ref #D1956]
  #   関数定義の一番外側でリダイレクトしてもリダイレクトされない。例えば、
  #   function func { ls -l /proc/$BASHPID/fd/{0..2}; } <&"$fd0" >&"$fd1"
  #
  #   どうも更に関数を func REDIRECT & で呼び出した時にのみ発生する様だ。呼び出
  #   し元のリダイレクションリストで上書きされているという事だろうか。e
  function f1 { ble/util/print hello; } >&"$fd1"
  function f2 { ble/util/print hello >&"$fd1"; }
  function f3 { { ble/util/print hello; } >&"$fd1"; }
  function test1 {
    local fd1=
    ble/fd#alloc fd1 '>&1'
    "$1" >/dev/null & local pid=$!
    wait "$pid"
    ble/fd#close fd1
  }
  if ((_ble_bash<30100)); then
    ble/test 'test1 f1' stdout=
  else
    ble/test 'test1 f1' stdout=hello
  fi
  ble/test 'test1 f2' stdout=hello
  ble/test 'test1 f3' stdout=hello
)

ble/test/end-section
