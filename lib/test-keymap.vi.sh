# -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test
ble-import lib/keymap.vi
ble-import lib/vim-surround

## @var[out] str ind mark
function ble/keymap:vi_test/decompose-state {
  local spec=$1
  ind=${spec%%:*} str=${spec#*:}
  if ((${#ind}==1)) && [[ $ind == [!a-zA-Z0-9] ]]; then
    ind=${str%%"$ind"*} ind=${#ind} str=${str::ind}${str:ind+1}
    mark=
  elif ((${#ind}==2)) && [[ ${ind::1} == [!a-zA-Z0-9] && ${ind:1:1} == [!a-zA-Z0-9] ]]; then
    local ind1=${ind::1} ind2=${ind:1:1} text
    text=${str//"$ind2"} text=${text%%"$ind1"*} ind=${#text}
    text=${str//"$ind1"} text=${text%%"$ind2"*} mark=${#text}
    str=${str//["$ind"]*}
  fi
}

function ble/keymap:vi_test/start-section {
  ble/test/start-section "ble/keymap.vi/$1" "$2"
}

function ble/keymap:vi_test/check {
  local id=$1 initial=$2 kspecs=$3 final=$4
  local str ind mark
  ble/keymap:vi_test/decompose-state "$initial"; local i=$ind in=$str ima=$mark
  ble/keymap:vi_test/decompose-state "$final"; local f=$ind fin=$str fma=$mark
  
  local nl=$'\n' nl_rep=$'\e[7m^J\e[27m'
  ble-edit/content/reset "$in" edit
  _ble_edit_ind=$i
  [[ $ima ]] && _ble_edit_mark=$ima
  local ret
  ble-decode-kbd "$kspecs"
  ble/string#split-words ret "$ret"
  local ble_decode=${_ble_keymap_vi_test_ble_decode:-ble-decode-key}
  "$ble_decode" "${ret[@]}" &>/dev/null

  # construct result
  local esc_in=${in//$nl/"$nl_rep"}
  local section=${_ble_test_section_title#'ble/keymap.vi/'}
  local title="$section/$id i=$i${ima:+ m=$ima} str=$esc_in keys=($kspecs)"
  local ind_expect=ind=$f
  local ind_result=ind=$_ble_edit_ind
  if [[ $fma ]]; then
    ind_expect=$ind_expect,mark=$fma
    ind_result=$ind_result,mark=$_ble_edit_mark
  fi
  local str_expect=$fin
  local str_result=$_ble_edit_str

  ble/test --display-code="$title" ret="$ind_expect" stdout="$str_expect[EOF]" \
           code:'ret=$ind_result; ble/util/put "$str_result[EOF]"'
  local ext=$?

  # restore states
  case $_ble_decode_keymap in
  (vi_[ixo]map)
    ble-decode-key "$((_ble_decode_Ctrl|99))" &>/dev/null ;;
  esac

  return "$ext"
}

#------------------------------------------------------------------------------
# tests

# <space>
function ble/keymap:vi_test/section:space {
  ble/test/start-section "ble/keymap.vi/space" 2

  local str=$'    1234\n567890ab\n'
  ble/keymap:vi_test/check 1 "4:$str" '4 SP' "9:$str"
  ble/keymap:vi_test/check 2 "4:$str" 'd 4 SP' $'3:    \n567890ab\n'

  ble/test/end-section
}

# cw
function ble/keymap:vi_test/section:cw {
  ble/test/start-section "ble/keymap.vi/cw" 30

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

  ble/test/end-section
}


# / ? n N
function ble/keymap:vi_test/section:search {
  ble/test/start-section "ble/keymap.vi/search" 10
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
  ble/test/end-section
}

# <C-a>, <C-x>
function ble/keymap:vi_test/section:increment {
  ble/test/start-section "ble/keymap.vi/increment" 19

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

  ble/test/end-section
}

# qx..q
function ble/keymap:vi_test/section:macro {
  # enable ble-decode/keylog for automatic ble-decode-key
  local _ble_decode_keylog_depth=0
  local _ble_keymap_vi_test_ble_decode=ble-decode-char
  local ble_decode_char_sync=1
  ble/function#push ble/util/is-stdin-ready '((0))'

  ble/test/start-section "ble/keymap.vi/macro" 1
  ble/keymap:vi_test/check A1 '@:@123' 'q a A SP h e l l o @ESC q @ a' '@:123 hello hell@o'
  ble/test/end-section
}

function ble/keymap:vi_test/section:surround {
  ble/test/start-section "ble/keymap.vi/surround" 7

  # ys の時は末端の空白を除く
  ble/keymap:vi_test/check A1a '@:abcd @fghi jklm nopq' 'y s e a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1b '@:abcd @fghi jklm nopq' 'y s w a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1c '@:abcd @fghi jklm nopq' 'y s a w a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1d '@:abcd @     jklm nopq' 'y s 3 l a'   '@:abcd @<>     jklm nopq'

  # vS の時は末端の空白は除かない
  ble/keymap:vi_test/check A2a '@:abcd @fghi jklm nopq' 'v 3 l S a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A2b '@:abcd @fghi jklm nopq' 'v 4 l S a'   '@:abcd @<fghi >jklm nopq'
  ble/keymap:vi_test/check A2c '@:abcd @fghi jklm nopq' 'h v 5 l S a' '@:abcd@< fghi >jklm nopq'

  ble/test/end-section
}

# (xmap) i" a"
function ble/keymap:vi_test/section:txtobj_quote_xmap {
  ble/test/start-section "ble/keymap.vi/txtobj_quote_xmap" 45

  # A. xmap txtobj i"/a"、開始点と終了点が同じとき

  # A1. 様々な位置で実行した時
  ble/keymap:vi_test/check A1a '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1b '@:abcd @" fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
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

  ble/test/end-section
}

# (omap) ib ab
function ble/keymap:vi_test/section:txtobj_block_omap {
  ble/test/start-section "ble/keymap.vi/txtobj_block_omap" 41

  ble/keymap:vi_test/check A1a '@:echo @foo ( bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1b '@:echo foo@ ( bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1c '@:echo foo @( bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1d '@:echo foo (@ bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1e '@:echo foo ( @bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1f '@:echo foo ( bar@ ) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1g '@:echo foo ( bar @) baz (hello) world (vim) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check A1h '@:echo foo ( bar )@ baz (hello) world (vim) xxxx' 'd i b' '@:echo foo ( bar ) baz (@) world (vim) xxxx'
  ble/keymap:vi_test/check A1i '@:echo foo ( bar ) @baz (hello) world (vim) xxxx' 'd i b' '@:echo foo ( bar ) baz (@) world (vim) xxxx'
  ble/keymap:vi_test/check A1i '@:echo foo ( bar ) baz (hello) world (vim@) xxxx' 'd i b' '@:echo foo ( bar ) baz (hello) world (@) xxxx'
  ble/keymap:vi_test/check A1i '@:echo foo ( bar ) baz (hello) world (vim)@ xxxx' 'd i b' '@:echo foo ( bar ) baz (hello) world (vim)@ xxxx'
  ble/keymap:vi_test/check A1i '@:echo foo ( bar ) baz (hello) world (vim) @xxxx' 'd i b' '@:echo foo ( bar ) baz (hello) world (vim) @xxxx'

  ble/keymap:vi_test/check B1a '@:echo ( @foo ( bar ) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B1b '@:echo ( foo @( bar ) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo ( foo (@) baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B1c '@:echo ( foo ( @bar ) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo ( foo (@) baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B1d '@:echo ( foo ( bar @) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo ( foo (@) baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B1e '@:echo ( foo ( bar )@ baz (hello) world (vim) ) xxxx' 'd i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B1f '@:echo ( foo ( bar ) baz@ (hello) world (vim) ) xxxx' 'd i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B1g '@:echo ( foo ( bar ) baz @(hello) world (vim) ) xxxx' 'd i b' '@:echo ( foo ( bar ) baz (@) world (vim) ) xxxx'
  ble/keymap:vi_test/check B2a '@:echo ( @foo ( bar ) baz (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo ( @foo ( bar ) baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B2b '@:echo ( foo @( bar ) baz (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B2c '@:echo ( foo ( @bar ) baz (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B2d '@:echo ( foo ( bar @) baz (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo (@) xxxx'
  ble/keymap:vi_test/check B2e '@:echo ( foo ( bar )@ baz (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo ( foo ( bar )@ baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B2f '@:echo ( foo ( bar ) baz@ (hello) world (vim) ) xxxx' 'd 2 i b' '@:echo ( foo ( bar ) baz@ (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check B2g '@:echo ( foo ( bar ) baz @(hello) world (vim) ) xxxx' 'd 2 i b' '@:echo (@) xxxx'

  ble/keymap:vi_test/check C1a '@:echo ( @foo ( bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo ( @foo ( bar ) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check C1b '@:echo ( foo (@ bar ) baz (hello) world (vim) xxxx' 'd i b' '@:echo ( foo (@) baz (hello) world (vim) xxxx'
  ble/keymap:vi_test/check C2a '@:echo @foo ( bar ) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) ) xxxx'
  ble/keymap:vi_test/check C2b '@:echo foo (@ bar ) baz (hello) world (vim) ) xxxx' 'd i b' '@:echo foo (@) baz (hello) world (vim) ) xxxx'

  ble/keymap:vi_test/check D1a '@:echo @vim) test ( quick ) world ( foo )' 'd i b' '@:echo @vim) test ( quick ) world ( foo )'
  ble/keymap:vi_test/check D1a '@:echo vi@m) test ( quick ) world ( foo )' 'd i b' '@:echo vi@m) test ( quick ) world ( foo )'
  ble/keymap:vi_test/check D1a '@:echo vim@) test ( quick ) world ( foo )' 'd i b' '@:echo vim) test (@) world ( foo )'
  ble/keymap:vi_test/check D1a '@:echo vim) @test ( quick ) world ( foo )' 'd i b' '@:echo vim) test (@) world ( foo )'
  ble/keymap:vi_test/check D1a '@:echo vim) test @( quick ) world ( foo )' 'd i b' '@:echo vim) test (@) world ( foo )'

  ble/keymap:vi_test/check E1a '@:echo @foo () bar' 'd i b' '@:echo foo (@) bar'
  ble/keymap:vi_test/check E1b '@:echo foo @() bar' 'd i b' '@:echo foo (@) bar'
  ble/keymap:vi_test/check E1c '@:echo foo (@) bar' 'd i b' '@:echo foo (@) bar'
  ble/keymap:vi_test/check E1d '@:echo @foo () bar' 'd a b' '@:echo foo @ bar'
  ble/keymap:vi_test/check E1e '@:echo foo @() bar' 'd a b' '@:echo foo @ bar'
  ble/keymap:vi_test/check E1f '@:echo foo (@) bar' 'd a b' '@:echo foo @ bar'

  ble/test/end-section
}

# (xmap) ib ab
function ble/keymap:vi_test/section:txtobj_block_xmap {
  ble/test/start-section "ble/keymap.vi/txtobj_block_xmap" 145

  # xmap txtobj i"/a"、開始点と終了点が同じとき

  # 様々な位置で実行した時
  ble/keymap:vi_test/check A1a '@:echo @( foo ) bar ( baz ) hello ( vim ) world' 'v i b S a' '@:echo (@< foo >) bar ( baz ) hello ( vim ) world'
  ble/keymap:vi_test/check A1b '@:echo ( @foo ) bar ( baz ) hello ( vim ) world' 'v i b S a' '@:echo (@< foo >) bar ( baz ) hello ( vim ) world'
  ble/keymap:vi_test/check A1c '@:echo ( foo @) bar ( baz ) hello ( vim ) world' 'v i b S a' '@:echo (@< foo >) bar ( baz ) hello ( vim ) world'
  ble/keymap:vi_test/check A1d '@:echo ( foo ) @bar ( baz ) hello ( vim ) world' 'v i b S a' '@:echo ( foo ) bar (@< baz >) hello ( vim ) world'
  ble/keymap:vi_test/check A1e '@:echo ( foo ) bar ( baz ) hello ( vim ) @world' 'v i b S a' '@:echo ( foo ) bar ( baz ) hello ( vim ) @<w>orld'

  # 入れ子になっている時
  ble/keymap:vi_test/check B1a '@:echo ( @( foo ) bar ( baz ) hello ) ( vim ) world' 'v   i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B1b '@:echo ( @( foo ) bar ( baz ) hello ) ( vim ) world' 'v 1 i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B1c '@:echo ( @( foo ) bar ( baz ) hello ) ( vim ) world' 'v 2 i b S a' '@:echo (@< ( foo ) bar ( baz ) hello >) ( vim ) world'
  ble/keymap:vi_test/check B1d '@:echo ( @( foo ) bar ( baz ) hello ) ( vim ) world' 'v 3 i b S a' '@:echo ( @<(> foo ) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B2a '@:echo ( ( @foo ) bar ( baz ) hello ) ( vim ) world' 'v   i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B2b '@:echo ( ( @foo ) bar ( baz ) hello ) ( vim ) world' 'v 1 i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B2c '@:echo ( ( @foo ) bar ( baz ) hello ) ( vim ) world' 'v 2 i b S a' '@:echo (@< ( foo ) bar ( baz ) hello >) ( vim ) world'
  ble/keymap:vi_test/check B2d '@:echo ( ( @foo ) bar ( baz ) hello ) ( vim ) world' 'v 3 i b S a' '@:echo ( ( @<f>oo ) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B3a '@:echo ( ( foo @) bar ( baz ) hello ) ( vim ) world' 'v   i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B3b '@:echo ( ( foo @) bar ( baz ) hello ) ( vim ) world' 'v 1 i b S a' '@:echo ( (@< foo >) bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B3c '@:echo ( ( foo @) bar ( baz ) hello ) ( vim ) world' 'v 2 i b S a' '@:echo (@< ( foo ) bar ( baz ) hello >) ( vim ) world'
  ble/keymap:vi_test/check B3d '@:echo ( ( foo @) bar ( baz ) hello ) ( vim ) world' 'v 3 i b S a' '@:echo ( ( foo @<)> bar ( baz ) hello ) ( vim ) world'
  ble/keymap:vi_test/check B4a '@:echo ( ( foo ) @bar ( baz ) hello ) ( vim ) world' 'v   i b S a' '@:echo (@< ( foo ) bar ( baz ) hello >) ( vim ) world'
  ble/keymap:vi_test/check B4b '@:echo ( ( foo ) @bar ( baz ) hello ) ( vim ) world' 'v 1 i b S a' '@:echo (@< ( foo ) bar ( baz ) hello >) ( vim ) world'
  ble/keymap:vi_test/check B4c '@:echo ( ( foo ) @bar ( baz ) hello ) ( vim ) world' 'v 2 i b S a' '@:echo ( ( foo ) @<b>ar ( baz ) hello ) ( vim ) world'

  # 閉じていない時1
  ble/keymap:vi_test/check C1a '@:echo ( ( @foo ) bar ( baz ) hello' 'v i b S a' '@:echo ( (@< foo >) bar ( baz ) hello'
  ble/keymap:vi_test/check C1b '@:echo ( ( foo ) @bar ( baz ) hello' 'v i b S a' '@:echo ( ( foo ) @<b>ar ( baz ) hello'

  # 閉じていない時2
  ble/keymap:vi_test/check D1a '@:echo ( @foo bar' 'v i b S a' '@:echo ( @<f>oo bar'

  # 閉じていない時3
  ble/keymap:vi_test/check E1a '@:echo (vim) test ( quick ) world ( @foo bar' 'v i b S a' '@:echo (vim) test ( quick ) world ( @<f>oo bar'
  ble/keymap:vi_test/check E1b '@:echo (vim) test ( quick ) @world ( foo bar' 'v i b S a' '@:echo (vim) test ( quick ) @<w>orld ( foo bar'
  ble/keymap:vi_test/check E1c '@:echo (vim) test ( @quick ) world ( foo bar' 'v i b S a' '@:echo (vim) test (@< quick >) world ( foo bar'
  ble/keymap:vi_test/check E1d '@:echo (vim) @test ( quick ) world ( foo bar' 'v i b S a' '@:echo (vim) test (@< quick >) world ( foo bar'
  ble/keymap:vi_test/check E1e '@:echo (@vim) test ( quick ) world ( foo bar' 'v i b S a' '@:echo (@<vim>) test ( quick ) world ( foo bar'

  # 始まりがない時
  ble/keymap:vi_test/check F1a '@:echo @vim) test ( quick ) world ( foo )' 'v i b S a' '@:echo @<v>im) test ( quick ) world ( foo )'
  ble/keymap:vi_test/check F1b '@:echo vim@) test ( quick ) world ( foo )' 'v i b S a' '@:echo vim) test (@< quick >) world ( foo )'
  ble/keymap:vi_test/check F1c '@:echo vim) @test ( quick ) world ( foo )' 'v i b S a' '@:echo vim) test (@< quick >) world ( foo )'
  ble/keymap:vi_test/check F1d '@:echo vim) test @( quick ) world ( foo )' 'v i b S a' '@:echo vim) test (@< quick >) world ( foo )'
  ble/keymap:vi_test/check F1e '@:echo vim) test ( quick ) @world ( foo )' 'v i b S a' '@:echo vim) test ( quick ) world (@< foo >)'

  # echo () ... の時。ib と ab の両方テストする
  ble/keymap:vi_test/check G1a '@:echo @foo () (bar)' 'v i b S a' '@:echo foo @<()> (bar)'
  ble/keymap:vi_test/check G1b '@:echo foo @() (bar)' 'v i b S a' '@:echo foo @<(>) (bar)'
  ble/keymap:vi_test/check G1c '@:echo foo (@) (bar)' 'v i b S a' '@:echo foo (@<)> (bar)'
  ble/keymap:vi_test/check G2a '@:echo @foo () (bar)' 'v a b S a' '@:echo foo @<()> (bar)'
  ble/keymap:vi_test/check G2b '@:echo foo @() (bar)' 'v a b S a' '@:echo foo @<(>) (bar)'
  ble/keymap:vi_test/check G2c '@:echo foo (@) (bar)' 'v a b S a' '@:echo foo (@<)> (bar)'
  ble/keymap:vi_test/check G3a '@:echo @foo () (bar)' 'v i b h S a' '@:echo foo@< ()> (bar)'
  ble/keymap:vi_test/check G3b '@:echo @foo () (bar)' 'v a b l S a' '@:echo foo @<() >(bar)'

  # 改行が含まれている場合の処理
  ble/keymap:vi_test/check H1a $'@:echo (\nhello @world\n)'   'v i b S a' $'@:echo (\n@<hello world\n>)'
  ble/keymap:vi_test/check H2a $'@:echo (\nhello @world\n\n)' 'v i b S a' $'@:echo (\n@<hello world\n\n>)'

  ble/keymap:vi_test/check I1a '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I1b '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 4 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I1c '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 6 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I1d '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 9 l i b S a'   '@:echo @<foo ( bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I1e '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 0 l i b S a' '@:echo @<foo ( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I1f '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 2 l i b S a' '@:echo @<foo ( bar ) b>az (hello) vim (world) this'
  ble/keymap:vi_test/check I1g '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 6 l i b S a' '@:echo @<foo ( bar ) baz (>hello) vim (world) this'
  ble/keymap:vi_test/check I1h '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 8 l i b S a' '@:echo @<foo ( bar ) baz (he>llo) vim (world) this'
  ble/keymap:vi_test/check I2a '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 1 l i b S a'   '@:echo foo @<( >bar ) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I2b '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 2 l i b S a'   '@:echo foo @<( b>ar ) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I2c '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 6 l i b S a'   '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I2d '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 8 l i b S a'   '@:echo foo @<( bar ) b>az (hello) vim (world) this'
  ble/keymap:vi_test/check I2e '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 1 2 l i b S a' '@:echo foo @<( bar ) baz (>hello) vim (world) this'
  ble/keymap:vi_test/check I2f '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 1 4 l i b S a' '@:echo foo @<( bar ) baz (he>llo) vim (world) this'
  ble/keymap:vi_test/check I2g '@:echo foo @( bar ) baz (hello) vim (world) this' 'v 2 0 l i b S a' '@:echo foo @<( bar ) baz (hello) v>im (world) this'
  ble/keymap:vi_test/check I3a '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 1 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3b '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 4 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3c '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 6 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3d '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 1 0 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3e '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 1 2 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3f '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 1 6 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I3g '@:echo foo (@ bar ) baz (hello) vim (world) this' 'v 1 8 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4a '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 1 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4b '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 4 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4c '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 6 l i b S a'   '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4d '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 1 0 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4e '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 1 2 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4f '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 1 6 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I4g '@:echo foo ( @bar ) baz (hello) vim (world) this' 'v 1 8 l i b S a' '@:echo foo (@< bar >) baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5a '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1   l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5b '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 4   l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5c '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 6   l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5d '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 9   l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5e '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 0 l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5f '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 2 l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5g '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 6 l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'
  ble/keymap:vi_test/check I5h '@:echo @foo ( bar ) baz (hello) vim (world) this' 'v 1 8 l a b S a' '@:echo foo @<( bar )> baz (hello) vim (world) this'

  ble/keymap:vi_test/check J1a '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 1 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1b '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 2 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1c '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 4 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1d '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 6 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1e '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 1 0 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1f '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 1 2 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J1g '@:echo ( @foo ( bar ) baz (hello) vim (world) this )' 'v 1 6 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2a '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 1 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2b '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 2 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2c '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 4 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2d '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 6 l i b S a'   '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2e '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 1 0 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2f '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 1 2 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J2g '@:echo ( foo @( bar ) baz (hello) vim (world) this )' 'v 1 6 l i b S a' '@:echo (@< foo ( bar ) baz (hello) vim (world) this >)'
  ble/keymap:vi_test/check J3a '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 1 l i b S a'   '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3b '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 2 l i b S a'   '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3c '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 4 l i b S a'   '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3d '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 6 l i b S a'   '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3e '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 1 0 l i b S a' '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3f '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 1 2 l i b S a' '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3g '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 1 6 l i b S a' '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'
  ble/keymap:vi_test/check J3h '@:echo ( foo ( @bar ) baz (hello) vim (world) this )' 'v 1 8 l i b S a' '@:echo ( foo (@< bar >) baz (hello) vim (world) this )'

  ble/keymap:vi_test/check K1a '@:echo foo @(bar (check) ) world' 'v 1   l i b S a' '@:echo foo (bar (@<check>) ) world'
  ble/keymap:vi_test/check K1b '@:echo foo @(bar (check) ) world' 'v 4   l i b S a' '@:echo foo (bar (@<check>) ) world'
  ble/keymap:vi_test/check K1c '@:echo foo @(bar (check) ) world' 'v 5   l i b S a' '@:echo foo (bar (@<check>) ) world'
  ble/keymap:vi_test/check K1d '@:echo foo @(bar (check) ) world' 'v 7   l i b S a' '@:echo foo (bar (@<check>) ) world'
  ble/keymap:vi_test/check K1e '@:echo foo @(bar (check) ) world' 'v 9   l i b S a' '@:echo foo (bar (@<check>) ) world'
  ble/keymap:vi_test/check K1f '@:echo foo @(bar (check) ) world' 'v 1 0 l i b S a' '@:echo foo @<(bar (check>) ) world'
  ble/keymap:vi_test/check K1g '@:echo foo @(bar (check) ) world' 'v 1 1 l i b S a' '@:echo foo @<(bar (check)> ) world'
  ble/keymap:vi_test/check K1h '@:echo foo @(bar (check) ) world' 'v 1 2 l i b S a' '@:echo foo @<(bar (check) >) world'
  ble/keymap:vi_test/check K1i '@:echo foo @(bar (check) ) world' 'v 1 3 l i b S a' '@:echo foo @<(bar (check) )> world'

  ble/keymap:vi_test/check L1a '@:echo foo @(bar () ) world' 'v 1   l i b S a'   '@:echo foo (bar @<()> ) world'
  ble/keymap:vi_test/check L1b '@:echo foo @(bar () ) world' 'v 1   l i b h S a' '@:echo foo (bar@< ()> ) world'
  ble/keymap:vi_test/check L1c '@:echo foo @(bar () ) world' 'v 1   l a b S a'   '@:echo foo (bar @<()> ) world'
  ble/keymap:vi_test/check L1d '@:echo foo @(bar () ) world' 'v 1   l a b l S a' '@:echo foo (bar @<() >) world'
  ble/keymap:vi_test/check L2a '@:echo foo (bar @() ) world' 'v 1   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L2b '@:echo foo (bar @() ) world' 'v 2   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L2c '@:echo foo (bar @() ) world' 'v 3   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L2d '@:echo foo (bar @() ) world' 'v 4   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L3a '@:echo foo (bar (@) ) world' 'v 1   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L3b '@:echo foo (bar (@) ) world' 'v 2   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L3c '@:echo foo (bar (@) ) world' 'v 3   l i b S a' '@:echo foo (@<bar () >) world'
  ble/keymap:vi_test/check L3d '@:echo foo (bar (@) ) world' 'v 4   l i b S a' '@:echo foo (@<bar () >) world'

  ble/keymap:vi_test/check M1a '@:echo (foo @(bar (check) ) world) xxxx' 'v 1   l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1b '@:echo (foo @(bar (check) ) world) xxxx' 'v 5   l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1c '@:echo (foo @(bar (check) ) world) xxxx' 'v 7   l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1d '@:echo (foo @(bar (check) ) world) xxxx' 'v 1 1 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1e '@:echo (foo @(bar (check) ) world) xxxx' 'v 1 2 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1f '@:echo (foo @(bar (check) ) world) xxxx' 'v 1 3 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1g '@:echo (foo @(bar (check) ) world) xxxx' 'v 1 4 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1h '@:echo (foo @(bar (check) ) world) xxxx' 'v 2 0 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M1i '@:echo (foo @(bar (check) ) world) xxxx' 'v 2 4 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M2a '@:echo (foo (@bar (check) ) world) xxxx' 'v 1   l i b S a'   '@:echo (foo (@<bar (check) >) world) xxxx'
  ble/keymap:vi_test/check M2b '@:echo (foo (@bar (check) ) world) xxxx' 'v 4   l i b S a'   '@:echo (foo (@<bar (check) >) world) xxxx'
  ble/keymap:vi_test/check M2c '@:echo (foo (@bar (check) ) world) xxxx' 'v 6   l i b S a'   '@:echo (foo (@<bar (check) >) world) xxxx'
  ble/keymap:vi_test/check M2d '@:echo (foo (@bar (check) ) world) xxxx' 'v 1 0 l i b S a'   '@:echo (foo (@<bar (check) >) world) xxxx'
  ble/keymap:vi_test/check M2e '@:echo (foo (@bar (check) ) world) xxxx' 'v 1 1 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M2f '@:echo (foo (@bar (check) ) world) xxxx' 'v 1 2 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M2g '@:echo (foo (@bar (check) ) world) xxxx' 'v 1 3 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M2h '@:echo (foo (@bar (check) ) world) xxxx' 'v 1 9 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M2i '@:echo (foo (@bar (check) ) world) xxxx' 'v 2 3 l i b S a'   '@:echo (@<foo (bar (check) ) world>) xxxx'
  ble/keymap:vi_test/check M3a '@:echo (foo (@bar (check) ) world xxxx' 'v 1 4 l i b S a'   '@:echo (foo (@<bar (check) ) w>orld xxxx'
  ble/keymap:vi_test/check M3b '@:echo foo (@bar (check) ) world) xxxx' 'v 1 4 l i b S a'   '@:echo foo (@<bar (check) ) w>orld) xxxx'

  ble/keymap:vi_test/check N1a $'@:echo ( foo (\n@hello world\n) bar )' 'v $   i b S a'   $'@:echo (@< foo (\nhello world\n) bar >)'
  ble/keymap:vi_test/check N1b $'@:echo ( foo (\n@hello world\n) bar )' 'v f d i b S a'   $'@:echo (@< foo (\nhello world\n) bar >)'

  ble/test/end-section
}

# iw aw
function ble/keymap:vi_test/section:txtobj_word {
  ble/test/start-section "ble/keymap.vi/txtobj_word_omap" 79

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

  ble/test/start-section "ble/keymap.vi/txtobj_word_xmap" 34

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

  ble/test/end-section
}

function ble/keymap:vi_test/section:op.2018-02-22 {
  ble/test/start-section "ble/keymap.vi/op.2018-02-22" 4

  # 行指向のコピー&貼り付け #D0674
  ble/keymap:vi_test/check A0 $'@:12@345\n67890\n' 'y y p' $'@:12345\n@12345\n67890\n'

  # Y 及び yy ではカーソル位置は変化しない。 #D0673
  ble/keymap:vi_test/check B1 $'@:12@345\n67890\n' 'Y' $'@:12@345\n67890\n'
  ble/keymap:vi_test/check B2 $'@:12@345\n67890\n' 'y y' $'@:12@345\n67890\n'

  # blockwise operator d の書き直し #D0673
  ble/keymap:vi_test/check C $'@:\n12@34567\n1あ2345\n12い345\n123う45\n1234え5\n' 'C-v 4 j l d' $'@:\n12@567\n1 345\n12345\n12 45\n12え5\n'

  ble/test/end-section
}

#------------------------------------------------------------------------------

function ble/keymap:vi_test/run-tests {
  ble/keymap:vi_test/section:space
  ble/keymap:vi_test/section:cw
  ble/keymap:vi_test/section:search
  ble/keymap:vi_test/section:increment
  ble/keymap:vi_test/section:macro
  ble/keymap:vi_test/section:surround
  ble/keymap:vi_test/section:txtobj_quote_xmap
  ble/keymap:vi_test/section:txtobj_block_omap
  ble/keymap:vi_test/section:txtobj_block_xmap
  ble/keymap:vi_test/section:txtobj_word
  ble/keymap:vi_test/section:op.2018-02-22
}

if [[ $1 == bind ]]; then
  function ble/widget/vi-command/check-vi-mode {
    # save
    local original_str=$_ble_edit_str
    local original_ind=$_ble_edit_ind
    local original_mark=$_ble_edit_mark
    local original_mark_active=$_ble_edit_mark_active
    _ble_edit_line_disabled=1 ble/widget/.insert-newline # #D1800 pair=leave-command-layout
    ble/util/buffer.flush >&2

    ble/keymap:vi_test/run-tests

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
    ble/widget/vi-command/check-vi-mode
    return 0
  }

  ble-bind -m vi_imap -f 'C-\ C-\' vi_imap/check-vi-mode
  ble-bind -m vi_nmap -f 'C-\ C-\' vi-command:check-vi-mode
fi

function ble/keymap:vi_test/main {
  # initialize
  _ble_decode_initialize_inputrc=none
  ble/decode/initialize
  [[ ${_ble_decode_keymap-} ]] ||
    ble/decode/reset-default-keymap

  # setup
  ble/decode/keymap/push vi_imap
  ble/widget/vi_imap/normal-mode
  local original_str=$_ble_edit_str
  local original_ind=$_ble_edit_ind
  local original_mark=$_ble_edit_mark
  local original_mark_active=$_ble_edit_mark_active

  # test
  ble/util/buffer.flush >&2
  ble/keymap:vi_test/run-tests

  # restore
  ble-edit/content/reset "$original_str" edit
  _ble_edit_ind=$original_ind
  _ble_edit_mark=$original_mark
  _ble_edit_mark_active=$original_mark_active
  while [[ $_ble_decode_keymap != vi_imap ]]; do
    ble/decode/keymap/pop
  done
  ble/decode/keymap/pop
  return 0
}

ble/keymap:vi_test/main
