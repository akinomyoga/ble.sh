#!/bin/bash

## @var[out] str ind
function ble/keymap:vi_test/decompose-state {
  local spec=$1
  ind=${spec%%:*} str=${spec#*:}
  [[ $ind == [!0-9a-zA-Z] ]] &&
    ind=${str%%"$ind"*} ind=${#ind} str=${str::ind}${str:ind+1}
}

function ble/keymap:vi_test/start-section {
  section=$1 nsuccess=0 ntest=0
}

function ble/keymap:vi_test/check {
  local id=$1 initial=$2 kspecs=$3 final=$4
  local str ind
  ble/keymap:vi_test/decompose-state "$initial"; local i=$ind in=$str
  ble/keymap:vi_test/decompose-state "$final"; local f=$ind fin=$str
  
  local nl=$'\n' NL=$'\e[7m^J\e[m'
  _ble_edit_str.reset "$in" edit
  ble/widget/.goto-char "$i"
  local ret
  ble-decode-kbd "$kspecs"
  ble-decode-key $ret &>/dev/null

  # check results
  [[ $_ble_edit_ind == "$f" && $_ble_edit_str == "$fin" ]]; local ext=$?
  if ((ext==0)); then
    ((ntest++,nsuccess++))
  else
    ((ntest++))
    echo "test($section/$id): keys = ($kspecs)"
    echo "  initial  = \"$i:${in//$nl/$NL}\""
    echo "  expected = \"$f:${fin//$nl/$NL}\""
    echo "  result   = \"$_ble_edit_ind:${_ble_edit_str//$nl/$NL}\""
  fi >&2

  # restore states
  case $_ble_decode_key__kmap in
  (vi_[ixo]map)
    ble-decode-key $((ble_decode_Ctrl|99)) &>/dev/null ;;
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
  echo "# $title test: result $((nsuccess))/$((ntest)) $tip"
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

#------------------------------------------------------------------------------

function ble/widget/vi-command:check-vi-mode {
  # save
  local original_str=$_ble_edit_str
  local original_ind=$_ble_edit_ind
  local original_mark=$_ble_edit_mark
  local original_mark_active=$_ble_edit_mark_active
  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  ble/util/buffer.flush >&2

  local section ntest nsuccess

  #----------------------------------------------------------------------------

  ble/widget/vi-command:check-vi-mode/space
  ble/widget/vi-command:check-vi-mode/cw
  ble/widget/vi-command:check-vi-mode/search
  ble/widget/vi-command:check-vi-mode/increment

  #----------------------------------------------------------------------------

  # restore
  _ble_edit_str.reset "$original" edit
  ble/widget/.goto-char "$original_ind"
  _ble_edit_mark=$original_mark
  _ble_edit_mark_active=$original_mark_active
  return 0
}

function ble/widget/vi_imap/check-vi-mode {
  ble/widget/vi_imap/normal-mode
  ble/widget/vi-command:check-vi-mode
  return 0
}

ble-bind -m vi_imap -f 'C-\ C-\' vi_imap/check-vi-mode
ble-bind -m vi_nmap -f 'C-\ C-\' vi-command:check-vi-mode
