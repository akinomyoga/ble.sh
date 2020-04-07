# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test

ble/test/start-section 'util' 435

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
  export x=2
  readonly r=3
  declare -a a=()
  if ((_ble_bash>=40000)); then
    declare -A A=()
    declare -u u=a
    declare -l l=B
    declare -c c=c
  fi
  if ((_ble_bash>=40300)); then
    declare -n n=r
  fi

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

# ble/array#pop
(
  function result { echo "$ret:${#arr[*]}:(${arr[*]})"; }
  ble/test 'arr=()     ; ble/array#pop arr; result' stdout=':0:()'
  ble/test 'arr=(1)    ; ble/array#pop arr; result' stdout='1:0:()'
  ble/test 'arr=(1 2)  ; ble/array#pop arr; result' stdout='2:1:(1)'
  ble/test 'arr=(0 0 0); ble/array#pop arr; result' stdout='0:2:(0 0)'
  ble/test 'arr=(1 2 3); ble/array#pop arr; result' stdout='3:2:(1 2)'
  ble/test 'arr=(" a a " " b b " " c c "); ble/array#pop arr; result' \
           stdout=' c c :2:( a a   b b )'
)

# ble/array#unshift
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=()
  ble/array#unshift a
  ble/test status stdout='0:()'
  ble/array#unshift a A
  ble/test status stdout='1:(A)'
  ble/array#unshift a
  ble/test status stdout='1:(A)'
  ble/array#unshift a B
  ble/test status stdout='2:(B A)'
  ble/array#unshift a C D E
  ble/test status stdout='5:(C D E B A)'
  a=()
  ble/array#unshift a A B
  ble/test status stdout='2:(A B)'
)

# ble/array#reverse
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=(); ble/array#reverse a
  ble/test status stdout='0:()'
  a=(1); ble/array#reverse a
  ble/test status stdout='1:(1)'
  a=(xy zw); ble/array#reverse a
  ble/test status stdout='2:(zw xy)'
  a=(a 3 x); ble/array#reverse a
  ble/test status stdout='3:(x 3 a)'
  a=({1..10}) b=({10..1}); ble/array#reverse a
  ble/test status stdout="10:(${b[*]})"
  a=({1..9}) b=({9..1}); ble/array#reverse a
  ble/test status stdout="9:(${b[*]})"
)

# ble/array#insert-at
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=(); ble/array#insert-at a 0 A B C
  ble/test status stdout='3:(A B C)'
  a=(); ble/array#insert-at a 1 A B C
  ble/test status stdout='3:(A B C)'
  a=(x y z); ble/array#insert-at a 0 A
  ble/test status stdout='4:(A x y z)'
  a=(x y z); ble/array#insert-at a 1 A
  ble/test status stdout='4:(x A y z)'
  a=(x y z); ble/array#insert-at a 3 A
  ble/test status stdout='4:(x y z A)'
  a=(x y z); ble/array#insert-at a 0 A B C
  ble/test status stdout='6:(A B C x y z)'
  a=(x y z); ble/array#insert-at a 1 A B C
  ble/test status stdout='6:(x A B C y z)'
  a=(x y z); ble/array#insert-at a 3 A B C
  ble/test status stdout='6:(x y z A B C)'
  a=(x y z); ble/array#insert-at a 0
  ble/test status stdout='3:(x y z)'
  a=(x y z); ble/array#insert-at a 1
  ble/test status stdout='3:(x y z)'
  a=(x y z); ble/array#insert-at a 3
  ble/test status stdout='3:(x y z)'
)

# ble/array#insert-after
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=(hello world hello world)
  ble/array#insert-after a hello 1 2 3
  ble/test status stdout='7:(hello 1 2 3 world hello world)'
  a=(heart world hello world)
  ble/array#insert-after a hello 1 2 3
  ble/test status stdout='7:(heart world hello 1 2 3 world)'
  a=(hello world hello world)
  ble/test 'ble/array#insert-after a check 1 2 3' exit=1
  ble/test status stdout='4:(hello world hello world)'
)

# ble/array#insert-before
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=(hello world this)
  ble/array#insert-before a this with check
  ble/test status stdout='5:(hello world with check this)'
  a=(hello world this)
  ble/test 'ble/array#insert-before a haystack kick check' exit=1
  ble/test status stdout='3:(hello world this)'
)

