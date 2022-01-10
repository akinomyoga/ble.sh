# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test

ble/test/start-section 'ble/decode' 33

# ble/builtin/bind/.parse-keyname
(
  # valid cases
  ble/test 'ble/builtin/bind/.parse-keyname tab    ; ret=${chars[0]}' ret=9
  ble/test 'ble/builtin/bind/.parse-keyname TAB    ; ret=${chars[0]}' ret=9
  ble/test 'ble/builtin/bind/.parse-keyname newline; ret=${chars[0]}' ret=10
  ble/test 'ble/builtin/bind/.parse-keyname LFD    ; ret=${chars[0]}' ret=10
  ble/test 'ble/builtin/bind/.parse-keyname Return ; ret=${chars[0]}' ret=13
  ble/test 'ble/builtin/bind/.parse-keyname RET    ; ret=${chars[0]}' ret=13
  ble/test 'ble/builtin/bind/.parse-keyname Space  ; ret=${chars[0]}' ret=32
  ble/test 'ble/builtin/bind/.parse-keyname SPC    ; ret=${chars[0]}' ret=32
  ble/test 'ble/builtin/bind/.parse-keyname Rubout ; ret=${chars[0]}' ret=127
  ble/test 'ble/builtin/bind/.parse-keyname DEL   ; ret=${chars[0]}' ret=127
  ble/test 'ble/builtin/bind/.parse-keyname Escape ; ret=${chars[0]}' ret=27
  ble/test 'ble/builtin/bind/.parse-keyname ESC    ; ret=${chars[0]}' ret=27
  ble/test 'ble/builtin/bind/.parse-keyname C-Space; ret=${chars[0]}' ret=0
  ble/test 'ble/builtin/bind/.parse-keyname s      ; ret=${chars[0]}' ret=115
  ble/test 'ble/builtin/bind/.parse-keyname S      ; ret=${chars[0]}' ret=83

  # invalid cases
  ble/test "ble/builtin/bind/.parse-keyname '\C-x\C-y'     ; ret=\${chars[0]}" ret=25  # C-y
  ble/test "ble/builtin/bind/.parse-keyname 'xyz'          ; ret=\${chars[0]}" ret=120 # x
  ble/test "ble/builtin/bind/.parse-keyname '\a'           ; ret=\${chars[0]}" ret=92  # \ (backslash)
  ble/test "ble/builtin/bind/.parse-keyname '\C-nop'       ; ret=\${chars[0]}" ret=14  # C-n
  ble/test "ble/builtin/bind/.parse-keyname '\C-xC-y'      ; ret=\${chars[0]}" ret=25  # C-y
  ble/test "ble/builtin/bind/.parse-keyname '\C-axC-b'     ; ret=\${chars[0]}" ret=2   # C-b
  ble/test "ble/builtin/bind/.parse-keyname 'helloC-b'     ; ret=\${chars[0]}" ret=2   # C-b
  ble/test "ble/builtin/bind/.parse-keyname 'helloC-x,TAB' ; ret=\${chars[0]}" ret=24  # C-x
  ble/test "ble/builtin/bind/.parse-keyname 'C-xTAB'       ; ret=\${chars[0]}" ret=24  # C-x
  ble/test "ble/builtin/bind/.parse-keyname 'TABC-x'       ; ret=\${chars[0]}" ret=24  # C-x
  ble/test "ble/builtin/bind/.parse-keyname 'BC-'          ; ret=\${chars[0]}" ret=0   # C-@
  ble/test "ble/builtin/bind/.parse-keyname 'C-M-a'        ; ret=\${chars[0]}" ret=129 # C-M-a
  ble/test "ble/builtin/bind/.parse-keyname 'M-C-a'        ; ret=\${chars[0]}" ret=129 # C-M-a
  ble/test "ble/builtin/bind/.parse-keyname 'C-aalpha-beta'; ret=\${chars[0]}" ret=2   # C-b
  ble/test "ble/builtin/bind/.parse-keyname '\C-a\M-c'     ; ret=\${chars[0]}" ret=131 # C-M-c
  ble/test "ble/builtin/bind/.parse-keyname 'panic-trim-c' ; ret=\${chars[0]}" ret=131 # C-M-c
  ble/test "ble/builtin/bind/.parse-keyname 'C--'          ; ret=\${chars[0]}" ret=0   # C-@
  ble/test "ble/builtin/bind/.parse-keyname 'C--x'         ; ret=\${chars[0]}" ret=24  # C-x
)

ble/test/end-section
