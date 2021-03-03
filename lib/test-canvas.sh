#!/bin/bash

ble-import lib/core-test

_ble_test_canvas_contra=
if [[ -x ext/contra ]]; then
  _ble_test_canvas_contra=ext/contra
elif [[ $(printf 'hello world' | contra test 5 2) == $' worl\nd    ' ]]; then
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

ble/test/start-section 'ble/canvas/trace (relative:confine:measure-bbox)' 10

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
ble/test '[[ $x1-$x2:$y1-$y2 == 3-8:2-4 ]]'

ble/test:canvas/trace.contra 10:2 日本語 measure-bbox << EOF
日本語    $
          $
EOF
ble/test '[[ $x1-$x2:$y1-$y2 == 0-6:0-1 ]]'

ble/test:canvas/trace.contra 10:2 $'hello\eDworld' measure-bbox << EOF
hello     $
     world$
EOF
ble/test '[[ $x1-$x2:$y1-$y2 == 0-10:0-2 ]]'

ble/test:canvas/trace.contra 10:2 $'hello\eMworld' measure-bbox << EOF
     world$
hello     $
EOF
ble/test '[[ $x1-$x2:$y1-$y2 == 0-10:-1-1 ]]'


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
  ble/test --depth=1 \
           'ble/canvas/flush.draw | ext/contra test 40 15' \
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
ble/test '[[ bbox:$x1,$y1-$x2,$y2 == bbox:0,0-30,3 ]]'
ble/test '[[ gbox:$gx1,$gy1-$gx2,$gy2 == gbox:20,0-30,3 ]]'

ble/test:canvas/trace.contra 30:3 $'hello\n2021-01-01\nA' center:measure-bbox:measure-gbox << EOF
            hello             $
          2021-01-01          $
              A               $
EOF
ble/test '[[ bbox:$x1,$y1-$x2,$y2 == bbox:0,0-20,3 ]]'
ble/test '[[ gbox:$gx1,$gy1-$gx2,$gy2 == gbox:10,0-20,3 ]]'

ble/test:canvas/trace.contra 10:1 $'xyz\e[4Daxyz' relative:measure-bbox x=3 << EOF
  axyz    $
EOF
ble/test '[[ bbox:$x1,$y1-$x2,$y2 == bbox:2,0-6,1 ]]'

ble/test/end-section