# ble/array#remove
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=(xxx yyy xxx yyy yyy xxx fdsa fdsa)
  ble/array#remove a xxx
  ble/test status stdout='5:(yyy yyy yyy fdsa fdsa)'
  a=(aa aa aa aa aa)
  ble/array#remove a bb
  ble/test status stdout='5:(aa aa aa aa aa)'
  ble/array#remove a aa
  ble/test status stdout='0:()'
  ble/array#remove a cc
  ble/test status stdout='0:()'
)

# ble/array#index
(
  a=(hello world this hello world)
  ble/test 'ble/array#index a hello' ret=0
  a=(world hep this hello world)
  ble/test 'ble/array#index a hello' ret=3
  a=(hello world this hello world)
  ble/test 'ble/array#index a check' ret=-1
)

# ble/array#last-index
(
  a=(hello world this hello world)
  ble/test 'ble/array#last-index a hello' ret=3
  a=(world hep this hello world)
  ble/test 'ble/array#last-index a hello' ret=3
  a=(hello world this hello world)
  ble/test 'ble/array#last-index a check' ret=-1
)

# ble/array#remove-at
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  a=()
  ble/test 'ble/array#remove-at a 0; status' stdout='0:()'
  ble/test 'ble/array#remove-at a 10; status' stdout='0:()'
  a=(x y z)
  ble/test 'ble/array#remove-at a 4; status' stdout='3:(x y z)'
  ble/test 'ble/array#remove-at a 3; status' stdout='3:(x y z)'
  ble/test 'ble/array#remove-at a 1; status' stdout='2:(x z)'
  ble/test 'ble/array#remove-at a 0; status' stdout='1:(z)'
  ble/test 'ble/array#remove-at a 0; status' stdout='0:()'
  a=({a..z}) a1=({a..y}) a2=({b..y}) a3=({b..h} {j..y})
  ble/test 'ble/array#remove-at a 25; status' stdout="25:(${a1[*]})"
  ble/test 'ble/array#remove-at a 0; status' stdout="24:(${a2[*]})"
  ble/test 'ble/array#remove-at a 7; status' stdout="23:(${a3[*]})"
)

# ble/string#reserve-prototype
(
  _ble_string_prototype='        '
  ble/test 'echo ${#_ble_string_prototype}' stdout=8
  ble/string#reserve-prototype 10
  ble/test 'echo ${#_ble_string_prototype}' stdout=16
  ble/test 'x=${_ble_string_prototype::10}; echo ${#x}' stdout=10
  ble/string#reserve-prototype 3
  ble/test 'echo ${#_ble_string_prototype}' stdout=16
  ble/test 'x=${_ble_string_prototype::3}; echo ${#x}' stdout=3
  ble/string#reserve-prototype 77
  ble/test 'echo ${#_ble_string_prototype}' stdout=128
  ble/test 'x=${_ble_string_prototype::77}; echo ${#x}' stdout=77
)

# ble/string#repeat
(
  ble/test 'ble/string#repeat' ret=
  ble/test 'ble/string#repeat ""' ret=
  ble/test 'ble/string#repeat a' ret=
  ble/test 'ble/string#repeat abc' ret=
  ble/test 'ble/string#repeat "" ""' ret=
  ble/test 'ble/string#repeat a ""' ret=
  ble/test 'ble/string#repeat abc ""' ret=
  ble/test 'ble/string#repeat "" 0' ret=
  ble/test 'ble/string#repeat a 0' ret=
  ble/test 'ble/string#repeat abc 0' ret=
  ble/test 'ble/string#repeat "" 1' ret=
  ble/test 'ble/string#repeat "" 10' ret=

  ble/test 'ble/string#repeat a 1' ret=a
  ble/test 'ble/string#repeat a 2' ret=aa
  ble/test 'ble/string#repeat a 5' ret=aaaaa
  ble/test 'ble/string#repeat abc 1' ret=abc
  ble/test 'ble/string#repeat abc 2' ret=abcabc
  ble/test 'ble/string#repeat abc 5' ret=abcabcabcabcabc
  ble/test 'ble/string#repeat ";&|<>" 5' ret=';&|<>;&|<>;&|<>;&|<>;&|<>'
)

