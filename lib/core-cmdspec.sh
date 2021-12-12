# -*- mode: sh; mode: sh-bash -*-

function ble/cmdspec/initialize { return 0; }
ble-import core-complete

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
      ble/progcolor/wattr#setattr $((wbeg+${#varname})) d
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
