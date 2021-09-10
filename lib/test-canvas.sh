#!/bin/bash

ble-import lib/core-test

_ble_test_canvas_contra=
if [[ -x ext/contra ]]; then
  _ble_test_canvas_contra=ext/contra
elif [[ $(printf 'hello world' | contra test 5 2 2>/dev/null) == $' worl\nd    ' ]]; then
  _ble_test_canvas_contra=contra
fi

function ble/test:canvas/trace.contra {
  [[ $_ble_test_canvas_contra ]] || return 0 # skip

  local w=${1%%:*} h=${1#*:} esc=$2 opts=$3 test_opts=$4
  local expect=$(sed 's/\$$//')

  local ret x=0 y=0 g=0 rex termw=$w termh=$h
  rex=':x=([^:]+):'; [[ :$test_opts: =~ $rex ]] && ((x=BASH_REMATCH[1]))
  rex=':y=([^:]+):'; [[ :$test_opts: =~ $rex ]] && ((y=BASH_REMATCH[1]))
  rex=':termw=([^:]+):'; [[ :$test_opts: =~ $rex ]] && ((termw=BASH_REMATCH[1]))
  rex=':termh=([^:]+):'; [[ :$test_opts: =~ $rex ]] && ((termh=BASH_REMATCH[1]))

  local x0=$x y0=$y
  LINES=$h COLUMNS=$w ble/canvas/trace "$esc" "$opts"
  local out=$ret

  ble/string#quote-word "$esc"; local q_esc=$ret
  ble/string#quote-word "$opts"; local q_opts=$ret
  ble/test --depth=1 --display-code="trace $q_esc $q_opts" \
           '{ printf "\e['$((y0+1))';'$((x0+1))'H"; ble/util/put "$out";} | "$_ble_test_canvas_contra" test "$termw" "$termh"' \
           stdout="$expect"
}

#------------------------------------------------------------------------------
# from lib/test-canvas.sh

ble/test/start-section 'ble/canvas/trace (relative:confine:measure-bbox)' 17

# test1

ble/test:canvas/trace.contra 10:10 'hello world this is a flow world' relative x=3:y=3:termw=20 << EOF
                    $
                    $
                    $
   hello w          $
orld this           $
is a flow           $
world               $
                    $
                    $
                    $
EOF

ble/test:canvas/trace.contra 20:1 '12345678901234567890hello' confine << EOF
12345678901234567890$
EOF

ble/test:canvas/trace.contra 10:1 $'hello\nworld' confine << EOF
helloworld$
EOF
ble/test:canvas/trace.contra 10:2 $'hello\nworld check' confine << EOF
hello     $
world chec$
EOF

# ble/test:ble/canvas/trace

ble/test:canvas/trace.contra 10:6 $'hello\e[B\e[4D123' measure-bbox x=3:y=2 << EOF
          $
          $
   hello  $
    123   $
          $
          $
EOF
[[ $_ble_test_canvas_contra ]] &&
  ble/test 'echo "$x1-$x2:$y1-$y2"' stdout='3-8:2-4'

ble/test:canvas/trace.contra 10:2 日本語 measure-bbox << EOF
日本語    $
          $
EOF
[[ $_ble_test_canvas_contra ]] &&
  ble/test 'echo "$x1-$x2:$y1-$y2"' stdout='0-6:0-1'

ble/test:canvas/trace.contra 10:2 $'hello\eDworld' measure-bbox << EOF
hello     $
     world$
EOF
[[ $_ble_test_canvas_contra ]] &&
  ble/test 'echo "$x1-$x2:$y1-$y2"' stdout='0-10:0-2'

ble/test:canvas/trace.contra 10:2 $'hello\eMworld' measure-bbox << EOF
     world$
hello     $
EOF
[[ $_ble_test_canvas_contra ]] &&
  ble/test 'echo "$x1-$x2:$y1-$y2"' stdout='0-10:-1-1'

(
  LINES=10 COLUMNS=10 _ble_term_xenl=1
  ble/test 'x=0 y=0; ble/canvas/trace "HelloWorld"; ret=$x,$y' ret=10,0
  ble/test 'x=0 y=0; ble/canvas/trace "HelloWorldH"; ret=$x,$y' ret=1,1
  ble/test 'x=0 y=0; ble/canvas/trace "HelloWorldHello"; ret=$x,$y' ret=5,1
  ble/test 'x=0 y=0; ble/canvas/trace "HelloWorldHelloWorldHello"; ret=$x,$y' ret=5,2
  ble/test 'x=0 y=0; ble/canvas/trace "HelloWorldHelloWorldHelloWorldHello"; ret=$x,$y' ret=5,3
)

#------------------------------------------------------------------------------
# from test/check-trace.sh

ble/test/start-section 'ble/canvas/trace (cfuncs)' 18

function ble/test:canvas/check-trace-1 {
  local input=$1 ex=$2 ey=$3
  ble/canvas/trace.draw "$input"
  ble/test --depth=1 '((x==ex&&y==ey))'
}

function ble/test:canvas/check-trace {
  local -a DRAW_BUFF=()
  ble/canvas/put.draw "$_ble_term_clear"
  local x=0 y=0

  # 0-9
  ble/test:canvas/check-trace-1 "abc" 3 0
  ble/test:canvas/check-trace-1 $'\n\n\nn' 1 3
  ble/test:canvas/check-trace-1 $'\e[3BB' 2 6
  ble/test:canvas/check-trace-1 $'\e[2AA' 3 4
  ble/test:canvas/check-trace-1 $'\e[20CC' 24 4
  ble/test:canvas/check-trace-1 $'\e[8DD' 17 4
  ble/test:canvas/check-trace-1 $'\e[9EE' 1 13
  ble/test:canvas/check-trace-1 $'\e[6FF' 1 7
  ble/test:canvas/check-trace-1 $'\e[28GG' 28 7
  ble/test:canvas/check-trace-1 $'\e[II' 33 7

  ble/test:canvas/check-trace-1 $'\e[3ZZ' 17 7
  ble/test:canvas/check-trace-1 $'\eDD' 18 8
  ble/test:canvas/check-trace-1 $'\eMM' 19 7
  ble/test:canvas/check-trace-1 $'\e77\e[3;3Hexcur\e8\e[C8' 21 7
  ble/test:canvas/check-trace-1 $'\eEE' 1 8
  ble/test:canvas/check-trace-1 $'\e[10;24HH' 24 9
  ble/test:canvas/check-trace-1 $'\e[1;94mb\e[m' 25 9

  local expect=$(sed 's/\$$//' << EOF
abc                                     $
                                        $
  excur                                 $
n                                       $
  A             D      C                $
                                        $
 B                                      $
F               Z M78      G    I       $
E                D                      $
                       Hb               $
                                        $
                                        $
                                        $
E                                       $
                                        $
EOF
)
  [[ $_ble_test_canvas_contra ]] &&
    ble/test --depth=1 \
             'ble/canvas/flush.draw | $_ble_test_canvas_contra test 40 15' \
             stdout="$expect"
}
ble/test:canvas/check-trace

#------------------------------------------------------------------------------
# test-trace.sh

ble/test/start-section 'ble/canvas/trace (justify)' 24

ble/test:canvas/trace.contra 30:1 'a b c' justify << EOF
a             b              c$
EOF
ble/test:canvas/trace.contra 30:1 ' center ' justify << EOF
            center            $
EOF
ble/test:canvas/trace.contra 30:1 ' right-aligned' justify << EOF
                 right-aligned$
EOF
ble/test:canvas/trace.contra 30:1 'left-aligned' justify << EOF
left-aligned                  $
EOF
ble/test:canvas/trace.contra 30:1 ' 日本語' justify << EOF
                        日本語$
EOF
ble/test:canvas/trace.contra 30:1 'a b c d e f' justify << EOF
a    b     c     d     e     f$
EOF
ble/test:canvas/trace.contra 30:2 $'hello center world\na b c d e f' justify << EOF
hello       center       world$
a    b     c     d     e     f$
EOF
ble/test:canvas/trace.contra 30:3 'A brown fox jumped over the lazy dog. A brown fox jumped over the lazy dog.' justify << EOF
A brown fox jumped over the la$
zy dog. A brown fox jumped ove$
r      the      lazy      dog.$
EOF

# ' ' による分割点は最低幅1を保持しつつ空白の分配が均等に行われるかのテスト。
ble/test:canvas/trace.contra 30:2 $'hello blesh world\rHELLO WORLD\nhello world HELLO BLESH WORLD' justify=$' \r' << EOF
hello blesh  worldHELLO  WORLD$
hello world HELLO BLESH  WORLD$
EOF

# justify & measure-bbox
COLUMNS=10 LINES=10 x=3 y=2 ble/canvas/trace $'a b c\n' justify:measure-bbox
# ble/string#quote-word "$ret"
# ble/util/print "ret=$ret"
ble/test 'echo "$x1,$y1:$x2,$y2"' stdout:'0,2:10,4'
COLUMNS=10 LINES=10 x=3 y=2 ble/canvas/trace $' hello ' justify:measure-bbox
ble/test 'echo "$x1,$y1:$x2,$y2"' stdout:'2,2:7,3'

# フィールドの x1:x2 がそのまま出力すると画面外に出るという時に正しくシフトでき
# ているか。
ble/test:canvas/trace.contra 30:1 $'\e[3Dhello\rblesh\rworld\e[1D' justify=$'\r' x=5 << EOF
hello      blesh         world$
EOF

# justify x clip のテスト
ble/test:canvas/trace.contra \
  30:5 $'hello world\nfoo bar buzz\nA quick brown fox\nLorem ipsum\n1 1 2 3 5 8 13 21 34 55 89 144' \
  justify:clip=2,1+24,5 << EOF
o          bar                $
    quick     brown           $
rem                    i      $
1 2 3 5 8 13 21 34 55 89      $
                              $
EOF

ble/test:canvas/trace.contra 30:1 $'hello1 world long long word quick brown' justify:confine << EOF
hello1 world long long word qu$
EOF

ble/test:canvas/trace.contra 30:1 $'hello2 world long long word quick brown' justify:truncate << EOF
hello2 world long long word qu$
EOF

ble/test:canvas/trace.contra 60:2 $'-- INSERT --\r/home/murase\r2021-01-01 00:00:00' justify << EOF
--           INSERT           2021-01-01            00:00:00$
                                                            $
EOF

ble/test:canvas/trace.contra 30:3 $'hello\r\vquick check\v\rtest \e[2Afoo\r\vbar' justify:truncate << EOF
hello                      foo$
quick         check        bar$
              test            $
EOF

ble/test:canvas/trace.contra 30:3 $'hello\n2021-01-01\nA' right:measure-bbox:measure-gbox << EOF
                         hello$
                    2021-01-01$
                             A$
EOF
if [[ $_ble_test_canvas_contra ]]; then
  ble/test 'echo "bbox:$x1,$y1-$x2,$y2"' stdout='bbox:0,0-30,3'
  ble/test 'echo "gbox:$gx1,$gy1-$gx2,$gy2"' stdout='gbox:20,0-30,3'
fi

ble/test:canvas/trace.contra 30:3 $'hello\n2021-01-01\nA' center:measure-bbox:measure-gbox << EOF
            hello             $
          2021-01-01          $
              A               $
EOF
if [[ $_ble_test_canvas_contra ]]; then
  ble/test 'echo "bbox:$x1,$y1-$x2,$y2"' stdout='bbox:0,0-20,3'
  ble/test 'echo "gbox:$gx1,$gy1-$gx2,$gy2"' stdout='gbox:10,0-20,3'
fi

ble/test:canvas/trace.contra 10:1 $'xyz\e[4Daxyz' relative:measure-bbox x=3 << EOF
  axyz    $
EOF
if [[ $_ble_test_canvas_contra ]]; then
  ble/test 'echo "bbox:$x1,$y1-$x2,$y2"' stdout='bbox:2,0-6,1'
fi

#------------------------------------------------------------------------------
# trace-text

ble/test/start-section 'ble/canvas/trace-text' 11

(
  sgr0= sgr1=

  # truncate
  lines=1 cols=10 _ble_term_xenl=1 x=0 y=0
  ble/test 'ble/canvas/trace-text "Hello World";ret="$x,$y,$ret"' ret='10,0,Hello Worl'
  lines=1 cols=10 _ble_term_xenl= x=0 y=0
  ble/test 'ble/canvas/trace-text "Hello World";ret="$x,$y,$ret"' ret='9,0,Hello Wor'
  lines=1 cols=10 _ble_term_xenl=1 x=3 y=0
  ble/test 'ble/canvas/trace-text "Hello World";ret="$x,$y,$ret"' ret='10,0,Hello W'

  # 折返し
  lines=3 cols=10 _ble_term_xenl=1 x=3 y=0
  ble/test 'ble/canvas/trace-text "Hello Bash World";ret="$x,$y,$ret"' ret='9,1,Hello Bash World'

  # 全角文字の折返し (nonewline on/off)
  lines=3 cols=10 _ble_term_xenl=1 x=3 y=0
  ble/test 'ble/canvas/trace-text "これは日本語の文章";ret="$x,$y,$ret"' ret=$'2,2,これは\n日本語の文章'
  lines=3 cols=10 _ble_term_xenl=1 x=3 y=0
  ble/test 'ble/canvas/trace-text "これは日本語の文章" nonewline;ret="$x,$y,$ret"' ret='2,2,これは 日本語の文章'

  # 行末での改行 (nonewline)
  lines=3 cols=10 _ble_term_xenl=1 x=0 y=0
  ble/test 'ble/canvas/trace-text "これは日本";ret="$x,$y,$ret"' ret=$'0,1,これは日本\n'
  lines=3 cols=10 _ble_term_xenl=0 x=0 y=0
  ble/test 'ble/canvas/trace-text "これは日本";ret="$x,$y,$ret"' ret=$'0,1,これは日本'
  lines=3 cols=10 _ble_term_xenl=1 x=0 y=0
  ble/test 'ble/canvas/trace-text "これは日本" nonewline;ret="$x,$y,$ret"' ret=$'10,0,これは日本'
  lines=3 cols=10 _ble_term_xenl=0 x=0 y=0
  ble/test 'ble/canvas/trace-text "これは日本" nonewline;ret="$x,$y,$ret"' ret=$'0,1,これは日本'

  # 改行は ^J と表示
  lines=1 cols=12 _ble_term_xenl=1 x=0 y=0
  ble/test $'ble/canvas/trace-text "あ\nい\nう" external-sgr;ret="$x,$y,$ret"' ret=$'10,0,あ^Jい^Jう'
)

ble/test/end-section

#------------------------------------------------------------------------------

ble/test/start-section 'ble/textmap#update' 5

function ble/test:canvas/textmap {
  local text=$1
  x=0 y=0
  _ble_textmap_length=
  _ble_textmap_pos=()
  _ble_textmap_glyph=()
  _ble_textmap_ichg=()
  _ble_textmap_dbeg=0
  _ble_textmap_dend=${#text}
  _ble_textmap_dend0=0
  ble/textmap#update "$text"
  [[ :$opts: == *:stderr:* ]] &&
    declare -p _ble_textmap_pos >&2
}
(
  ble/test:canvas/textmap $'hello\nworld\ncheck'
  ble/test 'ble/textmap#getxy.out 5; ret=$x,$y' ret='5,0'
  ble/test 'ble/textmap#getxy.out 6; ret=$x,$y' ret='0,1'
  ble/test 'ble/textmap#getxy.out 11; ret=$x,$y' ret='5,1'
  ble/test 'ble/textmap#getxy.out 12; ret=$x,$y' ret='0,2'
  ble/test 'ble/textmap#getxy.out 17; ret=$x,$y' ret='5,2'
)


#------------------------------------------------------------------------------
# Grapheme_Cluster_Break

ble/test/start-section 'ble/unicode/GraphemeCluster/c2break' 72

(
  bleopt emoji_opts=ri:tpvs:epvs:zwj
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x20))' ret="$_ble_unicode_GraphemeClusterBreak_Other"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x41))' ret="$_ble_unicode_GraphemeClusterBreak_Other"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x7E))' ret="$_ble_unicode_GraphemeClusterBreak_Other"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x00))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x0d))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x0a))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1F))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x80))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x9F))' ret="$_ble_unicode_GraphemeClusterBreak_Control"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x0308))' ret="$_ble_unicode_GraphemeClusterBreak_Extend"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x200C))' ret="$_ble_unicode_GraphemeClusterBreak_Extend" # ZWNJ
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x200D))' ret="$_ble_unicode_GraphemeClusterBreak_ZWJ"    # ZWJ
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x0600))' ret="$_ble_unicode_GraphemeClusterBreak_Prepend"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x0605))' ret="$_ble_unicode_GraphemeClusterBreak_Prepend"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x06DD))' ret="$_ble_unicode_GraphemeClusterBreak_Prepend"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x110BD))' ret="$_ble_unicode_GraphemeClusterBreak_Prepend"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xE33))' ret="$_ble_unicode_GraphemeClusterBreak_SpacingMark" # THAI CHARACTER SARA AM
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xEB3))' ret="$_ble_unicode_GraphemeClusterBreak_SpacingMark" # LAO VOWEL SIGN AM
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1100))' ret="$_ble_unicode_GraphemeClusterBreak_L"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x115F))' ret="$_ble_unicode_GraphemeClusterBreak_L"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xA960))' ret="$_ble_unicode_GraphemeClusterBreak_L"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xA97C))' ret="$_ble_unicode_GraphemeClusterBreak_L"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1160))' ret="$_ble_unicode_GraphemeClusterBreak_V"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x11A2))' ret="$_ble_unicode_GraphemeClusterBreak_V"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xD7B0))' ret="$_ble_unicode_GraphemeClusterBreak_V"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xD7C6))' ret="$_ble_unicode_GraphemeClusterBreak_V"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x11A8))' ret="$_ble_unicode_GraphemeClusterBreak_T"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x11F9))' ret="$_ble_unicode_GraphemeClusterBreak_T"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xD7CB))' ret="$_ble_unicode_GraphemeClusterBreak_T"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xD7FB))' ret="$_ble_unicode_GraphemeClusterBreak_T"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xAC00))' ret="$_ble_unicode_GraphemeClusterBreak_LV"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xAC1C))' ret="$_ble_unicode_GraphemeClusterBreak_LV"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xAC38))' ret="$_ble_unicode_GraphemeClusterBreak_LV"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xAC01))' ret="$_ble_unicode_GraphemeClusterBreak_LVT"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0xAC04))' ret="$_ble_unicode_GraphemeClusterBreak_LVT"
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1F1E6))' ret="$_ble_unicode_GraphemeClusterBreak_Regional_Indicator" # RI A
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1F1FF))' ret="$_ble_unicode_GraphemeClusterBreak_Regional_Indicator" # RI Z
  ble/test 'ble/unicode/GraphemeCluster/c2break $((0x1F32B))' ret="$_ble_unicode_GraphemeClusterBreak_Pictographic"

  if ((_ble_bash>=40200)); then
    # Regional_Indicator
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F1E6\U1F1FF\U1F1E6\U1F1FF" 1' ret="0"
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F1E6\U1F1FF\U1F1E6\U1F1FF" 2' ret="0"
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F1E6\U1F1FF\U1F1E6\U1F1FF" 3' ret="2"
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F1E6\U1F1FF\U1F1E6\U1F1FF" 4' ret="2"
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F1E6\U1F1FF\U1F1E6\U1F1FF" 5' ret="4"
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 2' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 3' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 4' ret=3
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 5' ret=3
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 6' ret=5
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6" 7' ret=6
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\U1F1E6\U1F1FF\U1F1E6\U1F1FF\U1F1E6Z" 7' ret=6
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\u600\u600\u600\u600\U1F1E6\U1F1FF" 7' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "A\u600\u600\u600\u600\U1F1E6\U1F1FF" 6' ret=1
    ble/test $'bleopt_grapheme_cluster=legacy ble/unicode/GraphemeCluster/find-previous-boundary "A\u600\u600\u600\u600\U1F1E6\U1F1FF" 7' ret=5
    ble/test $'bleopt_grapheme_cluster=legacy ble/unicode/GraphemeCluster/find-previous-boundary "A\u600\u600\u600\u600\U1F1E6\U1F1FF" 6' ret=5

    # ZWJ sequence
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F636\U200D\U1F32B\UFE0F" 1' ret=0
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F636\U200D\U1F32B\UFE0F" 2' ret=0
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F636\U200D\U1F32B\UFE0F" 3' ret=0
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F636\U200D\U1F32B\UFE0F" 4' ret=0
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "\U1F636\U200D\U1F32B\UFE0F" 5' ret=4
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U1F636\U200D\U1F32B\UFE0F" 2' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U1F636\U200D\U1F32B\UFE0F" 3' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U1F636\U200D\U1F32B\UFE0F" 4' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U1F636\U200D\U1F32B\UFE0F" 5' ret=1
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U1F636\U200D\U1F32B\UFE0F" 6' ret=5
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U200D\U1F32B\UFE0F" 2' ret=0
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U200D\U1F32B\UFE0F" 3' ret=2
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U200D\U1F32B\UFE0F" 4' ret=2
    ble/test $'ble/unicode/GraphemeCluster/find-previous-boundary "a\U200D\U1F32B\UFE0F" 5' ret=4

    ble/test "ble/test:canvas/textmap \$'@@'                   stderr; ble/textmap#get-index-at -v ret 1 0" ret=1
    ble/test "ble/test:canvas/textmap \$'@\u0308@'             stderr; ble/textmap#get-index-at -v ret 1 0" ret=2
    ble/test "ble/test:canvas/textmap \$'@\u0308\u0308@'       stderr; ble/textmap#get-index-at -v ret 1 0" ret=3
    ble/test "ble/test:canvas/textmap \$'@\u0308\u0308\u0308@' stderr; ble/textmap#get-index-at -v ret 1 0" ret=4
  fi
)

ble/test/start-section 'ble/unicode/GraphemeCluster/c2break (GraphemeBreakTest.txt)' 3251
(
  bleopt emoji_opts=ri:tpvs:epvs:zwj
  tests_cases=(
#%< test-canvas.GraphemeClusterTest.sh
  )

  function ble/test:canvas/GraphemeClusterBreak/find-previous-boundary {
    local ans=${1%%:*} str=${1#*:}
    ble/string#split ans , "$ans"
    local i=0 b=0
    for k in "${!ans[@]}"; do
      ble/test "ble/unicode/GraphemeCluster/find-previous-boundary \$'$str' $((k+1))" ret=${ans[k]}
      if ((ans[k]>b)); then
        local ret= c= w= cs= extend=
        ble/test "ble/unicode/GraphemeCluster/match \$'$str' $b && ((ret=b+1+extend))" ret=${ans[k]}
        ((b=ans[k]))
      fi
    done
  }
  for spec in "${tests_cases[@]}"; do
    ble/test:canvas/GraphemeClusterBreak/find-previous-boundary "$spec"
  done
)

ble/test/end-section