# ble/string#common-prefix
(
  ble/test 'ble/string#common-prefix' ret=
  ble/test 'ble/string#common-prefix ""' ret=
  ble/test 'ble/string#common-prefix a' ret=
  ble/test 'ble/string#common-prefix "" ""' ret=
  ble/test 'ble/string#common-prefix a ""' ret=
  ble/test 'ble/string#common-prefix a b' ret=
  ble/test 'ble/string#common-prefix a a' ret=a
  ble/test 'ble/string#common-prefix abc abc' ret=abc
  ble/test 'ble/string#common-prefix abc aaa' ret=a
  ble/test 'ble/string#common-prefix abc ccc' ret=
  ble/test 'ble/string#common-prefix abc xyz' ret=
)

# ble/string#common-suffix
(
  ble/test 'ble/string#common-suffix' ret=
  ble/test 'ble/string#common-suffix ""' ret=
  ble/test 'ble/string#common-suffix a' ret=
  ble/test 'ble/string#common-suffix "" ""' ret=
  ble/test 'ble/string#common-suffix a ""' ret=
  ble/test 'ble/string#common-suffix a b' ret=
  ble/test 'ble/string#common-suffix a a' ret=a
  ble/test 'ble/string#common-suffix abc abc' ret=abc
  ble/test 'ble/string#common-suffix abc aaa' ret=
  ble/test 'ble/string#common-suffix abc ccc' ret=c
  ble/test 'ble/string#common-suffix abc xyz' ret=
)

# ble/string#split
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  nl=$'\n'
  ble/test 'ble/string#split a , ""  ; status' stdout='1:()'
  ble/test 'ble/string#split a , "1"  ; status' stdout='1:(1)'
  ble/test 'ble/string#split a , ","  ; status' stdout='2:( )'
  ble/test 'ble/string#split a , "1,"  ; status' stdout='2:(1 )'
  ble/test 'ble/string#split a , ",2"  ; status' stdout='2:( 2)'
  ble/test 'ble/string#split a , "1,,3"  ; status' stdout='3:(1  3)'
  ble/test 'ble/string#split a , "1,2,3"  ; status' stdout='3:(1 2 3)'
  ble/test 'ble/string#split a " " "1 2 3"; status' stdout='3:(1 2 3)'
  ble/test 'ble/string#split a " " "1	2	3"; status' stdout='1:(1	2	3)'
  ble/test 'ble/string#split a " " "1'"$nl"'2'"$nl"'3"; status' stdout="1:(1${nl}2${nl}3)"
)

# ble/string#split-words
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  nl=$'\n' ht=$'\t'
  ble/test 'ble/string#split-words a ""  ; status' stdout='0:()'
  ble/test 'ble/string#split-words a "1"  ; status' stdout='1:(1)'
  ble/test 'ble/string#split-words a " "  ; status' stdout='0:()'
  ble/test 'ble/string#split-words a "1 "  ; status' stdout='1:(1)'
  ble/test 'ble/string#split-words a " 2"  ; status' stdout='1:(2)'
  ble/test 'ble/string#split-words a "1  3"  ; status' stdout='2:(1 3)'
  ble/test 'ble/string#split-words a "1 2 3"; status' stdout='3:(1 2 3)'
  ble/test 'ble/string#split-words a "  1'"$ht"'2'"$ht"'3  "; status' stdout='3:(1 2 3)'
  ble/test 'ble/string#split-words a "  1'"$nl"'2'"$nl"'3  "; status' stdout='3:(1 2 3)'
)

# ble/string#split-lines
(
  function status { echo "${#a[@]}:(${a[*]})"; }
  nl=$'\n' ht=$'\t'
  ble/test 'ble/string#split-lines a ""  ; status' stdout='1:()'
  ble/test 'ble/string#split-lines a "1"  ; status' stdout='1:(1)'
  ble/test 'ble/string#split-lines a "'"$nl"'"  ; status' stdout='2:( )'
  ble/test 'ble/string#split-lines a "1'"$nl"'"  ; status' stdout='2:(1 )'
  ble/test 'ble/string#split-lines a "'"$nl"'2"  ; status' stdout='2:( 2)'
  ble/test 'ble/string#split-lines a "1'"$nl$nl"'3"  ; status' stdout='3:(1  3)'
  ble/test 'ble/string#split-lines a "1'"$nl"'2'"$nl"'3"; status' stdout='3:(1 2 3)'
  ble/test 'ble/string#split-lines a "1'"$ht"'2'"$ht"'3"; status' stdout="1:(1${ht}2${ht}3)"
  ble/test 'ble/string#split-lines a "1 2 3"; status' stdout="1:(1 2 3)"
)

