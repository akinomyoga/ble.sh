#! /bin/bash

: ${ble_opt_error_char_abell=}
: ${ble_opt_error_char_vbell=1}
: ${ble_opt_error_char_discard=}
: ${ble_opt_error_kseq_abell=1}
: ${ble_opt_error_kseq_vbell=1}
: ${ble_opt_error_kseq_discard=1}
: ${ble_opt_default_keymap:=emacs}

# function ble-decode-byte {
#   while [ $# -gt 0 ]; do
#     "ble-decode-byte+$ble_opt_input_encoding" "$1"
#     shift
#   done

#   .ble-edit.accept-line.exec
# }

# function ble-decode-char {
#   .ble-decode-char "$1"
#   .ble-edit.accept-line.exec
# }

# function ble-decode-key {
#   .ble-decode-key "$1"
#   .ble-edit.accept-line.exec
# }

# **** ble-decode-byte ****

## 関数 .ble-decode-byte bytes...
##   バイト値を整数で受け取って、現在の文字符号化方式に従ってデコードをします。
##   デコードした結果得られた文字は .ble-decode-char を呼び出す事によって処理します。
function .ble-decode-byte {
  while (($#)); do
    "ble-decode-byte+$ble_opt_input_encoding" "$1"
    shift
  done
}

# **** ble-decode-char ****
declare _ble_decode_char__hook=
declare _ble_decode_char__mod_meta=
declare _ble_decode_char__seq # /(_\d+)*/

## 関数 .ble-decode-char char
##   文字をユニコード値 (整数) で受け取って、端末のキー入力の列に翻訳します。
##   デコードした結果得られたキー入力は .ble-decode-key を呼び出す事によって処理します。
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
  if [[ $_ble_decode_char__hook ]]; then
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
  local -a seq=($1)
  local kc="$2"

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
  local -a seq=($1)

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
    local cnames
    cnames=($nseq $ret)

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

## 配列 _ble_decode_${keymap}_kmap_${_ble_decode_key__seq}[key]
##   各 keymap は (キーシーケンス, コマンド) の集合と等価です。
##   この配列は keymap の内容を以下の形式で格納します。
##
##   @param[in] keymap
##     対象の keymap の名称を指定します。
##
##   @param[in] _ble_decode_key__seq
##   @param[in] key
##     _ble_decode_key__seq key の組合せでキーシーケンスを表します。
##
##   @value
##     以下の形式の何れかです。
##     - "_"
##     - "_:command"
##     - "1:command"
##
##     始めの文字が "_" の場合はキーシーケンスに続きがある事を表します。
##     つまり、このキーシーケンスを prefix とするより長いキーシーケンスが登録されている事を表します。
##     command が指定されている場合には、より長いシーケンスでの一致に全て失敗した時点で
##     command が実行されます。シーケンスを受け取った段階では実行されません。
##
##     初めの文字が "1" の場合はキーシーケンスが確定的である事を表します。
##     つまり、このキーシーケンスを prefix とするより長いシーケンスが登録されてなく、
##     このシーケンスを受け取った段階で command を実行する事が確定する事を表します。
##

## 変数 _ble_decode_kmaps := ( ':' kmap ':' )+
##   存在している kmap の名前の一覧を保持します。
##   既定の kmap (名前無し) は含まれません。
_ble_decode_kmaps=
function .ble-decode/keymap/register {
  local kmap="$1"
  if [[ $kmap && $_ble_decode_kmaps != *":$kmap:"* ]]; then
    _ble_decode_kmaps="$_ble_decode_kmaps:$kmap:"
  fi
}

function .ble-decode/keymap/dump {
  local kmap="$1" arrays
  eval "arrays=(\"\${!_ble_decode_${kmap}_kmap_@}\")"
  echo ".ble-decode/keymap/register $kmap"
  if ((${#arrays[@]})); then
    local rex_APOS="'\\\\''"
    declare -p "${arrays[@]}" | sed '
      s/^declare \+\(-[aAfFgilrtux]\+ \+\)\{0,1\}//
      s/^-- \+//
      s/^\([a-zA-Z_0-9]*\)='\''(/\1=(/
      s/)'\''$/)/
      s/'$rex_APOS'/'\''/g
    '
  fi
}

## 関数 kmap ; .ble-decode-key.bind keycodes command
function .ble-decode-key.bind {
  local dicthead="_ble_decode_${kmap}_kmap_"
  local -a seq=($1)
  local cmd="$2"

  .ble-decode/keymap/register "$kmap"

  local i iN="${#seq[@]}" key tseq=
  for ((i=0;i<iN;i++)); do
    local key="${seq[i]}"

    eval "local ocmd=\"\${$dicthead$tseq[$key]}\""
    if ((i+1==iN)); then
      if [[ ${ocmd::1} == _ ]]; then
        eval "$dicthead$tseq[$key]=\"_:\$cmd\""
      else
        eval "$dicthead$tseq[$key]=\"1:\$cmd\""
      fi
    else
      if [[ ! $ocmd ]]; then
        eval "$dicthead$tseq[$key]=_"
      elif [[ ${ocmd::1} == 1 ]]; then
        eval "$dicthead$tseq[$key]=\"_:\${ocmd#?:}\""
      fi
      tseq="${tseq}_$key"
    fi
  done
}

function .ble-decode-key.unbind {
  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq=($1)

  local key="${seq[$((iN-1))]}"
  local tseq=
  local i iN=${#seq}
  for ((i=0;i<iN-1;i++)); do
    tseq="${tseq}_${seq[$i]}"
  done

  local isfirst=1 ent=
  while
    eval "ent=\"\${$dicthead$tseq[$key]}\""

    if [[ $isfirst ]]; then
      # command を消す
      isfirst=
      if [[ ${ent::1} == _ ]]; then
        # ent = _ または _:command の時は、単に command を消して終わる。
        # (未だ bind が残っているので、登録は削除せず break)。
        eval $dicthead$tseq[$key]=_
        break
      fi
    else
      # prefix の ent は _ か _:command のどちらかの筈。
      if [[ $ent != _ ]]; then
        # _:command の場合には 1:command に書き換える。
        # (1:command の bind が残っているので登録は削除せず break)。
        eval $dicthead$tseq[$key]="1:${ent#?:}"
        break
      fi
    fi

    unset $dicthead$tseq[$key]
    eval "((\${#$dicthead$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    key="${tseq##*_}"
    tseq="${tseq%_*}"
  done
}

function .ble-decode-key.dump {
  # 引数の無い場合: 全ての kmap を dump
  local kmap
  if test $# -eq 0; then
    for kmap in ${_ble_decode_kmaps//:/ }; do
      echo "# keymap $kmap"
      .ble-decode-key.dump "$kmap"
    done
    return
  fi

  local kmap="$1" tseq="$2" nseq="$3"
  local dicthead=_ble_decode_${kmap}_kmap_
  local kmapopt=
  test -n "$kmap" && kmapopt=" -m '$kmap'"

  local kcode kcodes
  eval "kcodes=(\${!$dicthead$tseq[@]})"
  for kcode in "${kcodes[@]}"; do
    local ret; ble-decode-unkbd "$kcode"
    local -a knames
    knames=($nseq $ret)
    eval "local ent=\${$dicthead$tseq[$kcode]}"
    if test -n "${ent:2}"; then
      local cmd="${ent:2}"
      case "$cmd" in
      # ble-edit+insert-string *)
      #   echo "ble-bind -sf '${knames[*]}' '${cmd#ble-edit+insert-string }'" ;;
      (ble-edit+*)
        echo "ble-bind$kmapopt -f '${knames[*]}' '${cmd#ble-edit+}'" ;;
      ('.ble-edit.bind.command '*)
        echo "ble-bind$kmapopt -cf '${knames[*]}' '${cmd#.ble-edit.bind.command }'" ;;
      (*)
        echo "ble-bind$kmapopt -xf '${knames[*]}' '${cmd}'" ;;
      esac
    fi

    if test "${ent::1}" = _; then
      .ble-decode-key.dump "$kmap" "${tseq}_$kcode" "${knames[*]}"
    fi
  done
}


## 現在選択されている keymap
declare _ble_decode_key__kmap
##
declare -a _ble_decode_keymap_stack=()

## 関数 .ble-decode/keymap/push kmap
function .ble-decode/keymap/push {
  ble/util/array-push _ble_decode_keymap_stack "$_ble_decode_key__kmap"
  _ble_decode_key__kmap="$1"
}
## 関数 .ble-decode/keymap/pop
function .ble-decode/keymap/pop {
  local count="${#_ble_decode_keymap_stack[@]}"
  local last="$((count-1))"
  _ble_decode_key__kmap="${_ble_decode_keymap_stack[last]}"
  unset _ble_decode_keymap_stack[last]
}


## 今迄に入力された未処理のキーの列を保持します
declare _ble_decode_key__seq= # /(_\d+)*/

declare _ble_decode_key__hook=

## 関数 .ble-decode-key key
##   キー入力の処理を行います。登録されたキーシーケンスに一致した場合、
##   関連付けられたコマンドを実行します。
##   登録されたキーシーケンスの前方部分に一致する場合、即座に処理は行わず
##   入力されたキーの列を _ble_decode_key__seq に記録します。
##
##   @var[in] key
##     入力されたキー
##
function .ble-decode-key {
  local key="$1"

  if [[ $_ble_decode_key__hook ]]; then
    local hook="$_ble_decode_key__hook"
    _ble_decode_key__hook=
    $hook "$key"
    return 0
  fi

  local dicthead=_ble_decode_${_ble_decode_key__kmap:-$ble_opt_default_keymap}_kmap_

  eval "local ent=\"\${$dicthead$_ble_decode_key__seq[$key]}\""
  if [ "${ent%%:*}" = 1 ]; then
    # /1:command/    (続きのシーケンスはなく ent で確定である事を示す)
    local command="${ent:2}"
    .ble-decode-key/invoke-command || _ble_decode_key__seq=
  elif [ "${ent%%:*}" = _ ]; then
    # /_(:command)?/ (続き (1つ以上の有効なシーケンス) がある事を示す)
    _ble_decode_key__seq="${_ble_decode_key__seq}_$key"
  else
    # 遡って適用 (部分一致、または、既定動作)
    .ble-decode-key/invoke-partial-match "$key" && return

    # エラーの表示
    local kcseq="${_ble_decode_key__seq}_$key" ret
    ble-decode-unkbd "${kcseq//_/ }"
    local kbd="$ret"
    [[ $ble_opt_error_kseq_vbell ]] && .ble-term.visible-bell "unbound keyseq: $kbd"
    [[ $ble_opt_error_kseq_abell ]] && .ble-term.audible-bell

    # 残っている文字の処理
    if [[ $_ble_decode_key__seq ]]; then
      if [[ $ble_opt_error_kseq_discard ]]; then
        _ble_decode_key__seq=
      else
        local -a keys=(${_ble_decode_key__seq//_/ } $key)
        local i iN
        _ble_decode_key__seq=
        for ((i=1,iN=${#keys[*]};i<iN;i++)); do
          # 2文字目以降を処理
          .ble-decode-key "${keys[i]}"
        done
      fi
    fi
  fi
  return 0
}

## 関数 .ble-decode-key/invoke-partial-match fail
##   これまでのキー入力に対する部分一致を試みます。
##   登録されている部分一致がない場合には単体のキーに対して既定の動作を呼び出します。
##   既定の動作も登録されていない場合には関数は失敗します。
##   @var[in,out] _ble_decode_key__seq
##   @var[in]     next
##     _ble_decode_key__seq は既に入力された未処理のキー列を指定します。
##     next には今回入力されたキーの列を指定します。
##     この関数は _ble_decode_key__seq next からなるキー列に対する部分一致を試みます。
##
##   この関数は以下の様に動作します。
##   1 先ず、_ble_decode_key__seq に対して部分一致がないか確認し、部分一致する
##     binding があればそれを実行します。
##     - _ble_decode_key__seq + key の全体に対する一致は試みない事に注意して下
##       さい。全体一致については既にチェックして失敗しているという前提です。
##       何故なら部分一致を試みるのは常に最長一致が失敗した時だけだからです。
##   2 _ble_decode_key__seq に対する部分一致が存在しない場合には、
##     ch = _ble_decode_key__seq + key の最初のキーについて登録されている既定の
##     動作を実行します。ch はつまり、_ble_decode_key__seq が空でない時はその先
##     頭で、空の場合は key になります。
##   3 一致が存在して処理が実行された場合には、その後一旦 _ble_decode_key__seq
##     がクリアされ、一致しなかった残りの部分に対して再度 .ble-decode-key を呼
##     び出して再解釈が行われます。
##     1, 2 のいずれでも一致が見付からなかった場合には、_ble_decode_key__seq を
##     呼出時の状態に戻し関数は失敗します。つまり、この場合 _ble_decode_key__seq
##     は、呼出元からは変化していない様に見えます。
##
function .ble-decode-key/invoke-partial-match {
  local dicthead=_ble_decode_${_ble_decode_key__kmap:-$ble_opt_default_keymap}_kmap_

  local next="$1"
  if [[ $_ble_decode_key__seq ]]; then
    local last="${_ble_decode_key__seq##*_}"
    _ble_decode_key__seq="${_ble_decode_key__seq%_*}"

    eval "local ent=\"\${$dicthead$_ble_decode_key__seq[$last]}\""
    if [ "${ent:0:2}" = _: ]; then
      local command="${ent:2}"
      .ble-decode-key/invoke-command || _ble_decode_key__seq=
      .ble-decode-key "$next"
      return 0
    else # ent = _
      if .ble-decode-key/invoke-partial-match "$last"; then
        .ble-decode-key "$next"
        return 0
      else
        # 元に戻す
        _ble_decode_key__seq="${_ble_decode_key__seq}_$last"
        return 1
      fi
    fi
  else
    # ここでは指定した単体のキーに対する既定の処理を実行する
    # $next 単体でも設定がない場合はここに来る。
    # 通常の文字などは全てここに流れてくる事になる。

    # 既定の文字ハンドラ
    local key="$1"
    if (((key&ble_decode_MaskFlag)==0&&32<=key&&key<ble_decode_function_key_base)); then
      eval "local command=\"\${${dicthead}[$_ble_decode_KC_DEFCHAR]:2}\""
      .ble-decode-key/invoke-command && return 0
    fi

    # 既定のキーハンドラ
    eval "local command=\"\${${dicthead}[$_ble_decode_KC_DEFAULT]:2}\""
    .ble-decode-key/invoke-command && return 0

    return 1
  fi
}

## 関数 .ble-decode-key/invoke-command
##   コマンドが有効な場合に、指定したコマンドを適切な環境で実行します。
##   @var[in] command
##     起動するコマンドを指定します。空の場合コマンドは実行されません。
##   @var[in] _ble_decode_key__seq
##   @var[in] key
##     _ble_decode_key__seq は前回までに受け取ったキーの列です。
##     key は今回新しく受け取ったキーの列です。
##     _ble_decode_key__seq と key の組合せで現在入力されたキーシーケンスになります。
##     コマンドを実行した場合 _ble_decode_key__seq はクリアされます。
##     コマンドを実行しなかった場合
##   @return
##     コマンドが実行された場合に 0 を返します。それ以外の場合は 1 です。
##
##   コマンドの実行時に次の変数が定義されます。
##   これらの変数はコマンドの内部から参照する事ができます。
##   @var[out] KEYS
##     このコマンドの起動に用いられたキーシーケンスが格納されます。
##
#
# 実装の注意
#
#   呼び出したコマンドの内部で keymap の switch があっても良い様に、
#   _ble_decode_key__seq + key は厳密に現在のコマンドに対応するシーケンスである必要がある事、
#   コマンドを呼び出す時には常に _ble_decode_key__seq が空になっている事に注意。
#   部分一致などの場合に後続のキーが存在する場合には、それらは呼出元で管理しなければならない。
#
function .ble-decode-key/invoke-command {
  if [[ $command ]]; then
    local -a KEYS=(${_ble_decode_key__seq//_/ } $key)
    _ble_decode_key__seq=
    eval "$command"
    return 0
  else
    return 1
  fi
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
    ret="${_ble_decode_kbd__k2c[$1]}"
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
  if ((${#key}==1)); then
    .ble-text.s2c "$1"
  elif [[ $key =~ ^[_a-zA-Z0-9]+$ ]]; then
    .ble-decode-kbd.get-keycode "$key"
    if [[ ! $ret ]]; then
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

function ble-decode-kbd {
  local key code codes
  codes=()
  for key in "$@"; do
    code=0
    while [[ $key == ?-* ]]; do
      case "${key::1}" in
      (S) ((code|=ble_decode_Shft)) ;;
      (C) ((code|=ble_decode_Ctrl)) ;;
      (M) ((code|=ble_decode_Meta)) ;;
      (A) ((code|=ble_decode_Altr)) ;;
      (s) ((code|=ble_decode_Supr)) ;;
      (H) ((code|=ble_decode_Hypr)) ;;
      (*) ((code|=ble_decode_Erro)) ;;
      esac
      key="${key:2}"
    done

    if [[ $key == ? ]]; then
      .ble-text.s2c "$key" 0
      ((code|=ret))
    elif [[ $key && ! ${key//[_0-9a-zA-Z]/} ]]; then
      .ble-decode-kbd.get-keycode "$key"
      [[ $ret ]] || .ble-decode-kbd.gen-keycode "$key"
      ((code|=ret))
    elif [[ $key == ^? ]]; then
      if [[ $key == '^?' ]]; then
        ((code|=0x7F))
      elif [[ $key == '^`' ]]; then
        ((code|=0x20))
      else
        .ble-text.s2c "$key" 1
        ((code|=ret&0x1F))
      fi
    else
      ((code|=ble_decode_Erro))
    fi
    
    codes[${#codes[@]}]="$code"
  done

  ret="${codes[*]}"
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
  local kmap="$ble_opt_default_keymap" fX= fC= ret

  local arg c
  while (($#)); do
    local arg="$1"; shift
    if [[ $arg == --?* ]]; then
      case "${arg:2}" in
      (help)
        cat <<EOF
ble-bind -k charspecs [keyspec]
ble-bind [-m kmapname] [-scx@] -f keyspecs [command]
ble-bind -D
ble-bind -d

EOF
        ;;
      (*)
        echo "ble-bind: unrecognized long option $arg" >&2
        return 2 ;;
      esac
    elif [[ $arg == -?* ]]; then
      arg="${arg:1}"
      while ((${#arg})); do
        c="${arg::1}" arg="${arg:1}"
        case "$c" in
        (D)
          local -a vars=("${!_ble_decode_kbd__@}" "${!_ble_decode_cmap_@}")
          ((${#vars[@]})) && declare -p "${vars[@]}" ;;
        (d)
          .ble-decode-char.dump
          .ble-decode-key.dump ;;
        (k)
          if (($#<2)); then
            echo "ble-bind: the option \`-k' requires two arguments." >&2
            return 2
          fi

          ble-decode-kbd "$1"; local cseq="$ret"
          if [[ $2 && $2 != - ]]; then
            ble-decode-kbd "$2"; local kc="$ret"
            .ble-decode-char.bind "$cseq" "$kc"
          else
            .ble-decode-char.unbind "$cseq"
          fi
          shift 2 ;;
        (m)
          if (($#<1)); then
            echo "ble-bind: the option \`-m' requires an argument." >&2
            return 2
          fi
          kmap="$1"
          shift ;;
        (x) fX=x ;;
        (c) fC=c ;;
        (f)
          if (($#<2)); then
            echo "ble-bind: the option \`-f' requires two arguments." >&2
            return 2
          fi

          ble-decode-kbd "$1"
          if [[ $2 && $2 != - ]]; then
            local command="$2"

            # コマンドの種類
            if [[ ! "$fX$fC" ]]; then
              # ble-edit+ 関数
              command="ble-edit+$command"

              # check if is function
              local -a a
              a=($command)
              if ! ble/util/isfunction "${a[0]}"; then
                echo "unknown ble edit function \`${a[0]#'ble-edit+'}'" 1>&2
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
          fX= fC=
          shift 2 ;;
        (*)
          echo "ble-bind: unrecognized short option \`-$c'." >&2
          return 2 ;;
        esac
      done
    else
      echo "ble-bind: unrecognized argument \`$arg'." >&2
      return 2
    fi
  done

  return 0
}

#------------------------------------------------------------------------------
# **** binder for bash input ****                                  @decode.bind

# **** stty control ****                                      @decode.bind.stty

## 変数 _ble_stty_stat
##   現在 stty で制御文字の効果が解除されているかどうかを保持します。

#
# 改行 (C-m, C-j) の取り扱いについて
#   入力の C-m が C-j に勝手に変換されない様に -icrnl を指定する必要がある。
#   (-nl の設定の中に icrnl が含まれているので、これを取り消さなければならない)
#   一方で、出力の LF は CR LF に変換されて欲しいので onlcr は保持する。
#   (これは -nl の設定に含まれている)
# 
function .ble-stty.initialize {
  stty -ixon -nl -icrnl \
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
  stty -echo -nl -icrnl \
    kill   undef  lnext  undef  werase undef  erase  undef \
    intr   undef  quit   undef  susp   undef
  _ble_stty_stat=1
}
function .ble-stty.finalize {
  test -z "$_ble_stty_stat" && return
  # detach の場合 -echo を指定する
  stty -echo -nl \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
  _ble_stty_stat=
}
function .ble-stty.exit-trap {
  # exit の場合は echo
  stty echo -nl \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
  rm -f "$_ble_base/tmp/$$".*
}
trap .ble-stty.exit-trap EXIT

# **** ESC ESC ****                                           @decode.bind.esc2

## 関数 ble-edit+.ble-decode-byte 27 27
##   ESC ESC を直接受信できないので
##   '' → '[27^[27^' → '__esc__ __esc__' と変換して受信する。
function ble-edit+.ble-decode-char {
  while (($#)); do
    .ble-decode-char "$1"
    shift
  done
}


# **** ^U ^V ^W ^? 対策 ****                                   @decode.bind.uvw

_ble_decode_bind__uvwflag=
function .ble-decode-bind.uvw {
  test -n "$_ble_decode_bind__uvwflag" && return
  _ble_decode_bind__uvwflag=1

  # 何故か stty 設定直後には bind できない物たち
  builtin bind -x '"":ble-decode-byte:bind 21; eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode-byte:bind 22; eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode-byte:bind 23; eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode-byte:bind 127; eval "$_ble_decode_bind_hook"'
}

# **** ble-decode-bind ****                                   @decode.bind.main

_ble_decode_bind_hook=

## 関数 .ble-decode.c2dqs code; ret
##   bash builtin bind で用いる事のできるキー表記
function .ble-decode.c2dqs {
  local i="$1"

  # bind で用いる
  # リテラル "～" 内で特別な表記にする必要がある物
  if ((0<=i&&i<32)); then
    # C0 characters
    if ((1<=i&&i<=26)); then
      .ble-text.c2s $((i+96))
      ret="\\C-$ret"
    elif ((i==27)); then
      ret="\\e"
    else
      .ble-decode.c2dqs $((i+64))
      ret="\\C-$ret"
    fi
  elif ((32<=i&&i<127)); then
    .ble-text.c2s "$i"

    # \" and \\
    if ((i==34||i==92)); then
      ret='\'"$ret"
    fi
  elif ((128<=i&&i<160)); then
    # C1 characters
    ble/util/sprintf ret '\\%03o' "$i"
  else
    # others
    ble/util/sprintf ret '\\%03o' "$i"
    # .ble-text.c2s だと UTF-8 encode されてしまうので駄目
  fi
}

## 関数 binder; .ble-decode-bind/from-cmap-source
##   3文字以上の bind -x を _ble_decode_cmap から自動的に行うソースを生成
##   binder には bind を行う関数を指定する。
#
# ※この関数は bash-3.1 では使えない。
#   bash-3.1 ではバグで呼出元と同名の配列を定義できないので
#   local -a ccodes が空になってしまう。
#   幸いこの関数は bash-3.1 では使っていないのでこのままにしてある。
#   追記: 公開されている patch を見たら bash-3.1.4 で修正されている様だ。
#
function .ble-decode-bind/from-cmap-source {
  local tseq="$1" qseq="$2" nseq="$3" depth="${4:-1}" ccode
  local apos="'" escapos="'\\''"
  eval "local -a ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret
    .ble-decode.c2dqs "$ccode"
    qseq1="$qseq$ret"
    nseq1="$nseq $ccode"

    eval "local ent=\${_ble_decode_cmap_$tseq[$ccode]}"
    if test -n "${ent%_}"; then
      if ((depth>=3)); then
        echo "\$binder \"$qseq1\" \"${nseq1# }\""
      fi
    fi

    if test "${ent//[0-9]/}" = _; then
      .ble-decode-bind/from-cmap-source "${tseq}_$ccode" "$qseq1" "$nseq1" $((depth+1))
    fi
  done
}

function .ble-decode-initialize-cmap/emit-bindx {
  local ap="'" eap="'\\''"
  echo "builtin bind -x '\"${1//$ap/$eap}\":ble-decode-byte:bind $2; eval \"\$_ble_decode_bind_hook\"'"
}
function .ble-decode-initialize-cmap/emit-bindr {
  echo "builtin bind -r \"$1\""
}
function .ble-decode-initialize-cmap {
  [[ -d $_ble_base/cache ]] || mkdir -p "$_ble_base/cache"
  
  local init="$_ble_base/cmap/default.sh"
  local dump="$_ble_base/cache/cmap+default.$_ble_decode_kbd_ver.$TERM.dump"
  if test "$dump" -nt "$init"; then
    source "$dump"
  else
    echo 'ble.sh: There is no file "'"$dump"'".' 1>&2
    echo '  This is the first time to run ble.sh with TERM='"$TERM." 1>&2
    echo '  Now initializing cmap... ' 1>&2
    source "$init"
    ble-bind -D | sed '
      s/^declare \+\(-[aAfFgilrtux]\+ \+\)\?//
      s/^-- //
      s/["'"'"']//g
    ' > "$dump"
  fi

  if ((_ble_bash>=40300)); then
    # 3文字以上 bind/unbind ソースの生成
    local fbinder="$_ble_base/cache/cmap+default.binder-source"
    _ble_decode_bind_fbinder="$fbinder"
    if ! test "$_ble_decode_bind_fbinder" -nt "$init"; then
      echo -n 'ble.sh: initializing multichar sequence binders... '
      .ble-decode-bind/from-cmap-source > "$fbinder"
      binder=.ble-decode-initialize-cmap/emit-bindx source "$fbinder" > "$fbinder.bind"
      binder=.ble-decode-initialize-cmap/emit-bindr source "$fbinder" > "$fbinder.unbind"
      echo 'done'
    fi
  fi
}

## 関数 .ble-decode-bind/generate-source-to-unbind-default
##   既存の ESC で始まる binding を削除するコードを生成し標準出力に出力します。
##   更に、既存の binding を復元する為のコードを同時に生成し tmp/$$.bind.save に保存します。
function .ble-decode-bind/generate-source-to-unbind-default {
  # 1 ESC で始まる既存の binding を全て削除
  # 2 bind を全て記録 at $$.bind.save
  {
    builtin bind -sp
    if ((_ble_bash>=40300)); then
      echo '__BINDX__'
      builtin bind -X
    fi
  } 2>/dev/null | gawk -v apos="'" '
    BEGIN{
      APOS=apos "\\" apos apos;
      mode=0;
    }

    function quote(text){
      gsub(apos,APOS,text);
      return apos text apos;
    }

    function unescape_control_modifier(str,_i,_esc){
      for(_i=0;_i<32;_i++){
        if(i==0||i==31)
          _esc=sprintf("\\\\C-%c",i+64);
        else if(27<=i&&i<=30)
          _esc=sprintf("\\\\C-\\%c",i+64);
        else
          _esc=sprintf("\\\\C-%c",i+96);

        _chr=sprintf("%c",i);
        gsub(_esc,_chr,str);
      }
      gsub(/\\C-\?/,sprintf("%c",127));
      return str;
    }
    function unescape(str){
      if(str ~ /\\C-/)
        str=unescape_control_modifier(str);
      gsub(/\\e/,sprintf("%c",27),str);
      gsub(/\\"/,"\"",str);
      gsub(/\\\\/,"\\",str);
      return str;
    }

    function output_bindr(line, seq,_capt){
      if(match(line,/^"(([^"]|\\.)+)"/,_capt)>0){
        seq=_capt[1];

        # ※bash-3.1 では bind -sp で \e ではなく \M- と表示されるが、
        #   bind -r では \M- ではなく \e と指定しなければ削除できない。
        gsub(/\\M-/,"\\e",seq);

        print "builtin bind -r " quote(seq);
      }
    }

    mode==0&&$0~/^"/{
      output_bindr($0);

      print "builtin bind " quote($0) >"/dev/stderr";
    }

    /^__BINDX__$/{mode=1;}

    mode==1&&$0~/^"/{
      output_bindr($0);

      line=$0;

      # ※bash-4.3 では bind -r しても bind -X に残る。
      #   再登録を防ぐ為 ble-decode-bind を明示的に避ける
      if(line~/\yble-decode-byte:bind\y/)next;

      # ※bind -X で得られた物は直接 bind -x に用いる事はできない。
      #   コマンド部分の "" を外して中の escape を外す必要がある。
      #   escape には以下の種類がある: \C-a など \C-? \e \\ \"
      #     \n\r\f\t\v\b\a 等は使われない様だ。
      if(match(line,/^("([^"\\]|\\.)*":) "(([^"\\]|\\.)*)"/,captures)>0){
        sequence=captures[1];
        command=captures[3];

        if(command ~ /\\/)
          command=unescape(command);

        line=sequence command;
      }

      print "builtin bind -x " quote(line) >"/dev/stderr";
    }
  ' 2> "$_ble_base/tmp/$$.bind.save"
}

function ble-decode-initialize {
  .ble-decode-initialize-cmap
}

_ble_decode_bind_attached=0
function ble-decode-attach {
  ((_ble_decode_bind_attached==0)) || return
  _ble_decode_bind_attached=1
  .ble-stty.initialize

  # 元のキー割り当ての保存
  eval -- "$(.ble-decode-bind/generate-source-to-unbind-default)"

  # ble.sh bind の設置
  local file="$_ble_base/cache/ble-decode-bind.$_ble_bash.bind"
  [[ $file -nt $_ble_base/bind.sh ]] || source "$_ble_base/bind.sh"
  source "$file"
}
function ble-decode-detach {
  ((_ble_decode_bind_attached==1)) || return
  _ble_decode_bind_attached=0
  .ble-stty.finalize

  # ble.sh bind の削除
  source "$_ble_base/cache/ble-decode-bind.$_ble_bash.unbind"
  
  # 元のキー割り当ての復元
  if [[ -s "$_ble_base/tmp/$$.bind.save" ]]; then
    source "$_ble_base/tmp/$$.bind.save"
    rm -f "$_ble_base/tmp/$$.bind.save"
  fi
}

# function bind {
#   if ((_ble_decode_bind_attached)); then
#     echo Error
#   else
#     builtin bind "$@"
#   fi
# }

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
