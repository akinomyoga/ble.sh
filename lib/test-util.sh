# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble/util/import "$_ble_base/lib/core-test.sh"

# bleopt

(
  # 定義・設定・出力
  ble/test 'bleopt a=1' \
           exit=1
  ble/test 'bleopt a' \
           stdout= exit=1
  ble/test 'bleopt a:=2'
  ble/test 'bleopt a' \
           stdout="bleopt a='2'"
  ble/test '[[ $bleopt_a == 2 ]]'
  ble/test "bleopt | grep 'bleopt a='" \
           stdout="bleopt a='2'"
  ble/test 'bleopt a=3'
  ble/test 'bleopt a' \
           stdout="bleopt a='3'"

  # setter
  function bleopt/check:a { value=123; }
  ble/test 'bleopt a=4 && bleopt a'
  stdout="bleopt a='123'"
  function bleopt/check:a { false; }
  ble/test 'bleopt a=5' \
           exit=1
  ble/test 'bleopt a' \
           stdout="bleopt a='123'"

  # 複数引数
  ble/test bleopt f:=10 g:=11
  ble/test bleopt f g \
           stdout="bleopt f='10'${_ble_term_nl}bleopt g='11'"
  ble/test bleopt f=12 g=13
  ble/test bleopt f g \
           stdout="bleopt f='12'${_ble_term_nl}bleopt g='13'"

  # bleopt/declare
  ble/test bleopt/declare -v b 6
  ble/test bleopt b stdout="bleopt b='6'"
  ble/test bleopt/declare -n c 7
  ble/test bleopt c stdout="bleopt c='7'"
  ble/test bleopt d:= e:=
  ble/test bleopt/declare -v d 8
  ble/test bleopt/declare -n e 9
  ble/test bleopt d stdout="bleopt d=''"
  ble/test bleopt e stdout="bleopt e='9'"
)

# ble/test

ble/test ble/util/setexit 0   exit=0
ble/test ble/util/setexit 1   exit=1
ble/test ble/util/setexit 9   exit=9
ble/test ble/util/setexit 128 exit=128
ble/test ble/util/setexit 255 exit=255

# ble/unlocal

(
  a=1
  function f1 {
    echo g:$a
    local a=2
    echo l:$a
    ble/util/unlocal a
    echo g:$a
    a=3
  }
  ble/test 'f1; echo g:$a' \
           stdout=g:1 \
           stdout=l:2 \
           stdout=g:1 \
           stdout=g:3

  function f2 {
    echo f1:$a@f2
    local a=3
    echo f2:$a@f2
    ble/util/unlocal a
    echo f1:$a@f2
    a=$a+
  }
  function f1 {
    echo g:$a@f1
    local a=2
    echo f1:$a@f1
    f2
    echo f1:$a@f1
    ble/util/unlocal a
    echo g:$a@f1
    a=$a+
  }
  ble/test 'a=1; f1; echo g:$a@g' \
           stdout=g:1@f1 \
           stdout=f1:2@f1 \
           stdout=f1:2@f2 \
           stdout=f2:3@f2 \
           stdout=f1:2@f2 \
           stdout=f1:2+@f1 \
           stdout=g:1@f1 \
           stdout=g:1+@g
)

# ble/util/upvar, ble/util/uparr (Freddy Vulto's trick)

(
  function f1 {
    local a=1 b=2
    local result=$((a+b))
    local "$1" && ble/util/upvar "$1" "$result"
  }
  ble/test 'f1 x; ret=$x' ret=3
  ble/test 'f1 a; ret=$a' ret=3
  ble/test 'f1 result; ret=$result' ret=3

  function f2 {
    local a=1
    local -a b=(2)
    local -a result=($((a+b[0])) y z)
    local "$1" && ble/util/uparr "$1" "${result[@]}"
  }
  ble/test 'f2 x; ret="(${x[*]})"' ret='(3 y z)'
  ble/test 'f2 a; ret="(${a[*]})"' ret='(3 y z)'
  ble/test 'f2 b; ret="(${b[*]})"' ret='(3 y z)'
  ble/test 'f2 result; ret="(${result[*]})"' ret='(3 y z)'
)

# ble/util/save-vars, restore-vars