# ble/string#count-char
(
  #UB: ble/test 'ble/string#count-char hello' ret=5
  ble/test 'ble/string#count-char hello a' ret=0
  ble/test 'ble/string#count-char hello あ' ret=0
  ble/test 'ble/string#count-char hello e' ret=1
  ble/test 'ble/string#count-char hello l' ret=2
  ble/test 'ble/string#count-char hello olh' ret=4
  ble/test 'ble/string#count-char hello hello' ret=5
  ble/test 'ble/string#count-char "" a' ret=0
  ble/test 'ble/string#count-char "" ab' ret=0
)

# ble/string#count-string
(
  ble/test 'ble/string#count-string hello a' ret=0
  ble/test 'ble/string#count-string hello あ' ret=0
  ble/test 'ble/string#count-string hello ee' ret=0
  ble/test 'ble/string#count-string hello e' ret=1
  ble/test 'ble/string#count-string hello l' ret=2
  ble/test 'ble/string#count-string hello ll' ret=1
  ble/test 'ble/string#count-string hello hello' ret=1
  ble/test 'ble/string#count-string "" a' ret=0
  ble/test 'ble/string#count-string "" ab' ret=0
  ble/test 'ble/string#count-string ababababa aba' ret=2
)

# ble/string#index-of
(
  ble/test 'ble/string#index-of hello a' ret=-1
  ble/test 'ble/string#index-of hello あ' ret=-1
  ble/test 'ble/string#index-of hello ee' ret=-1
  ble/test 'ble/string#index-of hello e' ret=1
  ble/test 'ble/string#index-of hello l' ret=2
  ble/test 'ble/string#index-of hello ll' ret=2
  ble/test 'ble/string#index-of hello hello' ret=0
  ble/test 'ble/string#index-of "" a' ret=-1
  ble/test 'ble/string#index-of "" ab' ret=-1
  ble/test 'ble/string#index-of ababababa aba' ret=0
)

# ble/string#last-index-of
(
  ble/test 'ble/string#last-index-of hello a' ret=-1
  ble/test 'ble/string#last-index-of hello あ' ret=-1
  ble/test 'ble/string#last-index-of hello ee' ret=-1
  ble/test 'ble/string#last-index-of hello e' ret=1
  ble/test 'ble/string#last-index-of hello l' ret=3
  ble/test 'ble/string#last-index-of hello ll' ret=2
  ble/test 'ble/string#last-index-of hello hello' ret=0
  ble/test 'ble/string#last-index-of "" a' ret=-1
  ble/test 'ble/string#last-index-of "" ab' ret=-1
  ble/test 'ble/string#last-index-of ababababa aba' ret=6
)

# ble/string#{toggle-case,tolower,toupper,capitalize}
(
  ble/test 'ble/string#toggle-case' ret=
  ble/test 'ble/string#tolower    ' ret=
  ble/test 'ble/string#toupper    ' ret=
  ble/test 'ble/string#capitalize ' ret=
  ble/test 'ble/string#toggle-case ""' ret=
  ble/test 'ble/string#tolower     ""' ret=
  ble/test 'ble/string#toupper     ""' ret=
  ble/test 'ble/string#capitalize  ""' ret=
  ble/test 'ble/string#toggle-case a' ret=A
  ble/test 'ble/string#tolower     a' ret=a
  ble/test 'ble/string#toupper     a' ret=A
  ble/test 'ble/string#capitalize  a' ret=A
  ble/test 'ble/string#toggle-case あ' ret=あ
  ble/test 'ble/string#tolower     あ' ret=あ
  ble/test 'ble/string#toupper     あ' ret=あ
  ble/test 'ble/string#capitalize  あ' ret=あ
  ble/test 'ble/string#toggle-case +' ret=+
  ble/test 'ble/string#tolower     +' ret=+
  ble/test 'ble/string#toupper     +' ret=+
  ble/test 'ble/string#capitalize  +' ret=+
  ble/test 'ble/string#toggle-case abc' ret=ABC
  ble/test 'ble/string#tolower     abc' ret=abc
  ble/test 'ble/string#toupper     abc' ret=ABC
  ble/test 'ble/string#capitalize  abc' ret=Abc
  ble/test 'ble/string#toggle-case ABC' ret=abc
  ble/test 'ble/string#tolower     ABC' ret=abc
  ble/test 'ble/string#toupper     ABC' ret=ABC
  ble/test 'ble/string#capitalize  ABC' ret=Abc
  ble/test 'ble/string#toggle-case aBc' ret=AbC
  ble/test 'ble/string#tolower     aBc' ret=abc
  ble/test 'ble/string#toupper     aBc' ret=ABC
  ble/test 'ble/string#capitalize  aBc' ret=Abc
  ble/test 'ble/string#toggle-case +aBc' ret=+AbC
  ble/test 'ble/string#tolower     +aBc' ret=+abc
  ble/test 'ble/string#toupper     +aBc' ret=+ABC
  ble/test 'ble/string#capitalize  +aBc' ret=+Abc
  ble/test 'ble/string#capitalize  "hello world"' ret='Hello World'
)

