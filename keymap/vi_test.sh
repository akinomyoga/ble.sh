#!/bin/bash

## @var[out] str ind mark
function ble/keymap:vi_test/decompose-state {
  local spec=$1
  ind=${spec%%:*} str=${spec#*:}
  if ((${#ind}==1)) && [[ $ind == [!0-9a-zA-Z] ]]; then
    ind=${str%%"$ind"*} ind=${#ind} str=${str::ind}${str:ind+1}
    mark=
  elif ((${#ind}==2)) && [[ ${ind::1} == [!0-9a-zA-Z] && ${ind:1:1} == [!0-9a-zA-Z] ]]; then
    local ind1=${ind::1} ind2=${ind:1:1} text
    text=${str//"$ind2"} text=${text%%"$ind1"*} ind=${#text}
    text=${str//"$ind1"} text=${text%%"$ind2"*} mark=${#text}
    str=${str//["$ind"]*}
  fi
}

function ble/keymap:vi_test/start-section {
  section=$1 nsuccess=0 ntest=0
}

function ble/keymap:vi_test/check {
  local id=$1 initial=$2 kspecs=$3 final=$4
  local str ind mark
  ble/keymap:vi_test/decompose-state "$initial"; local i=$ind in=$str ima=$mark
  ble/keymap:vi_test/decompose-state "$final"; local f=$ind fin=$str fma=$mark
  
  local nl=$'\n' nl_rep=$'\e[7m^J\e[m'
  ble-edit/content/reset "$in" edit
  _ble_edit_ind=$i
  [[ $ima ]] && _ble_edit_mark=$ima
  local ret
  ble-decode-kbd "$kspecs"
  local ble_decode=${_ble_keymap_vi_test_ble_decode:-ble-decode-key}
  "$ble_decode" $ret &>/dev/null

  # check results
  [[ $_ble_edit_ind == "$f" && $_ble_edit_str == "$fin" && ( ! $fma || $_ble_edit_mark == "$fma" ) ]]; local ext=$?
  if ((ext==0)); then
    ((ntest++,nsuccess++))
  else
    ((ntest++))
    local esc_in=${in//$nl/"$nl_rep"}
    local esc_fin=${fin//$nl/"$nl_rep"}
    local esc_str=${_ble_edit_str//$nl/"$nl_rep"}
    ble/util/print "test($section/$id): keys = ($kspecs)"
    ble/util/print "  initial  = \"$i:$esc_in\""
    ble/util/print "  expected = \"$f:$esc_fin\""
    ble/util/print "  result   = \"$_ble_edit_ind:$esc_str\""
  fi >&2

  # restore states
  case $_ble_decode_keymap in
  (vi_[ixo]map)
    ble-decode-key "$((_ble_decode_Ctrl|99))" &>/dev/null ;;
  esac

  return "$ext"
}

function ble/keymap:vi_test/show-summary {
  local title=$section
  if ((nsuccess==ntest)); then
    local tip=$'\e[32mpassed\e[m'
  else
    local tip=$'\e[31mfailed\e[m'
  fi
  ble/util/print "# $title test: result $((nsuccess))/$((ntest)) $tip"
}

#------------------------------------------------------------------------------
# tests

function ble/widget/vi-command:check-vi-mode/space {
  ble/keymap:vi_test/start-section '<space>'

  local str=$'    1234\n567890ab\n'
  ble/keymap:vi_test/check 1 "4:$str" '4 SP' "9:$str"
  ble/keymap:vi_test/check 2 "4:$str" 'd 4 SP' $'3:    \n567890ab\n'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/cw {
  ble/keymap:vi_test/start-section 'cw'

  # provided by cmplstofB
  ble/keymap:vi_test/check A1 '@:cp ./foo.txt   @        /tmp/' 'c w' '@:cp ./foo.txt   @/tmp/'
  ble/keymap:vi_test/check A2 '@:cp ./foo.tx@t           /tmp/' 'c w' '@:cp ./foo.tx@           /tmp/'
  ble/keymap:vi_test/check A3 '@:cp ./fo@o.txt           /tmp/' 'c w' '@:cp ./fo@.txt           /tmp/'
  ble/keymap:vi_test/check A4 '@:cp ./foo.t@xt           /tmp/' 'c w' '@:cp ./foo.t@           /tmp/'
  ble/keymap:vi_test/check A5 '@:cp ./fo@o.txt           /tmp/' 'c W' '@:cp ./fo@           /tmp/'

  ble/keymap:vi_test/check B1a '@:123@   456    789' 'c w'   '@:123@456    789'
  ble/keymap:vi_test/check B1b '@:123@   456    789' '1 c w' '@:123@456    789'
  ble/keymap:vi_test/check B1c '@:123@   456    789' '2 c w' '@:123@789'
  ble/keymap:vi_test/check B2a '@:12@3   456    789' 'c w'   '@:12@   456    789'
  ble/keymap:vi_test/check B2b '@:12@3   456    789' '1 c w' '@:12@   456    789'
  ble/keymap:vi_test/check B2c '@:12@3   456    789' '2 c w' '@:12@    789'
  ble/keymap:vi_test/check B3a '@:@123   456    789' 'c w'   '@:@   456    789'
  ble/keymap:vi_test/check B3b '@:@123   456    789' '1 c w' '@:@   456    789'
  ble/keymap:vi_test/check B3c '@:@123   456    789' '2 c w' '@:@    789'
  ble/keymap:vi_test/check B4a '@:ab@c///漢字' 'c w'   '@:ab@///漢字'
  ble/keymap:vi_test/check B4b '@:ab@c///漢字' '1 c w' '@:ab@///漢字'
  ble/keymap:vi_test/check B4c '@:ab@c///漢字' '2 c w' '@:ab@漢字'
  ble/keymap:vi_test/check B5a '@:@abc///漢字' 'c w'   '@:@///漢字'
  ble/keymap:vi_test/check B5b '@:@abc///漢字' '1 c w' '@:@///漢字'
  ble/keymap:vi_test/check B5c '@:@abc///漢字' '2 c w' '@:@漢字'

  # with empty lines
  ble/keymap:vi_test/check C1 $'@:123 456 @  \n\n789' 'c w' $'@:123 456 @\n\n789'
  ble/keymap:vi_test/check C2 $'@:123 456   \n@\n789' 'c w' $'@:123 456   \n@\n789'
  ble/keymap:vi_test/check C3 $'@:123 45@6   \n\n789' 'c w' $'@:123 45@   \n\n789'
  ble/keymap:vi_test/check C4 $'@:123 456@   \n\n789\nabc' '2 c w' $'@:123 456@\n789\nabc'
  ble/keymap:vi_test/check C5 $'@:123 45@6   \n\n789\nabc' '2 c w' $'@:123 45@\nabc'
  ble/keymap:vi_test/check C6 $'@:123 4@56   \n\n789\nabc' '2 c w' $'@:123 4@\nabc'
  ble/keymap:vi_test/check C7 $'@:123 456@   \n\n\n789\nabc' '2 c w' $'@:123 456@\n\n789\nabc'
  ble/keymap:vi_test/check C8 $'@:123 45@6   \n\n\n789\nabc' '2 c w' $'@:123 45@\nabc'
  ble/keymap:vi_test/check C9 $'@:123 4@56   \n\n\n789\nabc' '2 c w' $'@:123 4@\nabc'
  ble/keymap:vi_test/check C9 $'@:123 456   \n\n@' '2 c w' $'@:123 456   \n\n@'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/search {
  ble/keymap:vi_test/start-section '/ ? n N'
  ble/keymap:vi_test/check A1a '@:ech@o abc abc abc' '/ a b c RET'       '@:echo @abc abc abc'
  ble/keymap:vi_test/check A1b '@:ech@o abc abc abc' '/ a b c RET n'     '@:echo abc @abc abc'
  ble/keymap:vi_test/check A1c '@:ech@o abc abc abc' '/ a b c RET 2 n'   '@:echo abc abc @abc'
  ble/keymap:vi_test/check A1d '@:ech@o abc abc abc' '/ a b c RET 2 n N' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A2a '@:echo@ abc abc abc' '/ a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A2b '@:echo @abc abc abc' '/ a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A2c '@:echo a@bc abc abc' '/ a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A3a '@:echo abc@ abc abc' '? a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A3b '@:echo abc @abc abc' '? a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A3c '@:echo abc a@bc abc' '? a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/increment {
  ble/keymap:vi_test/start-section '<C-a>, <C-x>'

  ble/keymap:vi_test/check A1a '@:@123' 'C-a' '@:12@4'
  ble/keymap:vi_test/check A1b '@:@123' 'C-x' '@:12@2'
  ble/keymap:vi_test/check A1c '@:@-123' 'C-a' '@:-12@2'
  ble/keymap:vi_test/check A1d '@:@-123' 'C-x' '@:-12@4'

  ble/keymap:vi_test/check A2a '@:@ -123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2b '@: @-123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2c '@: -@123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2d '@: -1@23 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2e '@: -12@3 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2f '@: -123@ 0' 'C-a' '@: -123 @1'

  ble/keymap:vi_test/check A3a '@:@000' 'C-a'       '@:00@1'
  ble/keymap:vi_test/check A3b '@:@000' '1 0 C-a'   '@:01@0'
  ble/keymap:vi_test/check A3c '@:@000' '1 0 0 C-a' '@:10@0'
  ble/keymap:vi_test/check A3d '@:@000' 'C-x'       '@:-00@1'
  ble/keymap:vi_test/check A3e '@:@000' '1 0 C-x'   '@:-01@0'
  ble/keymap:vi_test/check A3f '@:@000' '1 0 0 C-x' '@:-10@0'
  ble/keymap:vi_test/check A3g '@:@099' '1 0 0 C-x' '@:-00@1'
  ble/keymap:vi_test/check A3h '@:@099' '9 9 C-x' '@:00@0'

  ble/keymap:vi_test/check A4a '@:-@0' 'C-a' '@:@1'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/macro {
  # enable ble-decode/keylog for automatic ble-decode-key
  local _ble_decode_keylog_depth=0
  local _ble_keymap_vi_test_ble_decode=ble-decode-char
  local ble_decode_char_sync=1
  ble/keymap:vi_test/start-section 'qx..q'
  ble/keymap:vi_test/check A1 '@:@123' 'q a A SP h e l l o @ESC q @ a' '@:123 hello hell@o'
  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/surround {
  ble/keymap:vi_test/start-section 'surround'

  # ys の時は末端の空白を除く
  ble/keymap:vi_test/check A1a '@:abcd @fghi jklm nopq' 'y s e a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1b '@:abcd @fghi jklm nopq' 'y s w a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1c '@:abcd @fghi jklm nopq' 'y s a w a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1d '@:abcd @     jklm nopq' 'y s 3 l a'   '@:abcd @<>     jklm nopq'

  # vS の時は末端の空白は除かない
  ble/keymap:vi_test/check A2a '@:abcd @fghi jklm nopq' 'v 3 l S a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A2b '@:abcd @fghi jklm nopq' 'v 4 l S a'   '@:abcd @<fghi >jklm nopq'
  ble/keymap:vi_test/check A2c '@:abcd @fghi jklm nopq' 'h v 5 l S a' '@:abcd@< fghi >jklm nopq'

  ble/keymap:vi_test/show-summary
}
function ble/widget/vi-command:check-vi-mode/xmap_txtobj_quote {
  ble/keymap:vi_test/start-section 'xmap text object i" a"'

  # A. xmap txtobj i"/a"、開始点と終了点が同じとき

  # A1. 様々な位置で実行した時
  ble/keymap:vi_test/check A1a '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1b '@:abcd @" fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd " fghi "@< jklm >" nopq " rstu " vwxyz'
  # A2. 引数が指定された時、a" が指定された時
  ble/keymap:vi_test/check A2a '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A2b '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v a " S a'   '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A2c '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v 2 a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  # A3. "" の中が空の時
  ble/keymap:vi_test/check A3a '@:ab@cd "" jklm " nopq " rstu " vwxyz' 'v i " S a'   '@:abcd @<""> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A3b '@:ab@cd "" jklm " nopq " rstu " vwxyz' 'v 2 i " S a' '@:abcd @<""> jklm " nopq " rstu " vwxyz'

  # B. xmap txtobj i"/a"、mark より現在位置の方が後のとき
  # B1. i"
  ble/keymap:vi_test/check B1a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd@< " fghi " jklm >" nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi " jklm " nopq@< " rstu >" vwxyz'
  ble/keymap:vi_test/check B1c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi " jklm "@< nopq >" rstu " vwxyz'
  ble/keymap:vi_test/check B1f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi "@< jklm " nopq >" rstu " vwxyz'
  # B2. 2i"
  ble/keymap:vi_test/check B2a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd@< " fghi " jklm "> nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi " jklm " nopq@< " rstu "> vwxyz'
  ble/keymap:vi_test/check B2c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi " jklm @<" nopq "> rstu " vwxyz'
  ble/keymap:vi_test/check B2f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi "@< jklm " nopq "> rstu " vwxyz'
  # B3. a"
  ble/keymap:vi_test/check B3a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd@< " fghi " jklm " >nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi " jklm " nopq@< " rstu " >vwxyz'
  ble/keymap:vi_test/check B3c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi " jklm @<" nopq " >rstu " vwxyz'
  ble/keymap:vi_test/check B3f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi "@< jklm " nopq " >rstu " vwxyz'

  # C. xmap txtobj i"/a"、mark より現在位置の方が前のとき
  ble/keymap:vi_test/check C1a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h i " S a' '@:abcd "@< fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/check C2a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h 2 i " S a' '@:abcd @<" fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/check C3a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h a " S a' '@:abcd @<" fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/txtobj_word {
  ble/keymap:vi_test/start-section 'txtobj word omap'

  # A. omap iw/aw
  ble/keymap:vi_test/check A1/iw  '@:echo he@llo world "hello" "world"' 'd i w' '@:echo @ world "hello" "world"'
  ble/keymap:vi_test/check A1/aw  '@:echo he@llo world "hello" "world"' 'd a w' '@:echo @world "hello" "world"'
  ble/keymap:vi_test/check A2/iw  '@:echo hello@ world "hello" "world"' 'd i w' '@:echo hello@world "hello" "world"'
  ble/keymap:vi_test/check A2/aw  '@:echo hello@ world "hello" "world"' 'd a w' '@:echo hello@ "hello" "world"'
  ble/keymap:vi_test/check A3/iw  '@:echo hello world "he@llo" "world"' 'd i w' '@:echo hello world "@" "world"'
  ble/keymap:vi_test/check A3/aw  '@:echo hello world "he@llo" "world"' 'd a w' '@:echo hello world "@" "world"'
  ble/keymap:vi_test/check A4/iw  '@:echo hello world @"hello" "world"' 'd i w' '@:echo hello world @hello" "world"'
  ble/keymap:vi_test/check A4/aw  '@:echo hello world @"hello" "world"' 'd a w' '@:echo hello world@hello" "world"'
  ble/keymap:vi_test/check A5/iw  '@:echo hello world "hello@" "world"' 'd i w' '@:echo hello world "hello@ "world"'
  ble/keymap:vi_test/check A5/aw  '@:echo hello world "hello@" "world"' 'd a w' '@:echo hello world "hello@"world"'
  ble/keymap:vi_test/check A1/2iw '@:echo he@llo world "hello" "world"' 'd 2 i w' '@:echo @world "hello" "world"'
  ble/keymap:vi_test/check A1/2aw '@:echo he@llo world "hello" "world"' 'd 2 a w' '@:echo @"hello" "world"'
  ble/keymap:vi_test/check A2/2iw '@:echo hello@ world "hello" "world"' 'd 2 i w' '@:echo hello@ "hello" "world"'
  ble/keymap:vi_test/check A2/2aw '@:echo hello@ world "hello" "world"' 'd 2 a w' '@:echo hello@hello" "world"'
  ble/keymap:vi_test/check A3/2iw '@:echo hello world "he@llo" "world"' 'd 2 i w' '@:echo hello world "@ "world"'
  ble/keymap:vi_test/check A3/2aw '@:echo hello world "he@llo" "world"' 'd 2 a w' '@:echo hello world "@"world"'
  ble/keymap:vi_test/check A4/2iw '@:echo hello world @"hello" "world"' 'd 2 i w' '@:echo hello world @" "world"'
  ble/keymap:vi_test/check A4/2aw '@:echo hello world @"hello" "world"' 'd 2 a w' '@:echo hello world@" "world"'
  ble/keymap:vi_test/check A5/2iw '@:echo hello world "hello@" "world"' 'd 2 i w' '@:echo hello world "hello@"world"'
  ble/keymap:vi_test/check A5/2aw '@:echo hello world "hello@" "world"' 'd 2 a w' '@:echo hello world "hello@world"'

  ble/keymap:vi_test/check A6/iw   $'@:echo@ \n hello world' 'd i w' $'@:ech@o\n hello world'
  ble/keymap:vi_test/check A6/aw   $'@:echo@ \n hello world' 'd a w' $'@:echo@ world'

  ble/keymap:vi_test/check A7.2/iw  $'@:echo\n@\nhello\n\nworld\nZ' 'd i w'   $'@:echo\n@\nhello\n\nworld\nZ'
  ble/keymap:vi_test/check A7.2/aw  $'@:echo\n@\nhello\n\nworld\nZ' 'd a w'   $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.2/2iw $'@:echo\n@\nhello\n\nworld\nZ' 'd 2 i w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.2/2aw $'@:echo\n@\nhello\n\nworld\nZ' 'd 2 a w' $'@:echo\n@Z'

  ble/keymap:vi_test/check A7.1/1diw $'@:echo\n@\nhello\nworld\nZ'         'd 1 i w' $'@:echo\n@\nhello\nworld\nZ'
  ble/keymap:vi_test/check A7.1/2diw $'@:echo\n@\nhello\nworld\nZ'         'd 2 i w' $'@:echo\n@world\nZ'
  ble/keymap:vi_test/check A7.1/3diw $'@:echo\n@\nhello\nworld\nZ'         'd 3 i w' $'@:echo\n@Z'
  ble/keymap:vi_test/check A7.2/1diw $'@:echo\n@\nhello\n\nworld\nZ'       'd 1 i w' $'@:echo\n@\nhello\n\nworld\nZ'
  ble/keymap:vi_test/check A7.2/2diw $'@:echo\n@\nhello\n\nworld\nZ'       'd 2 i w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.2/3diw $'@:echo\n@\nhello\n\nworld\nZ'       'd 3 i w' $'@:echo\n@world\nZ'
  ble/keymap:vi_test/check A7.2/4diw $'@:echo\n@\nhello\n\nworld\nZ'       'd 4 i w' $'@:echo\n@Z'
  ble/keymap:vi_test/check A7.3/1diw $'@:echo\n@\nhello\n\n\nworld\nZ'     'd 1 i w' $'@:echo\n@\nhello\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.3/2diw $'@:echo\n@\nhello\n\n\nworld\nZ'     'd 2 i w' $'@:echo\n@\n\nworld\nZ'
  ble/keymap:vi_test/check A7.3/3diw $'@:echo\n@\nhello\n\n\nworld\nZ'     'd 3 i w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.3/4diw $'@:echo\n@\nhello\n\n\nworld\nZ'     'd 4 i w' $'@:echo\n@Z'
  ble/keymap:vi_test/check A7.4/1diw $'@:echo\n@\nhello\n\n\n\nworld\nZ'   'd 1 i w' $'@:echo\n@\nhello\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.4/2diw $'@:echo\n@\nhello\n\n\n\nworld\nZ'   'd 2 i w' $'@:echo\n@\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.4/3diw $'@:echo\n@\nhello\n\n\n\nworld\nZ'   'd 3 i w' $'@:echo\n@\n\nworld\nZ'
  ble/keymap:vi_test/check A7.4/4diw $'@:echo\n@\nhello\n\n\n\nworld\nZ'   'd 4 i w' $'@:echo\n@world\nZ'
  ble/keymap:vi_test/check A7.4/5diw $'@:echo\n@\nhello\n\n\n\nworld\nZ'   'd 5 i w' $'@:echo\n@Z'
  ble/keymap:vi_test/check A7.5/1diw $'@:echo\n@\nhello\n\n\n\n\nworld\nZ' 'd 1 i w' $'@:echo\n@\nhello\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.5/2diw $'@:echo\n@\nhello\n\n\n\n\nworld\nZ' 'd 2 i w' $'@:echo\n@\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.5/3diw $'@:echo\n@\nhello\n\n\n\n\nworld\nZ' 'd 3 i w' $'@:echo\n@\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.5/4diw $'@:echo\n@\nhello\n\n\n\n\nworld\nZ' 'd 4 i w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.5/5diw $'@:echo\n@\nhello\n\n\n\n\nworld\nZ' 'd 5 i w' $'@:echo\n@Z'

  local A7_a=$'@:echo\n@\nhello\n\n\n\n\n\n\n\n\n\nworld\nZ'

  ble/keymap:vi_test/check A7.a/1ciw "$A7_a" 'c 1 i w' $'@:echo\n@\nhello\n\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/2ciw "$A7_a" 'c 2 i w' $'@:echo\n@\n\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/3ciw "$A7_a" 'c 3 i w' $'@:echo\n@\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/4ciw "$A7_a" 'c 4 i w' $'@:echo\n@\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/5ciw "$A7_a" 'c 5 i w' $'@:echo\n@\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/6ciw "$A7_a" 'c 6 i w' $'@:echo\n@\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/7ciw "$A7_a" 'c 7 i w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.a/8ciw "$A7_a" 'c 8 i w' $'@:echo\n@\nZ'

  ble/keymap:vi_test/check A7.a/1diw "$A7_a" 'd 1 i w' $'@:echo\n@\nhello\n\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/2diw "$A7_a" 'd 2 i w' $'@:echo\n@\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/3diw "$A7_a" 'd 3 i w' $'@:echo\n@\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/4diw "$A7_a" 'd 4 i w' $'@:echo\n@\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/5diw "$A7_a" 'd 5 i w' $'@:echo\n@\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/6diw "$A7_a" 'd 6 i w' $'@:echo\n@\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/7diw "$A7_a" 'd 7 i w' $'@:echo\n@world\nZ'
  ble/keymap:vi_test/check A7.a/8diw "$A7_a" 'd 8 i w' $'@:echo\n@Z'

  ble/keymap:vi_test/check A7.a/1caw "$A7_a" 'c 1 a w' $'@:echo\n@\n\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/2caw "$A7_a" 'c 2 a w' $'@:echo\n@\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/3caw "$A7_a" 'c 3 a w' $'@:echo\n@\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/4caw "$A7_a" 'c 4 a w' $'@:echo\n@\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/5caw "$A7_a" 'c 5 a w' $'@:echo\n@\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/6caw "$A7_a" 'c 6 a w' $'@:echo\n@\nZ'

  ble/keymap:vi_test/check A7.a/1daw "$A7_a" 'd 1 a w' $'@:echo\n@\n\n\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/2daw "$A7_a" 'd 2 a w' $'@:echo\n@\n\n\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/3daw "$A7_a" 'd 3 a w' $'@:echo\n@\n\n\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/4daw "$A7_a" 'd 4 a w' $'@:echo\n@\n\n\nworld\nZ'
  ble/keymap:vi_test/check A7.a/5daw "$A7_a" 'd 5 a w' $'@:echo\n@\nworld\nZ'
  ble/keymap:vi_test/check A7.a/6daw "$A7_a" 'd 6 a w' $'@:echo\n@Z'

  ble/keymap:vi_test/check A8.0/2aw $'@:echo\n@\nhello\n\nworld\n'   'd 2 a w' $'@:@echo'
  ble/keymap:vi_test/check A8.2/2aw $'@:  echo\n@\nhello\n\nworld\n' 'd 2 a w' $'@:  @echo'
  ble/keymap:vi_test/check A9.1/ciw $'@:@    \necho'                 'c i w' $'@:@\necho'
  ble/keymap:vi_test/check A9.2/ciw $'@:@\n    echo'                 'c i w' $'@:@\n    echo'

  ble/keymap:vi_test/show-summary

  ble/keymap:vi_test/start-section 'txtobj word xmap'

  # B. xmap iw/aw (mark == ind の時)
  ble/keymap:vi_test/check B1/viw.1  '@:echo he@llo world "hello" "world"' 'v i w S a' '@:echo @<hello> world "hello" "world"'
  ble/keymap:vi_test/check B1/vaw.1  '@:echo he@llo world "hello" "world"' 'v a w S a' '@:echo @<hello >world "hello" "world"'
  ble/keymap:vi_test/check B2/viw.2  '@:echo hello@ world "hello" "world"' 'v i w S a' '@:echo hello@< >world "hello" "world"'
  ble/keymap:vi_test/check B2/vaw.2  '@:echo hello@ world "hello" "world"' 'v a w S a' '@:echo hello@< world> "hello" "world"'
  ble/keymap:vi_test/check B3/viw.3  '@:echo hello world "he@llo" "world"' 'v i w S a' '@:echo hello world "@<hello>" "world"'
  ble/keymap:vi_test/check B3/vaw.3  '@:echo hello world "he@llo" "world"' 'v a w S a' '@:echo hello world "@<hello>" "world"'
  ble/keymap:vi_test/check B4/viw.4  '@:echo hello world @"hello" "world"' 'v i w S a' '@:echo hello world @<">hello" "world"'
  ble/keymap:vi_test/check B4/vaw.4  '@:echo hello world @"hello" "world"' 'v a w S a' '@:echo hello world@< ">hello" "world"'
  ble/keymap:vi_test/check B5/viw.5  '@:echo hello world "hello@" "world"' 'v i w S a' '@:echo hello world "hello@<"> "world"'
  ble/keymap:vi_test/check B5/vaw.5  '@:echo hello world "hello@" "world"' 'v a w S a' '@:echo hello world "hello@<" >"world"'
  ble/keymap:vi_test/check B1/v2iw.1 '@:echo he@llo world "hello" "world"' 'v 2 i w S a' '@:echo @<hello >world "hello" "world"'
  ble/keymap:vi_test/check B1/v2aw.1 '@:echo he@llo world "hello" "world"' 'v 2 a w S a' '@:echo @<hello world >"hello" "world"'
  ble/keymap:vi_test/check B2/v2iw.2 '@:echo hello@ world "hello" "world"' 'v 2 i w S a' '@:echo hello@< world> "hello" "world"'
  ble/keymap:vi_test/check B2/v2aw.2 '@:echo hello@ world "hello" "world"' 'v 2 a w S a' '@:echo hello@< world ">hello" "world"'
  ble/keymap:vi_test/check B3/v2iw.3 '@:echo hello world "he@llo" "world"' 'v 2 i w S a' '@:echo hello world "@<hello"> "world"'
  ble/keymap:vi_test/check B3/v2aw.3 '@:echo hello world "he@llo" "world"' 'v 2 a w S a' '@:echo hello world "@<hello" >"world"'
  ble/keymap:vi_test/check B4/v2iw.4 '@:echo hello world @"hello" "world"' 'v 2 i w S a' '@:echo hello world @<"hello>" "world"'
  ble/keymap:vi_test/check B4/v2aw.4 '@:echo hello world @"hello" "world"' 'v 2 a w S a' '@:echo hello world@< "hello>" "world"'
  ble/keymap:vi_test/check B5/v2iw.5 '@:echo hello world "hello@" "world"' 'v 2 i w S a' '@:echo hello world "hello@<" >"world"'
  ble/keymap:vi_test/check B5/v2aw.5 '@:echo hello world "hello@" "world"' 'v 2 a w S a' '@:echo hello world "hello@<" ">world"'

  # B. xmap iw/aw (ind < mark の時)
  ble/keymap:vi_test/check B2/v1hiw '@:echo  hello  wo@rld' 'v 1 h i w S a' '@:echo  hello  @<wor>ld'
  ble/keymap:vi_test/check B2/v2hiw '@:echo  hello  wo@rld' 'v 2 h i w S a' '@:echo  hello@<  wor>ld'
  ble/keymap:vi_test/check B2/v3hiw '@:echo  hello  wo@rld' 'v 3 h i w S a' '@:echo  hello@<  wor>ld'
  ble/keymap:vi_test/check B2/v4hiw '@:echo  hello  wo@rld' 'v 4 h i w S a' '@:echo  @<hello  wor>ld'
  ble/keymap:vi_test/check B2/v1haw '@:echo  hello  wo@rld' 'v 1 h a w S a' '@:echo  hello@<  wor>ld'
  ble/keymap:vi_test/check B2/v2haw '@:echo  hello  wo@rld' 'v 2 h a w S a' '@:echo  @<hello  wor>ld'
  ble/keymap:vi_test/check B2/v3haw '@:echo  hello  wo@rld' 'v 3 h a w S a' '@:echo  @<hello  wor>ld'
  ble/keymap:vi_test/check B2/v4haw '@:echo  hello  wo@rld' 'v 4 h a w S a' '@:echo@<  hello  wor>ld'
  ble/keymap:vi_test/check B1/v1haw '@:echo he@llo' 'v 1 h a w S a' '@:echo@< hel>lo'
  ble/keymap:vi_test/check B1/v2haw '@:echo he@llo' 'v 2 h a w S a' '@:@<echo hel>lo'
  ble/keymap:vi_test/check B1/v3haw '@:echo he@llo' 'v 3 h a w S a' '@:e@<cho hel>lo'
  ble/keymap:vi_test/check B1/v4haw '@:echo he@llo' 'v 4 h a w S a' '@:e@<cho hel>lo'
  ble/keymap:vi_test/check Bn/viw $'@:@echo hello\necho world'     'v $ o $ i w c' $'@:echo hell@echo world'
  ble/keymap:vi_test/check Bn/viw $'@:@echo hello    \necho world' 'v $ o $ i w c' $'@:echo hello@\necho world'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/op.2018-02-22 {
  ble/keymap:vi_test/start-section 'op.2018-02-22'

  # 行指向のコピー&貼り付け #D0674
  ble/keymap:vi_test/check A0 $'@:12@345\n67890\n' 'y y p' $'@:12345\n@12345\n67890\n'

  # Y 及び yy ではカーソル位置は変化しない。 #D0673
  ble/keymap:vi_test/check B1 $'@:12@345\n67890\n' 'Y' $'@:12@345\n67890\n'
  ble/keymap:vi_test/check B2 $'@:12@345\n67890\n' 'y y' $'@:12@345\n67890\n'

  # blockwise operator d の書き直し #D0673
  ble/keymap:vi_test/check C $'@:\n12@34567\n1あ2345\n12い345\n123う45\n1234え5\n' 'C-v 4 j l d' $'@:\n12@567\n1 345\n12345\n12 45\n12え5\n'

  ble/keymap:vi_test/show-summary
}

#------------------------------------------------------------------------------

function ble/widget/vi-command:check-vi-mode {
  # save
  local original_str=$_ble_edit_str
  local original_ind=$_ble_edit_ind
  local original_mark=$_ble_edit_mark
  local original_mark_active=$_ble_edit_mark_active
  _ble_edit_line_disabled=1 ble/widget/.insert-newline # #D1800 pair=leave-command-layout
  ble/util/buffer.flush >&2

  local section ntest nsuccess

  #----------------------------------------------------------------------------

  ble/widget/vi-command:check-vi-mode/space
  ble/widget/vi-command:check-vi-mode/cw
  ble/widget/vi-command:check-vi-mode/search
  ble/widget/vi-command:check-vi-mode/increment
  ble/widget/vi-command:check-vi-mode/macro
  ble/widget/vi-command:check-vi-mode/surround
  ble/widget/vi-command:check-vi-mode/xmap_txtobj_quote
  ble/widget/vi-command:check-vi-mode/op.2018-02-22
  ble/widget/vi-command:check-vi-mode/txtobj_word

  #----------------------------------------------------------------------------

  # restore
  ble-edit/content/reset "$original_str" edit
  _ble_edit_ind=$original_ind
  _ble_edit_mark=$original_mark
  _ble_edit_mark_active=$original_mark_active
  ble/edit/leave-command-layout # #D1800 pair=.insert-newline
  return 0
}

function ble/widget/vi_imap/check-vi-mode {
  ble/widget/vi_imap/normal-mode
  ble/widget/vi-command:check-vi-mode
  return 0
}

ble-bind -m vi_imap -f 'C-\ C-\' vi_imap/check-vi-mode
ble-bind -m vi_nmap -f 'C-\ C-\' vi-command:check-vi-mode
