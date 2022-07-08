# -*- mode: sh; mode: sh-bash -*-

function ble/cmdspec/initialize { return 0; }

function ble/complete/opts/initialize {
  ble/cmdspec/opts mandb-help                                    printf
  ble/cmdspec/opts mandb-disable-man:mandb-help                  bind
  ble/cmdspec/opts mandb-disable-man:mandb-help:mandb-help-usage complete
  ble/cmdspec/opts mandb-disable-man:no-options                  : true false

  ble/cmdspec/opts mandb-help=%'help echo':stop-options-unless='^-[neE]+$' echo

  local conditional_operators='
    -eq (NUM1 -eq NUM2)      Arithmetic comparison ==.
    -ne (NUM1 -ne NUM2)      Arithmetic comparison !=.
    -lt (NUM1 -lt NUM2)      Arithmetic comparison < .
    -le (NUM1 -le NUM2)      Arithmetic comparison <=.
    -gt (NUM1 -gt NUM2)      Arithmetic comparison > .
    -ge (NUM1 -ge NUM2)      Arithmetic comparison >=.
    -nt (FILE1 -nt FILE2)    True if file1 is newer than file2 (according to modification date).
    -ot (FILE1 -ot FILE2)    True if file1 is older than file2.
    -ef (FILE1 -ef FILE2)    True if file1 is a hard link to file2.'
  ble/cmdspec/opts disable-double-hyphen:mandb-help=%'help test':mandb-help=@"$conditional_operators" '[['

  local test_operators=$conditional_operators'
    -a (EXPR1 -a EXPR2)      True if both expr1 AND expr2 are true.
    -a (EXPR1 -o EXPR2)      True if either expr1 OR expr2 is true.'
  ble/cmdspec/opts disable-double-hyphen:mandb-help=%'help test':mandb-help=@"$test_operators"        'test' '['

  ble/cmdspec/opts mandb-disable-man:mandb-help:stop-options-postarg:plus-options=aAilnrtux declare typeset local
  ble/cmdspec/opts mandb-disable-man:mandb-help:stop-options-postarg local export readonly
  ble/cmdspec/opts mandb-disable-man:mandb-help:stop-options-postarg alias

  ble/cmdspec/opts mandb-help rsync
}
ble/complete/opts/initialize


function ble/cmdinfo/cmd:declare/chroma.wattr {
  local ret
  if ((wtype==_ble_attr_VAR)); then
    ble/syntax:bash/find-rhs "$wtype" "$wbeg" "$wlen" element-assignment &&
      ble/progcolor/highlight-filename.wattr "$ret" "$wend"
  else
    ble/progcolor/eval-word || return "$?"
    local wval=$ret

    if ble/string#match "$wval" '^([_a-zA-Z][_a-zA-Z0-9]*)(\[.+\])?$'; then
      # ToDo: properly support quoted case
      local varname=${BASH_REMATCH[1]}
      ble/syntax/highlight/vartype "$varname"
      ble/progcolor/wattr#setattr "$wbeg" "$ret"
      ble/progcolor/wattr#setattr "$((wbeg+${#varname}))" d
    elif ble/string#match "$wval" '^[-+]' && ble/progcolor/is-option-context; then
      # ToDo: validate available options
      local ret; ble/color/face2g argument_option
      ble/progcolor/wattr#setg "$wbeg" "$ret"
    else
      local ret; ble/color/face2g argument_error
      ble/progcolor/wattr#setg "$wbeg" "$ret"
    fi
  fi
  return 0
}

function ble/cmdinfo/cmd:declare/chroma {
  local i "${_ble_syntax_progcolor_vars[@]/%/=}" # WA #D1570 checked
  for ((i=1;i<${#comp_words[@]};i++)); do
    local ref=${tree_words[i]}
    [[ $ref ]] || continue
    local progcolor_iword=$i
    ble/progcolor/load-word-data "$ref"
    ble/progcolor/@wattr ble/cmdinfo/cmd:declare/chroma.wattr
  done
}
function ble/cmdinfo/cmd:typeset/chroma  { ble/cmdinfo/cmd:declare/chroma "$@"; }
function ble/cmdinfo/cmd:local/chroma    { ble/cmdinfo/cmd:declare/chroma "$@"; }
function ble/cmdinfo/cmd:readonly/chroma { ble/cmdinfo/cmd:declare/chroma "$@"; }
function ble/cmdinfo/cmd:export/chroma   { ble/cmdinfo/cmd:declare/chroma "$@"; }