# ble/string#{trim,ltrim,rtrim}
(
  ble/test 'ble/string#trim ' ret=
  ble/test 'ble/string#ltrim' ret=
  ble/test 'ble/string#rtrim' ret=
  ble/test 'ble/string#trim  ""' ret=
  ble/test 'ble/string#ltrim ""' ret=
  ble/test 'ble/string#rtrim ""' ret=
  ble/test 'ble/string#trim  "a"' ret=a
  ble/test 'ble/string#ltrim "a"' ret=a
  ble/test 'ble/string#rtrim "a"' ret=a
  ble/test 'ble/string#trim  " a "' ret=a
  ble/test 'ble/string#ltrim " a "' ret='a '
  ble/test 'ble/string#rtrim " a "' ret=' a'
  ble/test 'ble/string#trim  " a b "' ret='a b'
  ble/test 'ble/string#ltrim " a b "' ret='a b '
  ble/test 'ble/string#rtrim " a b "' ret=' a b'
  ble/test 'ble/string#trim  "abc"' ret='abc'
  ble/test 'ble/string#ltrim "abc"' ret='abc'
  ble/test 'ble/string#rtrim "abc"' ret='abc'
  ble/test 'ble/string#trim  "  abc  "' ret='abc'
  ble/test 'ble/string#ltrim "  abc  "' ret='abc  '
  ble/test 'ble/string#rtrim "  abc  "' ret='  abc'
  for pad in $' \t\n \t\n' $'\t\t\t' $'\n\n\n'; do
    ble/test 'ble/string#trim  "'"$pad"'abc'"$pad"'"' ret='abc'
    ble/test 'ble/string#ltrim "'"$pad"'abc'"$pad"'"' ret="abc${pad}"
    ble/test 'ble/string#rtrim "'"$pad"'abc'"$pad"'"' ret="${pad}abc"
  done
)

# ble/string#escape-characters
(
  ble/test 'ble/string#escape-characters hello' ret=hello
  ble/test 'ble/string#escape-characters hello ""' ret=hello
  ble/test 'ble/string#escape-characters hello xyz' ret=hello
  ble/test 'ble/string#escape-characters hello el' ret='h\e\l\lo'
  ble/test 'ble/string#escape-characters hello hl XY' ret='\Xe\Y\Yo'

  # regex
  ble/test 'ble/string#escape-for-sed-regex      "A\.[*?+|^\$(){}/"' \
           ret='A\\\.\[\*?+|\^\$(){}\/'
  ble/test 'ble/string#escape-for-awk-regex      "A\.[*?+|^\$(){}/"' \
           ret='A\\\.\[\*\?\+\|\^\$\(\)\{\}\/'
  ble/test 'ble/string#escape-for-extended-regex "A\.[*?+|^\$(){}/"' \
           ret='A\\\.\[\*\?\+\|\^\$\(\)\{\}/'

  # bash
  ble/test 'ble/string#escape-for-bash-glob "A\*?[("' ret='A\\\*\?\[\('
  ble/test 'ble/string#escape-for-bash-single-quote "A'\''B"' ret="A'\''B"
  ble/test 'ble/string#escape-for-bash-double-quote "hello \$ \` \\ ! world"' ret='hello \$ \` \\ "\!" world'
  input=A$'\\\a\b\e\f\n\r\t\v'\'B output=A'\\\a\b\e\f\n\r\t\v\'\'B
  ble/test 'ble/string#escape-for-bash-escape-string "$input"' ret="$output"
  ble/test 'ble/string#escape-for-bash-specialchars "[hello] (world) {this,is} <test>"' \
           ret='\[hello\]\ \(world\)\ {this,is}\ \<test\>'
  ble/test 'ble/string#escape-for-bash-specialchars "[hello] (world) {this,is} <test>" b' \
           ret='\[hello\]\ \(world\)\ \{this\,is\}\ \<test\>'
  ble/test 'ble/string#escape-for-bash-specialchars "a=b:c:d" c' \
           ret='a\=b\:c\:d'
)