(
  VARNAMES=(name x y count data)

  function print-status {
    echo "name=$name x=$x y=$y count=$count data=(${data[*]})"
  }

  function f1 {
    local "${VARNAMES[@]}"

    name=1 x=2 y=3 count=4 data=(aa bb cc dd)
    print-status
    ble/util/save-vars save1_ "${VARNAMES[@]}"

    name=one x= y=A count=1 data=(Q)
    print-status
    ble/util/save-vars save2_ "${VARNAMES[@]}"

    ble/util/restore-vars save1_ "${VARNAMES[@]}"
    print-status

    ble/util/restore-vars save2_ "${VARNAMES[@]}"
    print-status
  }
  ble/test f1 \
           stdout='name=1 x=2 y=3 count=4 data=(aa bb cc dd)' \
           stdout='name=one x= y=A count=1 data=(Q)' \
           stdout='name=1 x=2 y=3 count=4 data=(aa bb cc dd)' \
           stdout='name=one x= y=A count=1 data=(Q)'
)

# ble/variable#get-attr

(
  declare v=1
  declare -i i=1
  declare -u u=a
  declare -l l=B
  declare -c c=c
  export x=2
  readonly r=3
  declare -a a=()
  declare -A A=()
  declare -n n=r

  ble/test 'ble/variable#get-attr v; ret=$attr' ret=
  ble/test 'ble/variable#get-attr i; ret=$attr' ret=i
  ble/test 'ble/variable#get-attr x; ret=$attr' ret=x
  ble/test 'ble/variable#get-attr r; ret=$attr' ret=r
  ble/test 'ble/variable#get-attr a; ret=$attr' ret=a
  if ((_ble_bash>=40000)); then
    ble/test 'ble/variable#get-attr u; ret=$attr' ret=u
    ble/test 'ble/variable#get-attr l; ret=$attr' ret=l
    ble/test 'ble/variable#get-attr c; ret=$attr' ret=c
    ble/test 'ble/variable#get-attr A; ret=$attr' ret=A
  fi
  # ((_ble_bash>=40300)) &&
  #   ble/test 'ble/variable#get-attr n; ret=$attr' ret=n

  ble/test 'ble/variable#has-attr i i'
  ble/test 'ble/variable#has-attr x x'
  ble/test 'ble/variable#has-attr r r'
  ble/test 'ble/variable#has-attr a a'
  ble/test 'ble/variable#has-attr v i' exit=1
  ble/test 'ble/variable#has-attr v x' exit=1
  ble/test 'ble/variable#has-attr v r' exit=1
  ble/test 'ble/variable#has-attr v a' exit=1
  if ((_ble_bash>=40000)); then
    ble/test 'ble/variable#has-attr u u'
    ble/test 'ble/variable#has-attr l l'
    ble/test 'ble/variable#has-attr c c'
    ble/test 'ble/variable#has-attr A A'
    ble/test 'ble/variable#has-attr v u' exit=1
    ble/test 'ble/variable#has-attr v l' exit=1
    ble/test 'ble/variable#has-attr v c' exit=1
    ble/test 'ble/variable#has-attr v A' exit=1
  fi
  # if ((_ble_bash>=40300)); then
  #   ble/test 'ble/variable#has-attr n n'
  #   ble/test 'ble/variable#has-attr v n' exit=1
  # fi

  ble/test 'ble/is-inttype i'
  ble/test 'ble/is-inttype v' exit=1
  ble/test 'ble/is-readonly r'
  ble/test 'ble/is-readonly v' exit=1
  if ((_ble_bash>=40000)); then
    ble/test 'ble/is-transformed u'
    ble/test 'ble/is-transformed l'
    ble/test 'ble/is-transformed c'
    ble/test 'ble/is-transformed v' exit=1
  fi
)

# _ble_array_prototype
(
  _ble_array_prototype=()
  ble/test 'echo ${#_ble_array_prototype[@]}' stdout=0
  ble/array#reserve-prototype 10
  ble/test 'echo ${#_ble_array_prototype[@]}' stdout=10
  ble/test 'x=("${_ble_array_prototype[@]::10}"); echo ${#x[@]}' stdout=10
  ble/array#reserve-prototype 3
  ble/test 'echo ${#_ble_array_prototype[@]}' stdout=10
  ble/test 'x=("${_ble_array_prototype[@]::3}"); echo ${#x[@]}' stdout=3
)

