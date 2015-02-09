#! /bin/bash

function ble-decode-byte {
  while [ $# -gt 0 ]; do
    "ble-decode-byte+$ble_opt_input_encoding" "$1"
    shift
  done

  .ble-edit.accept-line.exec
}

function ble-decode-char {
  .ble-decode-char "$1"
  .ble-edit.accept-line.exec
}

function ble-decode-key {
  .ble-decode-key "$1"
  .ble-edit.accept-line.exec
}

# **** ble-decode-byte ****

function .ble-decode-byte {
  while [ $# -gt 0 ]; do
    "ble-decode-byte+$ble_opt_input_encoding" "$1"
    shift
  done
}

# **** ble-decode-char ****
: ${ble_opt_error_char_abell=}
: ${ble_opt_error_char_vbell=1}
: ${ble_opt_error_char_discard=}
declare _ble_decode_char__hook=
declare _ble_decode_char__mod_meta=
declare _ble_decode_char__seq # /(_\d+)*/
function .ble-decode-char {
  local char="$1"

  # decode error character
  if ((char&ble_decode_Erro)); then
    ((char&=~ble_decode_Erro))
    [ -n "$ble_opt_error_char_vbell" ] && .ble-term.visible-bell "received a misencoded char $(printf '\\u%04x' $char)"
    [ -n "$ble_opt_error_char_abell" ] && .ble-term.audible-bell 
    [ -n "$ble_opt_error_char_discard" ] && return
    # ((char&ble_decode_Erro)) : 最適化(過去 sequence は全部吐く)?
  fi

  # hook for quoted-insert, etc
  if test -n "$_ble_decode_char__hook"; then
    local hook="$_ble_decode_char__hook"
    _ble_decode_char__hook=
    $hook "$char"
    return 0
  fi

  eval "local ent=\"\${_ble_decode_cmap_$_ble_decode_char__seq[$char]}\""
  if [ -z "$ent" ]; then
    # /^$/   (一致に失敗した事を表す)
    .ble-decode-char.emit "$char"
  elif [ -z "${ent//[0-9]/}" ]; then
    # /\d+/  (続きのシーケンスはなく ent で確定である事を示す)
    _ble_decode_char__seq=
    .ble-decode-char.sendkey-mod "${ent//_/}"
  elif [ "${ent//[0-9]/}" = _ ]; then
    # /\d*_/ (_ は続き (1つ以上の有効なシーケンス) がある事を示す)
    _ble_decode_char__seq="${_ble_decode_char__seq}_$char"
  fi
  return 0
}
## 指定した文字 $1 が sequence を形成しないと分かった時、
## a. 過去の sequence が残っていればそこから一文字以上出力し末端に $1 を追加します。
## b. 過去の sequence がなければ文字を直接出力します。
## \param [in]     $1                     sequence を形成しない文字
## \param [in,out] _ble_decode_char__seq  過去の sequence
function .ble-decode-char.emit {
  local fail="$1"
  if [ -n "$_ble_decode_char__seq" ]; then
    local char="${_ble_decode_char__seq##*_}"
    _ble_decode_char__seq="${_ble_decode_char__seq%_*}"

    eval "local ent=\"\${_ble_decode_cmap_$_ble_decode_char__seq[$char]}\""
    if [ "$ent" != _ -a "${ent//[0-9]/}" = _ ]; then
      _ble_decode_char__seq=
      .ble-decode-char.sendkey-mod "${ent//_/}"
    else
      .ble-decode-char.emit "$char"
    fi

    .ble-decode-char "$fail"
  else
    # 直接出力
    if ((fail<32)); then
      local kcode=$((fail|(fail==0||fail>26?64:96)|ble_decode_Ctrl))
      # modify meta
      if test -n "$_ble_decode_char__mod_meta"; then
        _ble_decode_char__mod_meta=
        .ble-decode-key $((kcode|ble_decode_Meta))
      elif ((fail==27)); then
        _ble_decode_char__mod_meta=$kcode
      else
        .ble-decode-key $kcode
      fi
    else
      # modify meta
      if test -n "$_ble_decode_char__mod_meta"; then
        fail=$((fail|ble_decode_Meta))
        _ble_decode_char__mod_meta=
      fi

      .ble-decode-key "$fail"
    fi
  fi
}
function .ble-decode-char.sendkey-mod {
  local kcode="$1"

  # modify meta
  if test -n "$_ble_decode_char__mod_meta"; then
    local kcode0="$_ble_decode_char__mod_meta"
    _ble_decode_char__mod_meta=
    if ((kcode&ble_decode_Meta)); then
      .ble-decode-key "$kcode0"
    else
      kcode=$((kcode|ble_decode_Meta))
    fi
  fi

  .ble-decode-key "$kcode"
}

function .ble-decode-char.bind {
  local seq=($1) kc="$2"

  local i iN=${#seq[@]} char tseq=
  for ((i=0;i<iN;i++)); do
    local char=${seq[$i]}

    eval "local okc=\"\${_ble_decode_cmap_$tseq[$char]}\""
    if ((i+1==iN)); then
      if test "${okc//[0-9]/}" = _; then
        eval "_ble_decode_cmap_$tseq[$char]=\"${kc}_\""
      else
        eval "_ble_decode_cmap_$tseq[$char]=\"${kc}\""
      fi
    else
      if test -z "$okc"; then
        eval "_ble_decode_cmap_$tseq[$char]=_"
      else
        eval "_ble_decode_cmap_$tseq[$char]=\"${okc%_}_\""
      fi
      tseq="${tseq}_$char"
    fi
  done
}
function .ble-decode-char.unbind {
  local seq=($1)

  local char="${seq[$((iN-1))]}"
  local tseq=
  local i iN=${#seq}
  for ((i=0;i<iN-1;i++)); do
    tseq="${tseq}_${seq[$i]}"
  done

  local isfirst=1 ent=
  while
    eval "ent=\"\${_ble_decode_cmap_$tseq[$char]}\""

    if [ -n "$isfirst" ]; then
      # 数字を消す
      isfirst=
      if [ "${ent%_}" != "$ent" ]; then
        # ent = 1234_ (両方在る時は片方消して終わり)
        eval _ble_decode_cmap_$tseq[$char]=_
        break
      fi
    else
      # _ を消す
      if [ "$ent" != _ ]; then
        # ent = 1234_ (両方在る時は片方消して終わり)
        eval _ble_decode_cmap_$tseq[$char]=${ent%_}
        break
      fi
    fi

    unset _ble_decode_cmap_$tseq[$char]
    eval "((\${#_ble_decode_cmap_$tseq[@]}!=0))" && break

    [ -n "$tseq" ]
  do
    char="${tseq##*_}"
    tseq="${tseq%_*}"
  done
}
function .ble-decode-char.dump {
  local tseq="$1" nseq="$2" ccode
  eval "local -a ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret; ble-decode-unkbd "$ccode"
    local cnames=($nseq $ret)

    eval "local ent=\${_ble_decode_cmap_$tseq[$ccode]}"
    if test -n "${ent%_}"; then
      local kcode="${ent%_}" ret
      ble-decode-unkbd "$kcode"; local key="$ret"
      echo "ble-bind -k '${cnames[*]}' '$key'"
    fi

    if test "${ent//[0-9]/}" = _; then
      .ble-decode-char.dump "${tseq}_$ccode" "${cnames[*]}"
    fi
  done
}

# **** ble-decode-key ****

if [ -z "$ble_decode_Erro" ]; then
  declare -ir ble_decode_Erro=0x40000000
  declare -ir ble_decode_Meta=0x08000000
  declare -ir ble_decode_Ctrl=0x04000000
  declare -ir ble_decode_Shft=0x02000000
  declare -ir ble_decode_Hypr=0x01000000
  declare -ir ble_decode_Supr=0x00800000
  declare -ir ble_decode_Altr=0x00400000
  declare -ir ble_decode_MaskChar=0x001FFFFF
  declare -ir ble_decode_MaskFlag=0x7FC00000
fi

: ${ble_opt_error_kseq_abell=1}
: ${ble_opt_error_kseq_vbell=1}
: ${ble_opt_error_kseq_discard=1}

declare _ble_decode_key__seq # /(_\d+)*/
declare _ble_decode_key__kmap

function .ble-decode-key {
  local key="$1"
  local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_

  eval "local ent=\"\${$dicthead$_ble_decode_key__seq[$key]}\""
  if [ "${ent%%:*}" = 1 ]; then
    # /1:command/    (続きのシーケンスはなく ent で確定である事を示す)
    local command="${ent:2}"
    .ble-decode-key.invoke
  elif [ "${ent%%:*}" = _ ]; then
    # /_(:command)?/ (続き (1つ以上の有効なシーケンス) がある事を示す)
    _ble_decode_key__seq="${_ble_decode_key__seq}_$key"
  else
    # 既定の動作
    .ble-decode-key.invoke-default "$key" && return

    # 他     (一致に失敗した事を表す)
    local kcseq="${_ble_decode_key__seq}_$key" ret
    ble-decode-unkbd "${kcseq//_/}"
    local kbd="$ret"
    [ -n "$ble_opt_error_kseq_vbell" ] && .ble-term.visible-bell "unbound keyseq: $kbd"
    [ -n "$ble_opt_error_kseq_abell" ] && .ble-term.audible-bell
    if [ -n "$ble_opt_error_kseq_discard" ]; then
      _ble_decode_key__seq=
    else
      .ble-decode-key.emit "$key"
    fi
  fi
  return 0
}
function .ble-decode-key.emit {
  local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_

  local fail="$1"
  if [ -n "$_ble_decode_key__seq" ]; then
    local key="${_ble_decode_key__seq##*_}"
    _ble_decode_key__seq="${_ble_decode_key__seq%_*}"

    eval "local ent=\"\${$dicthead$_ble_decode_key__seq[$key]}\""
    if [ "${ent:0:2}" = _: ]; then
      local command="${ent:2}"
      .ble-decode-key.invoke
    else # ent = _
      .ble-decode-key.emit "$key"
    fi

    .ble-decode-key "$fail"
  else
    # $fail 単体でも設定がない場合

    # 既定動作が設定されている場合
    .ble-decode-key.invoke-default "$fail" && return

    # 既定動作もない場合: 無視 (エラーは既に出力している)
  fi
}
## \param [in] command
## \param [in] _ble_decode_key__seq
## \param [in] key
function .ble-decode-key.invoke {
  if [ -n "$command" ]; then
    local KEYS=(${_ble_decode_key__seq//_/} $key)
    _ble_decode_key__seq=
    eval "$command"
    return 0
  else
    _ble_decode_key__seq=
    return 1
  fi
}

## \param [in] command
function .ble-decode-key.invoke-default {
  local key="$1"
  if (((key&ble_decode_MaskFlag)==0&&32<=key&&key<ble_decode_function_key_base)); then
    eval "local command=\"\${${dicthead}[$_ble_decode_KC_DEFCHAR]:2}\""
    .ble-decode-key.invoke && return 0
  fi
  eval "local command=\"\${${dicthead}[$_ble_decode_KC_DEFAULT]:2}\""
  .ble-decode-key.invoke && return 0

  return 1
}

## 変数 _ble_decode_kmaps := ( ':' kmap ':' )+
##   存在している kmap の名前の一覧を保持します。
##   既定の kmap (名前無し) は含まれません。
_ble_decode_kmaps=

## 関数 kmap ; .ble-decode-key.bind keycodes command
function .ble-decode-key.bind {
  local dicthead=_ble_decode_${kmap}_kmap_
  local seq=($1) cmd="$2"

  # register to the kmap list
  if test -n "$kmap" -a "${_ble_decode_kmaps/:$kmap:/}" = "${_ble_decode_kmaps}"; then
    _ble_decode_kmaps="$_ble_decode_kmaps:$kmap:"
  fi
  # if [ ${#seq} -eq 0 ]; then
  #   eval "${dicthead}_default=\"\$cmd\""
  #   return
  # fi

  local i iN=${#seq[@]} key tseq=
  for ((i=0;i<iN;i++)); do
    local key="${seq[$i]}"

    eval "local ocmd=\"\${$dicthead$tseq[$key]}\""
    if ((i+1==iN)); then
      if [ "${ocmd::1}" = _ ]; then
        eval "$dicthead$tseq[$key]=\"_:\$cmd\""
      else
        eval "$dicthead$tseq[$key]=\"1:\$cmd\""
      fi
    else
      if [ -z "$ocmd" ]; then
        eval "$dicthead$tseq[$key]=_"
      elif [ "$ocmd::1" = 1 ]; then
        eval "$dicthead$tseq[$key]=\"_:\${ocmd#?:}\""
      fi
      tseq="${tseq}_$key"
    fi
  done
}
function .ble-decode-key.unbind {
  local dicthead=_ble_decode_${kmap}_kmap_
  local seq=($1)

  local key="${seq[$((iN-1))]}"
  local tseq=
  local i iN=${#seq}
  for ((i=0;i<iN-1;i++)); do
    tseq="${tseq}_${seq[$i]}"
  done

  local isfirst=1 ent=
  while
    eval "ent=\"\${$dicthead$tseq[$key]}\""

    if [ -n "$isfirst" ]; then
      # command を消す
      isfirst=
      if [ "${ent:0:1}" != _ ]; then
        # ent = _:command (両方在る時は片方消して終わり)
        eval $dicthead$tseq[$key]=_
        break
      fi
    else
      # _ を消す
      if [ "$ent" != _ ]; then
        # ent = _:command (両方在る時は片方消して終わり)
        eval $dicthead$tseq[$key]="1:${ent#?:}"
        break
      fi
    fi

    unset $dicthead$tseq[$key]
    eval "((\${#$dicthead$tseq[@]}!=0))" && break

    [ -n "$tseq" ]
  do
    key="${tseq##*_}"
    tseq="${tseq%_*}"
  done
}
function .ble-decode-key.dump {
  # 引数の無い場合: 全ての kmap を dump
  if test $# -eq 0; then
    .ble-decode-key.dump ''
    for kmap in ${_ble_decode_kmaps//:/}; do
      .ble-decode-key.dump "$kmap"
    done
    return
  fi

  local kmap="$1" tseq="$2" nseq="$3"
  local dicthead=_ble_decode_${kmap}_kmap_
  local kmapopt=
  test -n "$kmap" && kmapopt=" -m '$kmap'"

  local kcode
  eval "local kcodes=(\${!$dicthead$tseq[@]})"
  for kcode in "${kcodes[@]}"; do
    local ret; ble-decode-unkbd "$kcode"
    local knames=($nseq $ret)
    eval "local ent=\${$dicthead$tseq[$kcode]}"
    if test -n "${ent:2}"; then
      local cmd="${ent:2}"
      case "$cmd" in
      # ble-edit+insert-string *)
      #   echo "ble-bind -sf '${knames[*]}' '${cmd#ble-edit+insert-string }'" ;;
      ble-edit+*)
        echo "ble-bind$kmapopt -f '${knames[*]}' '${cmd#ble-edit+}'" ;;
      *)
        echo "ble-bind$kmapopt -xf '${knames[*]}' '${cmd}'" ;;
      esac
    fi

    if test "${ent::1}" = _; then
      .ble-decode-key.dump "$kmap" "${tseq}_$kcode" "${knames[*]}"
    fi
  done
}

# **** key names ****
if [ "${_ble_bash:-0}" -ge 40000 ]; then
  _ble_decode_kbd_ver=4
  declare -i _ble_decode_kbd__n=0
  declare -A _ble_decode_kbd__k2c
  declare -A _ble_decode_kbd__c2k
  function .ble-decode-kbd.set-keycode {
    local key="$1" code="$2"
    : ${_ble_decode_kbd__c2k[$code]:=$key}
    _ble_decode_kbd__k2c[$key]=$code
  }
  function .ble-decode-kbd.get-keycode {
    local key="$1"
    ret="${_ble_decode_kbd__k2c[$key]}"
  }
else
  _ble_decode_kbd_ver=3
  declare -i _ble_decode_kbd__n=0
  declare    _ble_decode_kbd__k2c_keys=
  declare -a _ble_decode_kbd__k2c_vals
  declare -a _ble_decode_kbd__c2k
  function .ble-decode-kbd.set-keycode {
    local key="$1" code="$2"
    : ${_ble_decode_kbd__c2k[$code]:=$key}
    _ble_decode_kbd__k2c_keys="$_ble_decode_kbd__k2c_keys:$key:"
    _ble_decode_kbd__k2c_vals[${#_ble_decode_kbd__k2c_vals[@]}]=$code
  }
  function .ble-decode-kbd.get-keycode {
    local key="$1"
    local tmp="${_ble_decode_kbd__k2c_keys%%:$key:*}"
    if [ ${#tmp} = ${#_ble_decode_kbd__k2c_keys} ]; then
      ret=
    else
      tmp=(${tmp//:/ })
      ret="${_ble_decode_kbd__k2c_vals[${#tmp[@]}]}"
    fi
  }
fi

if test -z "$ble_decode_function_key_base"; then
  declare -ir ble_decode_function_key_base=0x110000
fi

## \param [in]  $1   keycode
## \param [out] ret  keyname
function .ble-decode-kbd.get-keyname {
  local keycode="$1"
  ret="${_ble_decode_kbd__c2k[$keycode]}"
  if [ -z "$ret" ] && ((keycode<ble_decode_function_key_base)); then
    .ble-text.c2s "$keycode"
    _ble_decode_kbd__c2k[$keycode]="$ret"
  fi
}
## 指定した名前に対応する keycode を取得します。
## 指定した名前の key が登録されていない場合は、
## 新しく kecode を割り当てて返します。
## \param [in]  $1   keyname
## \param [out] ret  keycode
function .ble-decode-kbd.gen-keycode {
  local key="$1"
  if [ ${#key} -eq 1 ]; then
    .ble-text.s2c "$1"
  elif [ -n "$key" -a -z "${key//[_a-zA-Z0-9]/}" ]; then
    .ble-decode-kbd.get-keycode "$key"
    if [ -z "$ret" ]; then
      ((ret=ble_decode_function_key_base+_ble_decode_kbd__n++))
      .ble-decode-kbd.set-keycode "$key" "$ret"
    fi
  else
    ret=-1
    return 1
  fi
}

function .ble-decode-kbd.initialize {
  .ble-decode-kbd.set-keycode TAB  9
  .ble-decode-kbd.set-keycode RET  13

  .ble-decode-kbd.set-keycode NUL  0
  .ble-decode-kbd.set-keycode SOH  1
  .ble-decode-kbd.set-keycode STX  2
  .ble-decode-kbd.set-keycode ETX  3
  .ble-decode-kbd.set-keycode EOT  4
  .ble-decode-kbd.set-keycode ENQ  5
  .ble-decode-kbd.set-keycode ACK  6
  .ble-decode-kbd.set-keycode BEL  7
  .ble-decode-kbd.set-keycode BS   8
  .ble-decode-kbd.set-keycode HT   9  # aka TAB
  .ble-decode-kbd.set-keycode LF   10
  .ble-decode-kbd.set-keycode VT   11
  .ble-decode-kbd.set-keycode FF   12
  .ble-decode-kbd.set-keycode CR   13 # aka RET
  .ble-decode-kbd.set-keycode SO   14
  .ble-decode-kbd.set-keycode SI   15

  .ble-decode-kbd.set-keycode DLE  16
  .ble-decode-kbd.set-keycode DC1  17
  .ble-decode-kbd.set-keycode DC2  18
  .ble-decode-kbd.set-keycode DC3  19
  .ble-decode-kbd.set-keycode DC4  20
  .ble-decode-kbd.set-keycode NAK  21
  .ble-decode-kbd.set-keycode SYN  22
  .ble-decode-kbd.set-keycode ETB  23
  .ble-decode-kbd.set-keycode CAN  24
  .ble-decode-kbd.set-keycode EM   25
  .ble-decode-kbd.set-keycode SUB  26
  .ble-decode-kbd.set-keycode ESC  27
  .ble-decode-kbd.set-keycode FS   28
  .ble-decode-kbd.set-keycode GS   29
  .ble-decode-kbd.set-keycode RS   30
  .ble-decode-kbd.set-keycode US   31

  .ble-decode-kbd.set-keycode SP   32
  .ble-decode-kbd.set-keycode DEL  127

  .ble-decode-kbd.set-keycode PAD  128
  .ble-decode-kbd.set-keycode HOP  129
  .ble-decode-kbd.set-keycode BPH  130
  .ble-decode-kbd.set-keycode NBH  131
  .ble-decode-kbd.set-keycode IND  132
  .ble-decode-kbd.set-keycode NEL  133
  .ble-decode-kbd.set-keycode SSA  134
  .ble-decode-kbd.set-keycode ESA  135
  .ble-decode-kbd.set-keycode HTS  136
  .ble-decode-kbd.set-keycode HTJ  137
  .ble-decode-kbd.set-keycode VTS  138
  .ble-decode-kbd.set-keycode PLD  139
  .ble-decode-kbd.set-keycode PLU  140
  .ble-decode-kbd.set-keycode RI   141
  .ble-decode-kbd.set-keycode SS2  142
  .ble-decode-kbd.set-keycode SS3  143

  .ble-decode-kbd.set-keycode DCS  144
  .ble-decode-kbd.set-keycode PU1  145
  .ble-decode-kbd.set-keycode PU2  146
  .ble-decode-kbd.set-keycode STS  147
  .ble-decode-kbd.set-keycode CCH  148
  .ble-decode-kbd.set-keycode MW   149
  .ble-decode-kbd.set-keycode SPA  150
  .ble-decode-kbd.set-keycode EPA  151
  .ble-decode-kbd.set-keycode SOS  152
  .ble-decode-kbd.set-keycode SGCI 153
  .ble-decode-kbd.set-keycode SCI  154
  .ble-decode-kbd.set-keycode CSI  155
  .ble-decode-kbd.set-keycode ST   156
  .ble-decode-kbd.set-keycode OSC  157
  .ble-decode-kbd.set-keycode PM   158
  .ble-decode-kbd.set-keycode APC  159

  local ret
  .ble-decode-kbd.gen-keycode __defchar__
  _ble_decode_KC_DEFCHAR="$ret"
  .ble-decode-kbd.gen-keycode __default__
  _ble_decode_KC_DEFAULT="$ret"
}

.ble-decode-kbd.initialize

## example: .ble-decode-kbd.single-key C M S up
## \param [out] ret
function .ble-decode-kbd.single-key {
  local code=0
  while [ $# -gt 1 ]; do
    case "$1" in
    S) ((code|=ble_decode_Shft)) ;;
    C) ((code|=ble_decode_Ctrl)) ;;
    M) ((code|=ble_decode_Meta)) ;;
    A) ((code|=ble_decode_Altr)) ;;
    s) ((code|=ble_decode_Supr)) ;;
    H) ((code|=ble_decode_Hypr)) ;;
    *) ((code|=ble_decode_Erro)) ;;
    esac
    shift
  done

  case "$1" in
  ?)
    .ble-text.s2c "$1" 0
    ((code|=ret)) ;;
  '^?')
    ((code=0x7F)) ;;
  '^`')
    ((code=0x32)) ;;
  ^?)
    .ble-text.s2c "$1" 1
    ((code|=ret&0x1F)) ;;
  *)
    if [ -z "${1//[_0-9a-zA-Z]/}" ]; then
      .ble-decode-kbd.gen-keycode "$1"
      ((code|=ret))
    else
      ((code|=ble_decode_Erro))
    fi ;;
  esac

  ret="$code"
}

function ble-decode-kbd {
  local GLOBIGNORE='*'
  local key keymods codes=()
  for key in $@; do
    if test "x${key: -1}" = 'x-'; then
      # -, C--
      IFS=- eval 'keymods=(${key%-})'
      keymods+=("${key: -1}")
    else
      IFS=- eval 'keymods=($key)'
    fi

    .ble-decode-kbd.single-key "${keymods[@]}"
    codes[${#codes[@]}]="$ret"
  done
  ret="${codes[@]}"
}

function .ble-decode-unkbd.single-key {
  local key="$1"

  local f_unknown=
  local char="$((key&ble_decode_MaskChar))"
  .ble-decode-kbd.get-keyname "$char"
  if [ -z "$ret" ]; then
    f_unknown=1
    ret=__UNKNOWN__
  fi

  ((key&ble_decode_Shft)) && ret="S-$ret"
  ((key&ble_decode_Meta)) && ret="M-$ret"
  ((key&ble_decode_Ctrl)) && ret="C-$ret"
  ((key&ble_decode_Altr)) && ret="A-$ret"
  ((key&ble_decode_Supr)) && ret="s-$ret"
  ((key&ble_decode_Hypr)) && ret="H-$ret"

  [ -z "$f_unknown" ]
}

function ble-decode-unkbd {
  local -a kbd
  local kc
  for kc in $*; do
    .ble-decode-unkbd.single-key "$kc"
    kbd[${#kbd[@]}]="$ret"
  done
  ret="${kbd[*]}"
}

# **** ble-bind ****
function ble-bind {
  local kmap= fX= fC= ret

  local "${ble_getopt_vars[@]}"
  ble-getopt-begin ble-bind 'D d k:n:? m:n x c f:.:? help' "$@"
  while ble-getopt; do
    case "${OPTARGS[0]}" in
    D) # dump cmap raw
      local vars=("${!_ble_decode_kbd__@}" "${!_ble_decode_cmap_@}")
      ((${#vars[@]})) && declare -p "${vars[@]}"
      ;;
    d) # dump ble-bind settings
      .ble-decode-char.dump
      .ble-decode-key.dump
      ;;
    k) # define char sequence = some key
      ble-decode-kbd "${OPTARGS[1]}"; local cseq="$ret"
      if [ -n "$3" ]; then
        ble-decode-kbd "${OPTARGS[2]}"; local kc="$ret"
        .ble-decode-char.bind "$cseq" "$kc"
      else
        .ble-decode-char.unbind "$cseq"
      fi
      ;;
    m) kmap="${OPTARGS[1]}" ;;
    x) fX=x ;;
    c) fC=c ;;
    f) # define key sequence = some command
      ble-decode-kbd "${OPTARGS[1]}"
      if [ -n "${OPTARGS[2]}" ]; then
        local command="${OPTARGS[2]}"

        # コマンドの種類
        if test -z "$fX$fC"; then
          # ble-edit+ 関数
          command="ble-edit+$command"

          # check if is function
          local a=($command)
          if ! type -t "${a[0]}" &>/dev/null; then
            echo "unknown ble edit function \`${a[0]#ble-edit+}'" 1>&2
            return 1
          fi
        else
          case "$fX$fC" in
          (x) # 編集用の関数
            # command="; $command; " # ■ 前処理と後処理を追加
            echo "error: sorry, not yet implemented" 1>&2 ;;
          (c) # コマンド実行
            # echo "error: sorry, not yet implemented" 1>&2
            command=".ble-edit.bind.command $command" ;;
          (*)
            echo "error: combination of -x and -c flags" 1>&2 ;;
          esac
        fi

        .ble-decode-key.bind "$ret" "$command"
      else
        .ble-decode-key.unbind "$ret"
      fi
      fX= fC= ;;
    help)
      cat <<EOF
ble-bind -k charspecs [keyspec]
ble-bind [-m kmapname] [-sxc@] -f keyspecs [command]

EOF
      return 0 ;;
    *)
      echo "unknown argument" 1>&2
      return 1
      ;;
    esac
  done
  
  [ -n "${OPTARGS+set}" ] && return 1

  return 0
}

#------------------------------------------------------------------------------
# **** binder for bash input ****                                  @decode.bind

# **** stty control ****                                      @decode.bind.stty

## 変数 _ble_stty_stat
##   現在 stty で制御文字の効果が解除されているかどうかを保持します。

function .ble-stty.setup {
  stty -ixon    \
    kill   undef  lnext  undef  werase undef  erase  undef \
    intr   undef  quit   undef  susp   undef
  _ble_stty_stat=1
}
function .ble-stty.leave {
  test -z "$_ble_stty_stat" && return
  stty  echo -nl \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
  _ble_stty_stat=
}
function .ble-stty.enter {
  test -n "$_ble_stty_stat" && return
  stty -echo -nl \
    kill   undef  lnext  undef  werase undef  erase  undef \
    intr   undef  quit   undef  susp   undef
  _ble_stty_stat=1
}

# **** ESC ESC ****                                           @decode.bind.esc2

## 関数 ble-edit+.ble-decode-byte.__esc__
##   ESC ESC を直接受信できないので
##   '' → '[27^[27^' → '__esc__ __esc__' と変換して受信する。
function ble-edit+.ble-decode-char.__esc__ {
  .ble-decode-char 27
  .ble-decode-char 27
}


# **** ^U ^V ^W ^? 対策 ****                                   @decode.bind.uvw

_ble_decode_bind__uvwflag=
function .ble-decode-bind.uvw {
  test -n "$_ble_decode_bind__uvwflag" && return
  _ble_decode_bind__uvwflag=1

  # 何故か stty 設定直後には bind できない物たち
  bind -x "\"\":ble-decode-byte:bind 21"
  bind -x "\"\":ble-decode-byte:bind 22"
  bind -x "\"\":ble-decode-byte:bind 23"
  bind -x "\"\":ble-decode-byte:bind 127"
}

# **** ble-decode-bind ****                                   @decode.bind.main

function ble-decode-bind.cmap {
  local init="$_ble_base/ble.d/cmap+default.sh"
  local dump="$_ble_base/ble.d/cmap+default.$_ble_decode_kbd_ver.dump"
  if test "$dump" -nt "$init"; then
    source "$dump"
  else
    echo 'ble.sh: There is not the file "ble.d/cmap+default.dump".' 1>&2
    echo '  This is possibly first time to load ble.sh.' 1>&2
    echo '  Now initializing cmap...' 1>&2
    source "$init"
    ble-bind -D | sed '
      s/^declare \+\(-[aAfFgilrtux]\+ \+\)\?//
      s/["'"'"']//g
    ' > "$dump"
  fi
}

function ble-decode-bind {
  .ble-stty.setup

  # ESC で始まる既存の binding を全て削除
  local line
  while IFS= read -r line; do
    bind -r "${line%x}"
  done < <(bind -sp | fgrep -a '"\e' | awk '{match($0,/"([^"]+)"/,_capt);print _capt[1] "x";}')

  # bind -x '"?":ble-decode-byte:bind ?'
  local i ret
  for ((i=0;i<256;i++)); do

    # リテラル "～" 内で特別な表記にする必要がある物
    case "$i" in
    (0) # \0
      ret='\C-@' ;;
    (34|92) # \\ or \"
      ret='\'"$ret" ;;
    # (39) # ' 特に何もしなくて良い
    #   ;;
    (*)
      if ((i>=128)); then
        .ble-text.sprintf ret '\\%03o' "$i"
      else
        .ble-text.c2s "$i"
      fi ;;
    esac

    # * C-x (24) は直接 bind すると何故か bash が crash する。
    #   なので C-x は割り当てないで、
    #   代わりに C-x ? の組合せを全て登録する事にする。
    # * bash-4.1 では ESC ESC に bind すると
    #   bash_execute_unix_command: cannot find keymap for command
    #   が出るので ESC [ ^ に適当に redirect して ESC [ ^ を
    #   ESC ESC として解釈する様にする。
    # * bash-4.3 では ESC ? と ESC [ ? も割り当てる必要がある (2015-02-09)
    #   bash-4.3 では ESC ?, ESC [ ? も全て割り当てないと以下のエラーになる。
    #   bash_execute_unix_command: cannot find keymap for command

    # ?
    ((i!=24)) && bind -x "\"$ret\":\"ble-decode-byte:bind $i\""

    # C-x ?
    bind -x "\"$ret\":\"ble-decode-byte:bind 24 $i\""

    if ((_ble_bash>=40300)); then
      # もしかすると bash-4.1 以下でもこれで良いのかも。

      # ESC ?
      bind -x "\"\e$ret\":\"ble-decode-byte:bind 27 $i\""

      # ESC [ ?
      bind -x "\"\e[$ret\":\"ble-decode-byte:bind 27 91 $i\""
    else
      # bash-4.1: not tested in other versions

      # ESC ESC
      bind '"\e\e":"\e[^"'
      ble-bind -k 'ESC [ ^' __esc__
      ble-bind -f __esc__ .ble-decode-char.__esc__
    fi
  done
}

#------------------------------------------------------------------------------
# **** encoding = UTF-8 ****

_ble_decode_byte__utf_8__mode=0
_ble_decode_byte__utf_8__code=0
function ble-decode-byte+UTF-8 {
  local code=$_ble_decode_byte__utf_8__code
  local mode=$_ble_decode_byte__utf_8__mode
  local byte="$1"
  local cha0= char=
  (('
    byte&=0xFF,
    (mode!=0&&(byte&0xC0)!=0x80)&&(
      cha0=ble_decode_Erro|code,mode=0
    ),
    byte<0xF0?(
      byte<0xC0?(
        byte<0x80?(
          char=byte
        ):(
          mode==0?(
            char=ble_decode_Erro|byte
          ):(
            code=code<<6|byte&0x3F,
            --mode==0&&(char=code)
          )
        )
      ):(
        byte<0xE0?(
          code=byte&0x1F,mode=1
        ):(
          code=byte&0x0F,mode=2
        )
      )
    ):(
      byte<0xFC?(
        byte<0xF8?(
          code=byte&0x07,mode=3
        ):(
          code=byte&0x03,mode=4
        )
      ):(
        byte<0xFE?(
          code=byte&0x01,mode=5
        ):(
          char=ble_decode_Erro|byte
        )
      )
    )
  '))

  _ble_decode_byte__utf_8__code=$code
  _ble_decode_byte__utf_8__mode=$mode

  [ -n "$cha0" ] && .ble-decode-char "$cha0"
  [ -n "$char" ] && .ble-decode-char "$char"
}

## \param [in]  $1 = code
## \param [out] ret
function .ble-text.c2bc+UTF-8 {
  local code="$1"
  ((ret=code<0x80?1:
    (code<0x800?2:
    (code<0x10000?3:
    (code<0x200000?4:5)))))
}

function ble-decode-byte+C {
  .ble-decode-char "$1"
}

## 関数 .ble-text.c2bc+C charcode ; ret
function .ble-text.c2bc+C {
  ret=1
}