# ble/string#quote-command
(
  ble/test 'ble/string#quote-command' ret=
  ble/test 'ble/string#quote-command echo' ret='echo'
  ble/test 'ble/string#quote-command echo hello world' ret="echo 'hello' 'world'"
  ble/test 'ble/string#quote-command echo "hello world"' ret="echo 'hello world'"
  ble/test 'ble/string#quote-command echo "'\''test'\''"' ret="echo ''\''test'\'''"
  ble/test 'ble/string#quote-command echo "" "" ""' ret="echo '' '' ''"
  ble/test 'ble/string#quote-command echo a{1..4}' ret="echo 'a1' 'a2' 'a3' 'a4'"
)

# ble/string#create-unicode-progress-bar
(
  ble/test 'ble/string#create-unicode-progress-bar  0 24 3' ret='   '
  ble/test 'ble/string#create-unicode-progress-bar  1 24 3' ret='▏  '
  ble/test 'ble/string#create-unicode-progress-bar  2 24 3' ret='▎  '
  ble/test 'ble/string#create-unicode-progress-bar  3 24 3' ret='▍  '
  ble/test 'ble/string#create-unicode-progress-bar  4 24 3' ret='▌  '
  ble/test 'ble/string#create-unicode-progress-bar  5 24 3' ret='▋  '
  ble/test 'ble/string#create-unicode-progress-bar  6 24 3' ret='▊  '
  ble/test 'ble/string#create-unicode-progress-bar  7 24 3' ret='▉  '
  ble/test 'ble/string#create-unicode-progress-bar  8 24 3' ret='█  '
  ble/test 'ble/string#create-unicode-progress-bar  9 24 3' ret='█▏ '
  ble/test 'ble/string#create-unicode-progress-bar 15 24 3' ret='█▉ '
  ble/test 'ble/string#create-unicode-progress-bar 16 24 3' ret='██ '
  ble/test 'ble/string#create-unicode-progress-bar 17 24 3' ret='██▏'
  ble/test 'ble/string#create-unicode-progress-bar 24 24 3' ret='███'
  ble/test 'ble/string#create-unicode-progress-bar  0 24 4 unlimited' ret=$'█   '
  ble/test 'ble/string#create-unicode-progress-bar  1 24 4 unlimited' ret=$'\e[7m▏\e[27m▏  '
  ble/test 'ble/string#create-unicode-progress-bar  2 24 4 unlimited' ret=$'\e[7m▎\e[27m▎  '
  ble/test 'ble/string#create-unicode-progress-bar  3 24 4 unlimited' ret=$'\e[7m▍\e[27m▍  '
  ble/test 'ble/string#create-unicode-progress-bar  4 24 4 unlimited' ret=$'\e[7m▌\e[27m▌  '
  ble/test 'ble/string#create-unicode-progress-bar  5 24 4 unlimited' ret=$'\e[7m▋\e[27m▋  '
  ble/test 'ble/string#create-unicode-progress-bar  6 24 4 unlimited' ret=$'\e[7m▊\e[27m▊  '
  ble/test 'ble/string#create-unicode-progress-bar  7 24 4 unlimited' ret=$'\e[7m▉\e[27m▉  '
  ble/test 'ble/string#create-unicode-progress-bar  8 24 4 unlimited' ret=$' █  '
  ble/test 'ble/string#create-unicode-progress-bar  9 24 4 unlimited' ret=$' \e[7m▏\e[27m▏ '
  ble/test 'ble/string#create-unicode-progress-bar 15 24 4 unlimited' ret=$' \e[7m▉\e[27m▉ '
  ble/test 'ble/string#create-unicode-progress-bar 16 24 4 unlimited' ret=$'  █ '
  ble/test 'ble/string#create-unicode-progress-bar 17 24 4 unlimited' ret=$'  \e[7m▏\e[27m▏'
  ble/test 'ble/string#create-unicode-progress-bar 24 24 4 unlimited' ret=$'█   '
)