# ble/is-array
(
  declare -a a=()
  declare b=
  ble/test 'ble/is-array a'
  ble/test 'ble/is-array b' exit=1
  ble/test 'ble/is-array c' exit=1
)

# ble/array#set
(
  ble/test 'ble/array#set a; echo "${#a[@]}:(${a[*]})"' stdout='0:()'
  ble/test 'ble/array#set a Q; echo "${#a[@]}:(${a[*]})"' stdout='1:(Q)'
  ble/test 'ble/array#set a 1 2 3; echo "${#a[@]}:(${a[*]})"' stdout='3:(1 2 3)'
  ble/test 'ble/array#set a; echo "${#a[@]}:(${a[*]})"' stdout='0:()'
)

# ble/array#push
(
  declare -a a=()
  ble/array#push a
  ble/test 'echo "${#a[@]}:(${a[*]})"' stdout='0:()'
  ble/array#push a A
  ble/test 'echo "${#a[@]}:(${a[*]})"' stdout='1:(A)'
  ble/array#push a B C
  ble/test 'echo "${#a[@]}:(${a[*]})"' stdout='3:(A B C)'
  ble/array#push a
  ble/test 'echo "${#a[@]}:(${a[*]})"' stdout='3:(A B C)'
)

#------------------------------------------------------------------------------

## 関数 ble/test/check-ret
##   deprecated
function ble/test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in" "${@:4}"
  if ! ble/util/assert '[[ $ret == "$expected" ]]'; then
    ble/util/print "command: $f $in" >&2
    ble/util/print 'FAIL: $ret'
    ble/test/diff "$expected" "$ret"
  fi
}

function ble/test:ble/array#pop {
  local arr; builtin eval "arr=($1)"
  ble/array#pop arr
  ret="$ret:(${arr[*]}):${#arr[*]}"
}
ble/test/check-ret ble/test:ble/array#pop '' ':():0'
ble/test/check-ret ble/test:ble/array#pop '1' '1:():0'
ble/test/check-ret ble/test:ble/array#pop '1 2' '2:(1):1'
ble/test/check-ret ble/test:ble/array#pop '0 0 0' '0:(0 0):2'
ble/test/check-ret ble/test:ble/array#pop '1 2 3' '3:(1 2):2'
ble/test/check-ret ble/test:ble/array#pop '" a a " " b b " " c c "' ' c c :( a a   b b ):2'

function ble/test:ble/string#escape {
  ble/test/check-ret ble/string#escape-for-sed-regex '\.[*?+|^$(){}/' '\\\.\[\*?+|\^\$(){}\/'
  ble/test/check-ret ble/string#escape-for-awk-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}\/'
  ble/test/check-ret ble/string#escape-for-extended-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}/'
  ble/test/check-ret ble/string#escape-for-bash-specialchars '[hello] (world) {this,is} <test>' '\[hello\]\ \(world\)\ {this,is}\ \<test\>'
  ble/test/check-ret ble/string#escape-for-bash-specialchars '[hello] (world) {this,is} <test>' '\[hello\]\ \(world\)\ \{this\,is\}\ \<test\>' b
  ble/test/check-ret ble/string#escape-for-bash-specialchars 'a=b:c:d' 'a\=b\:c\:d' c
}

ble/test:ble/string#escape

function ble/test:ble/array#index {
  local needle=${1%%:*} arr
  arr=(${1#*:})
  ble/array#index arr "$needle"
}
ble/test/check-ret ble/test:ble/array#index 'hello:hello world this hello world' 0
ble/test/check-ret ble/test:ble/array#index 'hello:world hep this hello world' 3
ble/test/check-ret ble/test:ble/array#index 'check:hello world this hello world' -1

function ble/test:ble/array#last-index {
  local needle=${1%%:*} arr
  arr=(${1#*:})
  ble/array#last-index arr "$needle"
}
ble/test/check-ret ble/test:ble/array#last-index 'hello:hello world this hello world' 3
ble/test/check-ret ble/test:ble/array#last-index 'hello:world hep this hello world' 3
ble/test/check-ret ble/test:ble/array#last-index 'check:hello world this hello world' -1