# ble/util/strlen
(
  ble/test 'ble/util/strlen' ret=0
  ble/test 'ble/util/strlen ""' ret=0
  ble/test 'ble/util/strlen a' ret=1
  ble/test 'ble/util/strlen abc' ret=3
  ble/test 'ble/util/strlen α' ret=2
  ble/test 'ble/util/strlen αβγ' ret=6
  ble/test 'ble/util/strlen あ' ret=3
  ble/test 'ble/util/strlen あいう' ret=9
  ble/test 'ble/util/strlen aα' ret=3
  ble/test 'ble/util/strlen aαあ' ret=6
)

# ble/path#remove{,-glob}
(
  for cmd in ble/path#{remove,remove-glob}; do
    ble/test code:'ret=; '$cmd' ret' ret=
    ble/test code:'ret=; '$cmd' ret ""' ret=
    ble/test code:'ret=a; '$cmd' ret ""' ret=a
    ble/test code:'ret=a; '$cmd' ret a' ret=
    ble/test code:'ret=a; '$cmd' ret b' ret=a
    ble/test code:'ret=a:a:a; '$cmd' ret a' ret=
    ble/test code:'ret=aa; '$cmd' ret a' ret=aa
    ble/test code:'ret=xyz:abc; '$cmd' ret ""' ret=xyz:abc
    ble/test code:'ret=xyz:abc; '$cmd' ret xyz' ret=abc
    ble/test code:'ret=xyz:abc; '$cmd' ret abc' ret=xyz
    ble/test code:'ret=xyz:abc:tuv; '$cmd' ret xyz' ret=abc:tuv
    ble/test code:'ret=xyz:abc:tuv; '$cmd' ret abc' ret=xyz:tuv
    ble/test code:'ret=xyz:abc:tuv; '$cmd' ret tuv' ret=xyz:abc
    ble/test code:'ret=xyz:xyz; '$cmd' ret xyz' ret=
    ble/test code:'ret=xyz:abc:xyz; '$cmd' ret xyz' ret=abc
    ble/test code:'ret=xyz:abc:xyz; '$cmd' ret abc' ret=xyz:xyz
    ble/test code:'ret=xyz:xyz:xyz; '$cmd' ret xyz' ret=
  done

  ble/test code:'ret=a; ble/path#remove ret \?' ret=a
  ble/test code:'ret=aa; ble/path#remove ret \?' ret=aa
  ble/test code:'ret=a:b; ble/path#remove ret \?' ret=a:b
  ble/test code:'ret=a:b:c; ble/path#remove ret \?' ret=a:b:c
  ble/test code:'ret=aa:b:cc; ble/path#remove ret \?' ret=aa:b:cc
  ble/test code:'ret=stdX:stdY:usrZ; ble/path#remove ret "std[a-zX-Z]"' ret=stdX:stdY:usrZ
  ble/test code:'ret=stdX:usrZ:stdY; ble/path#remove ret "std[a-zX-Z]"' ret=stdX:usrZ:stdY
  ble/test code:'ret=usrZ:stdX:stdY; ble/path#remove ret "std[a-zX-Z]"' ret=usrZ:stdX:stdY

  ble/test code:'ret=a; ble/path#remove-glob ret \?' ret=
  ble/test code:'ret=aa; ble/path#remove-glob ret \?' ret=aa
  ble/test code:'ret=a:b; ble/path#remove-glob ret \?' ret=
  ble/test code:'ret=a:b:c; ble/path#remove-glob ret \?' ret=
  ble/test code:'ret=aa:b:cc; ble/path#remove-glob ret \?' ret=aa:cc
  ble/test code:'ret=stdX:stdY:usrZ; ble/path#remove-glob ret "std[a-zX-Z]"' ret=usrZ
  ble/test code:'ret=stdX:usrZ:stdY; ble/path#remove-glob ret "std[a-zX-Z]"' ret=usrZ
  ble/test code:'ret=usrZ:stdX:stdY; ble/path#remove-glob ret "std[a-zX-Z]"' ret=usrZ
)

ble/test/end-section
