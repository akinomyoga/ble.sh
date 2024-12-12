#! /bin/bash

bleopt/declare -v decode_error_char_abell ''
bleopt/declare -v decode_error_char_vbell 1
bleopt/declare -v decode_error_char_discard ''
bleopt/declare -v decode_error_cseq_abell ''
bleopt/declare -v decode_error_cseq_vbell ''
bleopt/declare -v decode_error_cseq_discard 1
bleopt/declare -v decode_error_kseq_abell 1
bleopt/declare -v decode_error_kseq_vbell 1
bleopt/declare -v decode_error_kseq_discard 1

## @bleopt default_keymap
##   既定の編集モードに使われるキーマップを指定します。
## bleopt_default_keymap=auto
##   [[ -o emacs/vi ]] の状態に応じて emacs/vi を切り替えます。
## bleopt_default_keymap=emacs
##   emacs と同様の編集モードを使用します。
## bleopt_default_keymap=vi
##   vi と同様の編集モードを使用します。
bleopt/declare -n default_keymap auto

function bleopt/check:default_keymap {
  case $value in
  (auto|emacs|vi|safe)
    if [[ $_ble_decode_bind_state != none ]]; then
      local bleopt_default_keymap=$value
      ble/decode/reset-default-keymap
    fi
    return 0 ;;
  (*)
    ble/util/print "bleopt: Invalid value default_keymap='value'. The value should be one of \`auto', \`emacs', \`vi'." >&2
    return 1 ;;
  esac
}

## @fn bleopt/get:default_keymap
##   @var[out] ret
function bleopt/get:default_keymap {
  ret=$bleopt_default_keymap
  if [[ $ret == auto ]]; then
    if [[ -o vi ]]; then
      ret=vi
    else
      ret=emacs
    fi
  fi
}

## @bleopt decode_isolated_esc
##   bleopt decode_isolated_esc=meta
##     単体で受信した ESC を、前置詞として受信した ESC と同様に、
##     Meta 修飾または特殊キーのエスケープシーケンスとして扱います。
##   bleopt decode_isolated_esc=esc
##     単体で受信した ESC を、C-[ として扱います。
bleopt/declare -n decode_isolated_esc auto

function bleopt/check:decode_isolated_esc {
  case $value in
  (meta|esc|auto) ;;
  (*)
    ble/util/print "bleopt: Invalid value decode_isolated_esc='$value'. One of the values 'auto', 'meta' or 'esc' is expected." >&2
    return 1 ;;
  esac
}
function ble/decode/uses-isolated-esc {
  if [[ $bleopt_decode_isolated_esc == esc ]]; then
    return 0
  elif [[ $bleopt_decode_isolated_esc == auto ]]; then
    if local ret; bleopt/get:default_keymap; [[ $ret == vi ]]; then
      return 0
    elif [[ ! $_ble_decode_key__seq ]]; then
      local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_ key=$((_ble_decode_Ctrl|91))
      builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[key]-}"
      [[ ${ent:2} ]] && return 0
    fi
  fi

  return 1
}

## @bleopt decode_abort_char
bleopt/declare -n decode_abort_char 28

## @bleopt decode_macro_limit
bleopt/declare -n decode_macro_limit 1024

# **** key names ****

_ble_decode_Meta=0x08000000
_ble_decode_Ctrl=0x04000000
_ble_decode_Shft=0x02000000
_ble_decode_Hypr=0x01000000
_ble_decode_Supr=0x00800000
_ble_decode_Altr=0x00400000
_ble_decode_MaskChar=0x001FFFFF
_ble_decode_MaskFlag=0x7FC00000

## @var _ble_decode_Erro
##   文字復号に異常があった事を表します。
## @var _ble_decode_Macr
##   マクロ再生で生成された文字である事を表します。
_ble_decode_Erro=0x40000000
_ble_decode_Macr=0x20000000

_ble_decode_Flag3=0x10000000 # unused
_ble_decode_FlagA=0x00200000 # unused

_ble_decode_IsolatedESC=$((0x07FC))
_ble_decode_EscapedNUL=$((0x07FB)) # charlog#encode で用いる
_ble_decode_FunctionKeyBase=0x110000

## @fn ble/decode/mod2flag mod
##   @param[in] mod
##   @var[out] ret
function ble/decode/mod2flag {
  ret=0
  local mod=$1
  # Note: Supr 0x08 以降は独自
  ((mod&0x01&&(ret|=_ble_decode_Shft),
    mod&0x02&&(ret|=_ble_decode_Meta),
    mod&0x04&&(ret|=_ble_decode_Ctrl),
    mod&0x08&&(ret|=_ble_decode_Supr),
    mod&0x10&&(ret|=_ble_decode_Hypr),
    mod&0x20&&(ret|=_ble_decode_Altr)))
}
## @fn ble/decode/flag2mod flag
##   @param[in] flag
##   @var[out] ret
function ble/decode/flag2mod {
  ret=0
  local flag=$1
  ((flag&_ble_decode_Shft&&(ret|=0x01),
    flag&_ble_decode_Meta&&(ret|=0x02),
    flag&_ble_decode_Ctrl&&(ret|=0x04),
    flag&_ble_decode_Supr&&(ret|=0x08),
    flag&_ble_decode_Hypr&&(ret|=0x10),
    flag&_ble_decode_Altr&&(ret|=0x20)))
}

## @fn ble-decode-kbd/.set-keycode keyname key
##
## @fn ble-decode-kbd/.get-keycode keyname
##   @var[out] ret
_ble_decode_kbd_ver=gdict
_ble_decode_kbd__n=0
_ble_decode_kbd__c2k=()
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_decode_kbd__k2c}"
ble/is-assoc _ble_decode_kbd__k2c || _ble_decode_kbd_ver=adict

function ble-decode-kbd/.set-keycode {
  local keyname=$1
  local code=$2
  : "${_ble_decode_kbd__c2k[code]:=$keyname}"
  ble/gdict#set _ble_decode_kbd__k2c "$keyname" "$code"
}
function ble-decode-kbd/.get-keycode {
  ble/gdict#get _ble_decode_kbd__k2c "$1"
}

## @fn ble-decode-kbd/.get-keyname keycode
##
##   keycode に対応するキーの名前を求めます。
##   対応するキーが存在しない場合には空文字列を返します。
##
##   @param[in] keycode keycode
##   @var[out]  ret     keyname
##
function ble-decode-kbd/.get-keyname {
  local keycode=$1
  ret=${_ble_decode_kbd__c2k[keycode]}
  if [[ ! $ret ]] && ((keycode<_ble_decode_FunctionKeyBase)); then
    ble/util/c2s "$keycode"
  fi
}
## @fn ble-decode-kbd/generate-keycode keyname
##   指定した名前に対応する keycode を取得します。
##   指定した名前の key が登録されていない場合は、
##   新しく keycode を割り当てて返します。
##   @param[in]  keyname keyname
##   @var  [out] ret     keycode
function ble-decode-kbd/generate-keycode {
  local keyname=$1
  if ((${#keyname}==1)); then
    ble/util/s2c "$1"
  elif [[ $keyname && ! ${keyname//[_a-zA-Z0-9]} ]]; then
    ble-decode-kbd/.get-keycode "$keyname"
    if [[ ! $ret ]]; then
      ((ret=_ble_decode_FunctionKeyBase+_ble_decode_kbd__n++))
      ble-decode-kbd/.set-keycode "$keyname" "$ret"
    fi
  else
    ret=-1
    return 1
  fi
}

function ble-decode-kbd/.initialize {
  ble-decode-kbd/.set-keycode TAB  9
  ble-decode-kbd/.set-keycode RET  13

  ble-decode-kbd/.set-keycode NUL  0
  ble-decode-kbd/.set-keycode SOH  1
  ble-decode-kbd/.set-keycode STX  2
  ble-decode-kbd/.set-keycode ETX  3
  ble-decode-kbd/.set-keycode EOT  4
  ble-decode-kbd/.set-keycode ENQ  5
  ble-decode-kbd/.set-keycode ACK  6
  ble-decode-kbd/.set-keycode BEL  7
  ble-decode-kbd/.set-keycode BS   8
  ble-decode-kbd/.set-keycode HT   9  # aka TAB
  ble-decode-kbd/.set-keycode LF   10
  ble-decode-kbd/.set-keycode VT   11
  ble-decode-kbd/.set-keycode FF   12
  ble-decode-kbd/.set-keycode CR   13 # aka RET
  ble-decode-kbd/.set-keycode SO   14
  ble-decode-kbd/.set-keycode SI   15

  ble-decode-kbd/.set-keycode DLE  16
  ble-decode-kbd/.set-keycode DC1  17
  ble-decode-kbd/.set-keycode DC2  18
  ble-decode-kbd/.set-keycode DC3  19
  ble-decode-kbd/.set-keycode DC4  20
  ble-decode-kbd/.set-keycode NAK  21
  ble-decode-kbd/.set-keycode SYN  22
  ble-decode-kbd/.set-keycode ETB  23
  ble-decode-kbd/.set-keycode CAN  24
  ble-decode-kbd/.set-keycode EM   25
  ble-decode-kbd/.set-keycode SUB  26
  ble-decode-kbd/.set-keycode ESC  27
  ble-decode-kbd/.set-keycode FS   28
  ble-decode-kbd/.set-keycode GS   29
  ble-decode-kbd/.set-keycode RS   30
  ble-decode-kbd/.set-keycode US   31

  ble-decode-kbd/.set-keycode SP   32
  ble-decode-kbd/.set-keycode DEL  127

  ble-decode-kbd/.set-keycode PAD  128
  ble-decode-kbd/.set-keycode HOP  129
  ble-decode-kbd/.set-keycode BPH  130
  ble-decode-kbd/.set-keycode NBH  131
  ble-decode-kbd/.set-keycode IND  132
  ble-decode-kbd/.set-keycode NEL  133
  ble-decode-kbd/.set-keycode SSA  134
  ble-decode-kbd/.set-keycode ESA  135
  ble-decode-kbd/.set-keycode HTS  136
  ble-decode-kbd/.set-keycode HTJ  137
  ble-decode-kbd/.set-keycode VTS  138
  ble-decode-kbd/.set-keycode PLD  139
  ble-decode-kbd/.set-keycode PLU  140
  ble-decode-kbd/.set-keycode RI   141
  ble-decode-kbd/.set-keycode SS2  142
  ble-decode-kbd/.set-keycode SS3  143

  ble-decode-kbd/.set-keycode DCS  144
  ble-decode-kbd/.set-keycode PU1  145
  ble-decode-kbd/.set-keycode PU2  146
  ble-decode-kbd/.set-keycode STS  147
  ble-decode-kbd/.set-keycode CCH  148
  ble-decode-kbd/.set-keycode MW   149
  ble-decode-kbd/.set-keycode SPA  150
  ble-decode-kbd/.set-keycode EPA  151
  ble-decode-kbd/.set-keycode SOS  152
  ble-decode-kbd/.set-keycode SGCI 153
  ble-decode-kbd/.set-keycode SCI  154
  ble-decode-kbd/.set-keycode CSI  155
  ble-decode-kbd/.set-keycode ST   156
  ble-decode-kbd/.set-keycode OSC  157
  ble-decode-kbd/.set-keycode PM   158
  ble-decode-kbd/.set-keycode APC  159

  ble-decode-kbd/.set-keycode @ESC "$_ble_decode_IsolatedESC"
  ble-decode-kbd/.set-keycode @NUL "$_ble_decode_EscapedNUL"

  local ret
  ble-decode-kbd/generate-keycode __batch_char__
  _ble_decode_KCODE_BATCH_CHAR=$ret
  ble-decode-kbd/generate-keycode __defchar__
  _ble_decode_KCODE_DEFCHAR=$ret
  ble-decode-kbd/generate-keycode __default__
  _ble_decode_KCODE_DEFAULT=$ret
  ble-decode-kbd/generate-keycode __before_widget__
  _ble_decode_KCODE_BEFORE_WIDGET=$ret
  ble-decode-kbd/generate-keycode __after_widget__
  _ble_decode_KCODE_AFTER_WIDGET=$ret
  ble-decode-kbd/generate-keycode __attach__
  _ble_decode_KCODE_ATTACH=$ret
  ble-decode-kbd/generate-keycode __detach__
  _ble_decode_KCODE_DETACH=$ret

  ble-decode-kbd/generate-keycode shift
  _ble_decode_KCODE_SHIFT=$ret
  ble-decode-kbd/generate-keycode alter
  _ble_decode_KCODE_ALTER=$ret
  ble-decode-kbd/generate-keycode control
  _ble_decode_KCODE_CONTROL=$ret
  ble-decode-kbd/generate-keycode meta
  _ble_decode_KCODE_META=$ret
  ble-decode-kbd/generate-keycode super
  _ble_decode_KCODE_SUPER=$ret
  ble-decode-kbd/generate-keycode hyper
  _ble_decode_KCODE_HYPER=$ret

  # Note: 無視するキー。ble-decode-char に於いて
  #   端末からの通知などを処理した時に使う。
  ble-decode-kbd/generate-keycode __ignore__
  _ble_decode_KCODE_IGNORE=$ret

  # Note: bleopt decode_error_cseq_discard
  ble-decode-kbd/generate-keycode __error__
  _ble_decode_KCODE_ERROR=$ret

  # Note: line_limit による制限超過時のイベント
  ble-decode-kbd/generate-keycode __line_limit__
  _ble_decode_KCODE_LINE_LIMIT=$ret

  # Note: 暫定的な対応なので後で変更するかもしれない
  ble-decode-kbd/generate-keycode mouse
  _ble_decode_KCODE_MOUSE=$ret
  ble-decode-kbd/generate-keycode mouse_move
  _ble_decode_KCODE_MOUSE_MOVE=$ret

  # Note: 以下は改めてそれぞれのファイルで参照される
  #   コードを固定する為にここで定義しておく。
  ble-decode-kbd/generate-keycode auto_complete_enter

  # Note: ここに新しく kcode を追加した時には init-cmap.sh に何か変更をして、
  # cmap 及び keymap が更新される様にする必要がある。emacs.sh, vi.sh については
  # init-cmap.sh を見て自動的に更新されるので特別な処置は必要ない筈。
}

ble-decode-kbd/.initialize

## @fn ble-decode-kbd [TYPE:]VALUE...
##   @param[in] TYPE VALUE
##     キー列を指定します。TYPE はキー列の解釈方法を指定します。
##     TYPE の値に応じて VALUE には以下の物を指定します。TYPE の既定値は kbd です。
##     kspecs ... kspecs を指定します。
##     keys   ... キーコードの整数列を指定します。
##     chars  ... 文字コードの整数列を指定します。
##     keyseq ... bash bind の keyseq を指定します。
##     raw    ... バイト列を直接文字列として指定します。
##
##   @var[out] ret
##     キー列を空白区切りの整数列として返します。
function ble-decode-kbd {
  local IFS=$_ble_term_IFS
  local spec="$*"
  case $spec in
  (keys:*)
    ret="${spec#*:}"
    return 0 ;;
  (chars:*)
    local chars
    ble/string#split-words chars "${spec#*:}"
    ble/decode/cmap/decode-chars "${ret[@]}"
    ret="${keys[*]}"
    return 0 ;;
  (keyseq:*) # i.e. untranslated keyseq
    local keys
    ble/util/keyseq2chars "${spec#*:}"
    ble/decode/cmap/decode-chars "${ret[@]}"
    ret="${keys[*]}"
    return 0 ;;
  (raw:*) # i.e. translated keyseq
    ble/util/s2chars "${spec#*:}"
    ble/decode/cmap/decode-chars "${ret[@]}"
    ret="${keys[*]}"
    return 0 ;;
  (kspecs:*)
    spec=${spec#*:} ;;
  esac

  local kspecs; ble/string#split-words kspecs "$spec"
  local kspec code codes
  codes=()
  for kspec in "${kspecs[@]}"; do
    code=0
    while [[ $kspec == ?-* ]]; do
      case ${kspec::1} in
      (S) ((code|=_ble_decode_Shft)) ;;
      (C) ((code|=_ble_decode_Ctrl)) ;;
      (M) ((code|=_ble_decode_Meta)) ;;
      (A) ((code|=_ble_decode_Altr)) ;;
      (s) ((code|=_ble_decode_Supr)) ;;
      (H) ((code|=_ble_decode_Hypr)) ;;
      (*) ((code|=_ble_decode_Erro)) ;;
      esac
      kspec=${kspec:2}
    done

    if [[ $kspec == ? ]]; then
      ble/util/s2c "$kspec"
      ((code|=ret))
    elif [[ $kspec && ! ${kspec//[@_a-zA-Z0-9]} ]]; then
      ble-decode-kbd/.get-keycode "$kspec"
      [[ $ret ]] || ble-decode-kbd/generate-keycode "$kspec"
      ((code|=ret))
    elif [[ $kspec == ^? ]]; then
      if [[ $kspec == '^?' ]]; then
        ((code|=0x7F))
      elif [[ $kspec == '^`' ]]; then
        ((code|=0x20))
      else
        ble/util/s2c "${kspec:1}"
        ((code|=ret&0x1F))
      fi
    elif local rex='^U\+([0-9a-fA-F]+)$'; [[ $kspec =~ $rex ]]; then
      ((code|=0x${BASH_REMATCH[1]}))
    else
      ((code|=_ble_decode_Erro))
    fi

    codes[${#codes[@]}]=$code
  done

  ret="${codes[*]}"
}

## @fn ble-decode-unkbd/.single-key key
##   @var[in] key
##     キーを表す整数値
##   @var[out] ret
##     key の文字列表現を返します。
function ble-decode-unkbd/.single-key {
  local key=$1

  local f_unknown=
  local char=$((key&_ble_decode_MaskChar))
  ble-decode-kbd/.get-keyname "$char"
  if [[ ! $ret ]]; then
    f_unknown=1
    ret=__UNKNOWN__
  fi

  ((key&_ble_decode_Shft)) && ret=S-$ret
  ((key&_ble_decode_Meta)) && ret=M-$ret
  ((key&_ble_decode_Ctrl)) && ret=C-$ret
  ((key&_ble_decode_Altr)) && ret=A-$ret
  ((key&_ble_decode_Supr)) && ret=s-$ret
  ((key&_ble_decode_Hypr)) && ret=H-$ret

  [[ ! $f_unknown ]]
}

## @fn ble-decode-unkbd keys...
##   @param[in] keys
##     キーを表す整数値の列を指定します。
##   @var[out] ret
function ble-decode-unkbd {
  local IFS=$_ble_term_IFS
  local -a kspecs
  local key
  for key in $*; do
    ble-decode-unkbd/.single-key "$key"
    kspecs[${#kspecs[@]}]=$ret
  done
  ret="${kspecs[*]}"
}

## @fn ble/decode/keys2chars keys...
##   指定したキーの列を生成する文字の列を作成します。
##   @param[in] keys
##   @arr[out] ret
function ble/decode/keys2chars {
  local -a keys=()
  local key
  for key; do
    local flag=$((key&_ble_decode_MaskFlag))
    local char=$((key&_ble_decode_MaskChar))
    if ((flag&_ble_decode_Meta)); then
      ble/array#push keys 27
      ((flag&=~_ble_decode_Meta))
    fi

    # C-?, C-@, C-a..C-z, C-[..C-_ は DEL 及び C0 に変換する
    if ((flag==_ble_decode_Ctrl&&(char==63||char==64||91<=char&&char<=95||97<=char&&char<=122))); then
      ble/array#push keys "$((char==63?127:(char&0x1F)))"
      continue
    fi

    local mod_param=
    if ((flag)); then
      ble/decode/flag2mod "$flag"
      mod_param=$((ret+1))
    fi

    local csi=${_ble_decode_csimap_dict[char]-}
    if [[ $csi == tilde:* ]]; then
      local params=${csi#*:}
      if [[ $mod_param ]]; then
        params=$params';'$mod_param
      fi
      ble/util/s2chars "$params"
      ble/array#push keys 27 91 "${ret[@]}" 126
    elif [[ $csi == alpha:* ]]; then
      if [[ $mod_param ]]; then
        ble/util/s2chars "1;$mod_param"
      else
        ret=()
      fi
      ble/array#push keys 27 91 "${ret[@]}" "${csi#*:}"
    elif ((flag||char>=_ble_decode_FunctionKeyBase)); then
      ble/util/s2chars "27;${mod_param:-1};$char"
      ble/array#push keys 27 91 "${ret[@]}" 126
    else
      ble/array#push keys "$char"
    fi
  done
  ret=("${keys[@]}")
}

# **** ble-decode-byte ****

## @fn[custom] ble-decode/PROLOGUE
## @fn[custom] ble-decode/EPILOGUE
function ble-decode/PROLOGUE { return 0; }
function ble-decode/EPILOGUE { return 0; }

_ble_decode_input_buffer=()
_ble_decode_input_count=0
_ble_decode_input_original_info=()

_ble_decode_show_progress_hook=ble-decode/.hook/show-progress
_ble_decode_erase_progress_hook=ble-decode/.hook/erase-progress
function ble-decode/.hook/show-progress {
  if [[ $_ble_edit_info_scene == store ]]; then
    _ble_decode_input_original_info=("${_ble_edit_info[@]}")
    return 0
  elif [[ $_ble_edit_info_scene == default ]]; then
    _ble_decode_input_original_info=()
  elif [[ $_ble_edit_info_scene != decode_input_progress ]]; then
    return 0
  fi

  local progress_opts= opt_percentage=1
  if [[ $ble_batch_insert_count ]]; then
    local total=$ble_batch_insert_count
    local value=$ble_batch_insert_index
    local label='constructing text...'
    local sgr=$'\e[1;38;5;204;48;5;253m'
  elif ((${#_ble_decode_input_buffer[@]})); then
    local total=10000
    local value=$((${#_ble_decode_input_buffer[@]}%10000))
    local label="${#_ble_decode_input_buffer[@]} bytes received..."
    local sgr=$'\e[1;38;5;135;48;5;253m'
    progress_opts=unlimited
    opt_percentage=
  elif ((_ble_decode_input_count)); then
    local total=${#chars[@]}
    local value=$((total-_ble_decode_input_count-1))
    local label='decoding input...'
    local sgr=$'\e[1;38;5;69;48;5;253m'
  elif ((ble_decode_char_total)); then
    local total=$ble_decode_char_total
    local value=$((total-ble_decode_char_rest-1))
    local label='processing input...'
    local sgr=$'\e[1;38;5;71;48;5;253m'
  else
    return 0
  fi

  if [[ $opt_percentage ]]; then
    local mill=$((value*1000/total))
    local cent=${mill::${#mill}-1} frac=${mill:${#mill}-1}
    label="${cent:-0}.$frac% $label"
  fi

  local text="($label)"
  if ble/util/is-unicode-output; then
    local ret
    ble/string#create-unicode-progress-bar "$value" "$total" 10 "$progress_opts"
    text=$sgr$ret$'\e[m '$text
  fi

  ble/edit/info/show ansi "$text"

  _ble_edit_info_scene=decode_input_progress
}
function ble-decode/.hook/erase-progress {
  [[ $_ble_edit_info_scene == decode_input_progress ]] || return 1
  if ((${#_ble_decode_input_original_info[@]})); then
    ble/edit/info/show store "${_ble_decode_input_original_info[@]}"
  else
    ble/edit/info/default
  fi
}

## @fn ble-decode/.check-abort byte
##   bleopt_decode_abort_char による decode abort を検出します。
##
##   @remarks modifyOtherKeys も考慮に入れると実は C-x の形式のキーは
##   "CSI 27;5; code ~" や "CSI code ;5u" の形式で送られてくる。
##   _ble_decode_input_buffer に記録されている受信済みバイトも検査して
##   これらのシーケンスを構成していないか確認する必要がある。
##
function ble-decode/.check-abort {
  if (($1==bleopt_decode_abort_char)); then
    local nbytes=${#_ble_decode_input_buffer[@]}
    local nchars=${#_ble_decode_char_buffer[@]}
    ((nbytes||nchars)); return "$?"
  fi

  (($1==0x7e||$1==0x75)) || return 1

  local i=$((${#_ble_decode_input_buffer[@]}-1))
  local n
  ((n=bleopt_decode_abort_char,
    n+=(1<=n&&n<=26?96:64)))

  if (($1==0x7e)); then
    # Check "CSI >? 27 ; 5 ; XXX ~"

    # Check code
    for ((;n;n/=10)); do
      ((i>=0)) && ((_ble_decode_input_buffer[i--]==n%10+48)) || return 1
    done

    # Check "27;5;"
    ((i>=4)) || return 1
    ((_ble_decode_input_buffer[i--]==59)) || return 1
    ((_ble_decode_input_buffer[i--]==53)) || return 1
    ((_ble_decode_input_buffer[i--]==59)) || return 1
    ((_ble_decode_input_buffer[i--]==55)) || return 1
    ((_ble_decode_input_buffer[i--]==50)) || return 1

  elif (($1==0x75)); then
    # Check "CSI >? XXX ; 5 u"

    # Check ";5"
    ((i>=1)) || return 1
    ((_ble_decode_input_buffer[i--]==53)) || return 1
    ((_ble_decode_input_buffer[i--]==59)) || return 1

    # Check code
    for ((;n;n/=10)); do
      ((i>=0)) && ((_ble_decode_input_buffer[i--]==n%10+48)) || return 1
    done
  fi

  # Skip ">"
  ((i>=0)) && ((_ble_decode_input_buffer[i]==62&&i--))

  # Check CSI ("\e[", "\xC0\x9B[" or "\xC2\x9B")
  # ENCODING: UTF-8 (\xC0\x9B)
  ((i>=0)) || return 1
  if ((_ble_decode_input_buffer[i]==0x5B)); then
    if ((i>=1&&_ble_decode_input_buffer[i-1]==0x1B)); then
      ((i-=2))
    elif ((i>=2&&_ble_decode_input_buffer[i-1]==0x9B&&_ble_decode_input_buffer[i-2]==0xC0)); then
      ((i-=3))
    else
      return 1
    fi
  elif ((_ble_decode_input_buffer[i]==0x9B)); then
    ((--i>=0)) && ((_ble_decode_input_buffer[i--]==0xC2)) || return 1
  else
    return 1
  fi
  (((i>=0||${#_ble_decode_char_buffer[@]}))); return "$?"
  return 0
}

if ((_ble_bash>=40400)); then
  function ble/decode/nonblocking-read {
    local timeout=${1:-0.01} ntimeout=${2:-1} loop=${3:-100}
    local LC_ALL= LC_CTYPE=C IFS=
    local -a data=()
    local line buff ext
    while ((loop--)); do
      ble/bash/read-timeout "$timeout" -r -d '' buff; ext=$?
      [[ $buff ]] && line=$line$buff
      if ((ext==0)); then
        ble/array#push data "$line"
        line=
      elif ((ext>128)); then
        # timeout
        ((--ntimeout)) || break
        [[ $buff ]] || break
      else
        break
      fi
    done

    ble/util/assign ret '{
      ((${#data[@]})) && printf %s\\0 "${data[@]}"
      [[ $line ]] && printf %s "$line"
    } | ble/bin/od -A n -t u1 -v'
    ble/string#split-words ret "$ret"
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/decode/nonblocking-read
elif ((_ble_bash>=40000)); then
  function ble/decode/nonblocking-read {
    local timeout=${1:-0.01} ntimeout=${2:-1} loop=${3:-100}
    local LC_ALL= LC_CTYPE=C IFS= 2>/dev/null
    local -a data=()
    local line buff
    while ((loop--)); do
      builtin read -t 0 || break
      ble/bash/read -d '' -n 1 buff || break
      if [[ $buff ]]; then
        line=$line$buff
      else
        ble/array#push data "$line"
        line=
      fi
    done

    ble/util/assign ret '{
      ((${#data[@]})) && printf %s\\0 "${data[@]}"
      [[ $line ]] && printf %s "$line"
    } | ble/bin/od -A n -t u1 -v'
    ble/string#split-words ret "$ret"
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/decode/nonblocking-read
fi

function ble-decode/.hook/adjust-volatile-options {
  # Note: bind -x 内の set +v は揮発性なのでできるだけ先頭で set +v しておく。
  # (PROLOGUE 内から呼ばれる) stdout.on より前であれば大丈夫 #D0930
  if [[ $_ble_bash_options_adjusted ]]; then
    set +ev
  fi
  # Note (#D2221): We moved « builtin eval --
  # "$_ble_bash_POSIXLY_CORRECT_unset" » outside this function because of 5.3
  # slash in function names.
}

## @var _ble_decode_hook_count
##   これまでに呼び出された _ble_decode_hook の回数を記録する。(同じ
##   bash プロセス内の前の ble.sh session も含めて) 今までに一度も呼び
##   出された事がない場合には空文字列を設定する。
_ble_decode_hook_count=${_ble_decode_hook_count:+0}
_ble_decode_hook_Processing=
## @fn _ble_decode_hook bytes...
##   Note (#D2221): We have been used the function name "ble-decode/.hook", but
##   we now need to switch to "_ble_decode_hook" because Bash 5.3 started to
##   ignore function names with slashes in the POSIX mode.
function _ble_decode_hook {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_unset"
#%if leakvar
ble/debug/leakvar#check $"leakvar" H0-begin
#%end.i
  ((_ble_decode_hook_count++))
  if ble/util/is-stdin-ready; then
    ble/array#push _ble_decode_input_buffer "$@"

    local buflen=${#_ble_decode_input_buffer[@]}
    if ((buflen%257==0&&buflen>=2000)); then
      ble-decode/.hook/adjust-volatile-options

      local IFS=$_ble_term_IFS
      local _ble_decode_hook_Processing=prologue
      ble-decode/PROLOGUE
      _ble_decode_hook_Processing=body

      # その場で標準入力を読み切る
      local char=${_ble_decode_input_buffer[buflen-1]}
      if ((_ble_bash<40000||char==0xC0||char==0xDF)); then
        # Note: これらの文字は bind -s マクロの非終端文字 (0xC0 for two-byte
        # representations of C0 characters in the form \xC0\x??, 0xDF for
        # Isolated ESC U+07FC represented as \xDF\xBC)。現在マクロの処理中であ
        # る可能性があるので標準入力から読み取るとバイトの順序が変わる可能性が
        # ある。従って読み取りは行わない。
        builtin eval -- "$_ble_decode_show_progress_hook"
      else
        while ble/util/is-stdin-ready; do
          builtin eval -- "$_ble_decode_show_progress_hook"
          local ret; ble/decode/nonblocking-read 0.02 1 527
          ble/array#push _ble_decode_input_buffer "${ret[@]}"
        done
      fi
      _ble_decode_hook_Processing=epilogue
      ble-decode/EPILOGUE
      ble/util/unlocal _ble_decode_hook_Processing
#%if leakvar
ble/debug/leakvar#check $"leakvar" H0b1-1
#%end.i

      local ret
      ble/array#pop _ble_decode_input_buffer
      _ble_decode_hook "$ret"
#%if leakvar
ble/debug/leakvar#check $"leakvar" H0b1-2
#%end.i
    fi
#%if leakvar
ble/debug/leakvar#check $"leakvar" H0b2
#%end.i

    return 0
  fi

  ble-decode/.hook/adjust-volatile-options

  local IFS=$_ble_term_IFS
  local _ble_decode_hook_Processing=prologue
  ble-decode/PROLOGUE
  _ble_decode_hook_Processing=body
#%if leakvar
ble/debug/leakvar#check $"leakvar" H1-PROLOGUE
#%end.i

  # abort #D0998
  if ble-decode/.check-abort "$1"; then
    _ble_decode_char__hook=
    _ble_decode_input_buffer=()
    _ble_decode_char_buffer=()
    ble/term/visible-bell "Abort by 'bleopt decode_abort_char=$bleopt_decode_abort_char'"
    shift
    # 何れにしても EPILOGUE を実行する必要があるので下に流れる。
    # ble/term/visible-bell を表示する為には PROLOGUE の後でなければならない事にも注意する。
  fi
#%if leakvar
ble/debug/leakvar#check $"leakvar" H2-abort
#%end.i

  local chars
  # Note: Bash-4.4 で遅いので ble/array#set 経由で設定する
  ble/array#set chars "${_ble_decode_input_buffer[@]}" "$@"
  _ble_decode_input_buffer=()
  _ble_decode_input_count=${#chars[@]}

  if ((_ble_decode_input_count>=200)); then
    local i N=${#chars[@]}
    local B=$((N/100))
    ((B<100)) && B=100 || ((B>1000)) && B=1000
    for ((i=0;i<N;i+=B)); do
      ((_ble_decode_input_count=N-i-B))
      ((_ble_decode_input_count<0)) && _ble_decode_input_count=0
      builtin eval -- "$_ble_decode_show_progress_hook"
#%if debug_keylogger
      ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_bytes "${chars[@]:i:B}"
#%end
#%if leakvar
ble/debug/leakvar#check $"leakvar" "[H3b1: before decode $chars...]"
#%end.i
      ble/encoding:"$bleopt_input_encoding/decode" "${chars[@]:i:B}"
#%if leakvar
ble/debug/leakvar#check $"leakvar" "[H3b1: after decode $chars...]"
#%end.i
    done
  else
    local c
    for c in "${chars[@]}"; do
      ((--_ble_decode_input_count))
#%if debug_keylogger
      ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_bytes "$c"
#%end
#%if leakvar
ble/debug/leakvar#check $"leakvar" "[H3b2: before decode $c]"
#%end.i
      ble/encoding:"$bleopt_input_encoding/decode" "$c"
#%if leakvar
ble/debug/leakvar#check $"leakvar" "[H3b2: after decode $c]"
#%end.i
    done
  fi

#%if leakvar
ble/debug/leakvar#check $"leakvar" H4
#%end.i
  ble/decode/has-input || ble-decode-key/batch/flush
#%if leakvar
ble/debug/leakvar#check $"leakvar" H4-batch
#%end.i

  builtin eval -- "$_ble_decode_erase_progress_hook"
  _ble_decode_hook_Processing=epilogue
  ble-decode/EPILOGUE
#%if leakvar
ble/debug/leakvar#check $"leakvar" H4-EPILOGUE
#%end.i
}

## @fn ble-decode-byte bytes...
##   バイト値を整数で受け取って、現在の文字符号化方式に従ってデコードをします。
##   デコードした結果得られた文字は ble-decode-char を呼び出す事によって処理します。
##
##   Note: 現在 ble.sh 内部では使用されていません。
##     この関数はユーザが呼び出す事を想定した関数です。
function ble-decode-byte {
  while (($#)); do
    ble/encoding:"$bleopt_input_encoding"/decode "$1"
    shift
  done
}

# **** ble-decode-char/csi ****

_ble_decode_csi_mode=0
_ble_decode_csi_args=
_ble_decode_csimap_tilde=()
_ble_decode_csimap_alpha=()
_ble_decode_csimap_dict=()
function ble-decode-char/csi/print/.print-csidef {
  local qalpha qkey ret q=\' Q="'\''"
  if [[ $sgrq ]]; then
    ble/string#quote-word "$1" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qalpha=$ret
    ble/string#quote-word "$2" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qkey=$ret
  else
    qalpha="'${1//$q/$Q}'"
    qkey="'${2//$q/$Q}'"
  fi
  ble/util/print "${sgrf}ble-bind$sgr0 $sgro--csi$sgr0 $qalpha $qkey"

}
## @fn ble-decode-char/csi/print
##   @var[in] ble_bind_print sgr0 sgrf sgrq sgrc sgro
function ble-decode-char/csi/print {
  [[ $ble_bind_print ]] || local sgr0= sgrf= sgrq= sgrc= sgro=
  local num ret
  for num in "${!_ble_decode_csimap_tilde[@]}"; do
    ble-decode-unkbd "${_ble_decode_csimap_tilde[num]}"
    ble-decode-char/csi/print/.print-csidef "$num~" "$ret"
  done

  for num in "${!_ble_decode_csimap_alpha[@]}"; do
    local s; ble/util/c2s "$num"; s=$ret
    ble-decode-unkbd "${_ble_decode_csimap_alpha[num]}"
    ble-decode-char/csi/print/.print-csidef "$s" "$ret"
  done
}

function ble-decode-char/csi/clear {
  _ble_decode_csi_mode=0
}

# Initialized in lib/init-cmap.sh
_ble_decode_csimap_kitty_u=()

## @fn ble-decode/char/csi/.translate-kitty-csi-u
##   @var[in,out] key
function ble-decode/char/csi/.translate-kitty-csi-u {
  local name=${_ble_decode_csimap_kitty_u[key]}
  if [[ $name ]]; then
    local ret
    ble-decode-kbd/generate-keycode "$name"
    key=$ret
  fi
}
function ble-decode-char/csi/.modify-key {
  local mod=$(($1-1))
  if ((mod>=0)); then
    # Note: xterm, mintty では modifyOtherKeys で通常文字に対するシフトは
    #   文字自体もそれに応じて変化させ、更に修飾フラグも設定する。
    # Note: RLogin は修飾がある場合は常に英大文字に統一する。
    if ((33<=key&&key<_ble_decode_FunctionKeyBase)); then
      local term=${_ble_term_TERM[0]+${_ble_term_TERM[${#_ble_term_TERM[@]}-1]}}
      if (((mod&0x01)&&0x31<=key&&key<=0x39)) && [[ $term == RLogin:* ]]; then
        # RLogin は数字に対する S- 修飾の解決はしてくれない。
        ((key-=16,mod&=~0x01))
      elif ((mod==0x01)); then
        if [[ $term != contra:* ]]; then
          # S- だけの時には単に S- を外す
          ((mod&=~0x01))
        fi
      elif ((65<=key&&key<=90)); then
        # 他の修飾がある時は英大文字は小文字に統一する
        ((key|=0x20))
      fi
    fi

    local ret
    ble/decode/mod2flag "$mod"
    ((key|=ret))
  fi
}
function ble-decode-char/csi/.decode {
  local char=$1 rex key
  if ((char==126)); then # ~
    if rex='^>?27;([0-9]+);?([0-9]+)$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # xterm "CSI 2 7 ; <mod> ; <char> ~" sequences
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param2=$((10#0${BASH_REMATCH[2]}))
      local key=$((param2&_ble_decode_MaskChar))
      ble-decode-char/csi/.modify-key "$param1"
      csistat=$key
      return 0
    fi

    if rex='^>?([0-9]+)(;([0-9]+))?$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # "CSI <key> ; <mod> ~" sequences
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param3=$((10#0${BASH_REMATCH[3]}))
      key=${_ble_decode_csimap_tilde[param1]}
      if [[ $key ]]; then
        ble-decode-char/csi/.modify-key "$param3"
        csistat=$key
        return 0
      fi
    fi
  elif ((char==117)); then # u
    if rex='^([0-9]*)(;[0-9]*)?$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # xterm/mlterm "CSI <char> ; <mode> u" sequences
      # Note: 実は "CSI 1 ; mod u" が kp5 とする端末がある事に注意する。
      local rematch1=${BASH_REMATCH[1]}
      if [[ $rematch1 != 1 ]]; then
        local key=$((10#0$rematch1)) mods=$((10#0${BASH_REMATCH:${#rematch1}+1}))
        [[ $_ble_term_TERM == kitty:* ]] && ble-decode/char/csi/.translate-kitty-csi-u
        ble-decode-char/csi/.modify-key "$mods"
        csistat=$key
      fi
      return 0
    fi
  elif ((char==94||char==64)); then # ^, @
    if rex='^[0-9]+$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # rxvt "CSI <key> ^", "CSI <key> @" sequences
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param3=$((10#0${BASH_REMATCH[3]}))
      key=${_ble_decode_csimap_tilde[param1]}
      if [[ $key ]]; then
        ((key|=_ble_decode_Ctrl,
          char==64&&(key|=_ble_decode_Shft)))
        ble-decode-char/csi/.modify-key "$param3"
        csistat=$key
        return 0
      fi
    fi
  elif ((char==99)); then # c
    if rex='^[?>]'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # DA1 応答 "CSI ? Pm c" (何故か DA2 要求に対して DA1 で返す端末がある?)
      # DA2 応答 "CSI > Pm c"
      if [[ $_ble_decode_csi_args == '?'* ]]; then
        ble/term/DA1/notify "${_ble_decode_csi_args:1}"
      else
        ble/term/DA2/notify "${_ble_decode_csi_args:1}"
      fi
      csistat=$_ble_decode_KCODE_IGNORE
      return 0
    fi
  elif ((char==82||char==110)); then # R or n
    if rex='^([0-9]+);([0-9]+)$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # DSR(6) に対する応答 CPR "CSI Pn ; Pn R"
      # Note: Poderosa は DSR(Pn;Pn) "CSI Pn ; Pn n" で返す。
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param2=$((10#0${BASH_REMATCH[2]}))
      ble/term/CPR/notify "$param1" "$param2"
      csistat=$_ble_decode_KCODE_IGNORE
      return 0
    fi
  elif ((char==77||char==109)); then # M or m
    if rex='^<([0-9]+);([0-9]+);([0-9]+)$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # マウスイベント
      #   button の bit 達
      #     modifiers (mask 0x1C): 4  shift, 8  meta, 16 control
      #     button: 0 mouse1, 1 mouse2, 2 mouse3, 3 release, 64 wheel_up, 65 wheel_down
      #     他のフラグ: 32 移動
      #   可能な button のパターン:
      #     mouse1 mouse2 mouse3 mouse4 mouse5
      #     mouse1up mouse2up mouse3up mouse4up mouse5up
      #     mouse1drag mouse2drag mouse3drag mouse4drag mouse5drag
      #     wheelup wheeldown mouse_move
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param2=$((10#0${BASH_REMATCH[2]}))
      local param3=$((10#0${BASH_REMATCH[3]}))
      local button=$param1
      ((_ble_term_mouse_button=button&~0x1C,
        char==109&&(_ble_term_mouse_button|=0x70),
        _ble_term_mouse_x=param2-1,
        _ble_term_mouse_y=param3-1))
      local key=$_ble_decode_KCODE_MOUSE
      ((button&32)) && key=$_ble_decode_KCODE_MOUSE_MOVE
      ble-decode-char/csi/.modify-key "$((button>>2&0x07))"
      csistat=$key
      return 0
    fi
  elif ((char==116)); then # t
    if rex='^<([0-9]+);([0-9]+)$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      ## mouse_select
      local param1=$((10#0${BASH_REMATCH[1]}))
      local param2=$((10#0${BASH_REMATCH[2]}))
      ((_ble_term_mouse_button=128,
        _ble_term_mouse_x=param1-1,
        _ble_term_mouse_y=param2-1))
      local key=$_ble_decode_KCODE_MOUSE
      csistat=$key
    fi
  fi

  # pc-style "CSI 1; <mod> A" sequences
  key=${_ble_decode_csimap_alpha[char]}
  if [[ $key ]]; then
    if rex='^(1?|>?1;([0-9]+))$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      local param2=$((10#0${BASH_REMATCH[2]}))
      ble-decode-char/csi/.modify-key "$param2"
      csistat=$key
      return 0
    fi
  fi

  csistat=$_ble_decode_KCODE_ERROR
}

## @fn ble-decode-char/csi/consume char
##   @param[in] char
##   @var[out] csistat
function ble-decode-char/csi/consume {
  csistat=

  # 一番頻度の高い物
  ((_ble_decode_csi_mode==0&&$1!=27&&$1!=155)) && return 1

  local char=$1
  case $_ble_decode_csi_mode in
  (0)
    # CSI (155) もしくは ESC (27)
    ((_ble_decode_csi_mode=$1==155?2:1))
    _ble_decode_csi_args=
    csistat=_ ;;
  (1)
    if ((char!=91)); then
      _ble_decode_csi_mode=0
      return 1
    else
      _ble_decode_csi_mode=2
      _ble_decode_csi_args=
      csistat=_
    fi ;;
  (2)
    if ((32<=char&&char<64)); then
      local ret; ble/util/c2s "$char"
      _ble_decode_csi_args=$_ble_decode_csi_args$ret
      csistat=_
    elif ((64<=char&&char<127)); then
      _ble_decode_csi_mode=0
      ble-decode-char/csi/.decode "$char"
      ((csistat==27)) && csistat=$_ble_decode_IsolatedESC
    else
      _ble_decode_csi_mode=0
    fi ;;
  esac
}

# **** ble-decode-char ****

# 内部で使用する変数
# ble_decode_char_nest=
# ble_decode_char_sync=
# ble_decode_char_rest=

_ble_decode_char_buffer=()
function ble/decode/has-input-for-char {
  ((_ble_decode_input_count)) ||
    { [[ ! $ble_decode_char_sync ]] && ble/util/is-stdin-ready; } ||
    ble/encoding:"$bleopt_input_encoding"/is-intermediate
}

_ble_decode_char__hook=

## @arr _ble_decode_cmap_${_ble_decode_char__seq}[char]
##   文字列からキーへの写像を保持する。
##   各要素は文字の列 ($_ble_decode_char__seq $char) に対する定義を保持する。
##   各要素は以下の形式の何れかである。
##   key+ 文字の列がキー key に一意に対応する事を表す。
##   _    文字の列が何らかのキーを表す文字列の prefix になっている事を表す。
##   key_ 文字の列がキー key に対応すると同時に、
##        他のキーの文字列の prefix になっている事を表す。
_ble_decode_cmap_=()

# _ble_decode_char__seq が設定されている時は、
# 必ず _ble_decode_char2_reach_key も設定されている様にする。
_ble_decode_char2_seq=
_ble_decode_char2_reach_key=
_ble_decode_char2_reach_seq=
_ble_decode_char2_modifier=
_ble_decode_char2_modkcode=
_ble_decode_char2_modseq=()
function ble-decode-char {
  # 入れ子の ble-decode-char 呼び出しによる入力は後で実行。
  if [[ $ble_decode_char_nest && ! $ble_decode_char_sync ]]; then
    ble/array#push _ble_decode_char_buffer "$@"
    return 148
  fi
  local ble_decode_char_nest=1

  local iloop=0
  local ble_decode_char_total=$#
  local ble_decode_char_rest=$#
  local ble_decode_char_char=
  # Note: ループ中で set -- ... を使っている。

  local chars ichar char ent
  chars=("$@") ichar=0
  while
    if ((iloop++%50==0)); then
      ((iloop>=200)) && builtin eval -- "$_ble_decode_show_progress_hook"
      if [[ ! $ble_decode_char_sync ]] && ble/decode/has-input-for-char; then
        ble/array#push _ble_decode_char_buffer "${chars[@]:ichar}"
        return 148
      fi
    fi
    # 入れ子の ble-decode-char 呼び出しによる入力。
    if ((${#_ble_decode_char_buffer[@]})); then
      ((ble_decode_char_total+=${#_ble_decode_char_buffer[@]}))
      ((ble_decode_char_rest+=${#_ble_decode_char_buffer[@]}))
      ble/array#set chars "${_ble_decode_char_buffer[@]}" "${chars[@]:ichar}"
      ichar=0
      _ble_decode_char_buffer=()
    fi
    ((ble_decode_char_rest))
  do
    char=${chars[ichar]}
    ble_decode_char_char=$char # 補正前 char (_ble_decode_Macr 判定の為)
    ((ble_decode_char_rest--,ichar++))
#%if debug_keylogger
    ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_chars "$char"
#%end
    if [[ $_ble_decode_keylog_chars_enabled ]]; then
      if ! ((char&_ble_decode_Macr)); then
        ble/array#push _ble_decode_keylog_chars "$char"
        ((_ble_decode_keylog_chars_count++))
      fi
    fi
    ((char&=~_ble_decode_Macr))

    # decode error character
    if ((char&_ble_decode_Erro)); then
      ((char&=~_ble_decode_Erro))
      if [[ $bleopt_decode_error_char_vbell ]]; then
        local name; ble/util/sprintf name 'U+%04x' "$char"
        ble/term/visible-bell "received a misencoded char $name"
      fi
      [[ $bleopt_decode_error_char_abell ]] && ble/term/audible-bell
      [[ $bleopt_decode_error_char_discard ]] && continue
      # ((char&_ble_decode_Erro)) : 最適化(過去 sequence は全部吐く)?
    fi

    # hook for quoted-insert etc
    if [[ $_ble_decode_char__hook ]]; then
      ((char==_ble_decode_IsolatedESC)) && char=27 # isolated ESC -> ESC
      local hook=$_ble_decode_char__hook
      _ble_decode_char__hook=
      ble-decode/widget/.call-async-read "$hook $char" "$char"
      continue
    fi

    ble-decode-char/.getent # -> ent
    if [[ ! $ent ]]; then
      # シーケンスが登録されていない時
      if [[ $_ble_decode_char2_reach_key ]]; then
        local key=$_ble_decode_char2_reach_key
        local seq=$_ble_decode_char2_reach_seq
        local rest=${_ble_decode_char2_seq:${#seq}}
        ble/string#split-words rest "${rest//_/ } $ble_decode_char_char"

        _ble_decode_char2_seq=
        _ble_decode_char2_reach_key=
        _ble_decode_char2_reach_seq=
        ble-decode-char/csi/clear

        ble/decode/send-unmodified-key "$key" "$seq"
        ((ble_decode_char_total+=${#rest[@]}))
        ((ble_decode_char_rest+=${#rest[@]}))
        chars=("${rest[@]}" "${chars[@]:ichar}") ichar=0
      else
        local ret
        ble/decode/process-char/.convert-c0 "$char"
        ble/decode/send-unmodified-key "$ret" "_$char"
      fi
    elif [[ $ent == *_ ]]; then
      # /\d*_/ (_ は続き (1つ以上の有効なシーケンス) がある事を示す)
      _ble_decode_char2_seq=${_ble_decode_char2_seq}_$char
      if [[ ${ent%_} ]]; then
        _ble_decode_char2_reach_key=${ent%_}
        _ble_decode_char2_reach_seq=$_ble_decode_char2_seq
      elif [[ ! $_ble_decode_char2_reach_key ]]; then
        # 1文字目
        local ret
        ble/decode/process-char/.convert-c0 "$char"
        _ble_decode_char2_reach_key=$ret
        _ble_decode_char2_reach_seq=$_ble_decode_char2_seq
      fi
    else
      # /\d+/  (続きのシーケンスはなく ent で確定である事を示す)
      local seq=${_ble_decode_char2_seq}_$char
      _ble_decode_char2_seq=
      _ble_decode_char2_reach_key=
      _ble_decode_char2_reach_seq=
      ble-decode-char/csi/clear
      ble/decode/send-unmodified-key "$ent" "$seq"
    fi
  done
  return 0
}

## @fn ble-decode-char/hook/next-char
##   _ble_decode_char__hook で次の文字を
##   その場で読み出す時に使います。
##   これは bracketed paste の高速化の為に使います。
##   @var[out] char
##   @var[in,out] iloop ichar chars ble_decode_char_rest
##
##   @remarks
##     この関数を経由して読み取られた文字は keylog に残りません。
##     正しい動作を期待する為には _ble_debug_keylog_enabled (非零)
##     及び _ble_decode_keylog_chars_enabled (非空) が設定されて
##     いない事を確認してから呼び出す必要があります。
##
function ble/decode/char-hook/next-char {
  ((ble_decode_char_rest)) || return 1
  ((char=chars[ichar]&~_ble_decode_Macr))
  ((char&_ble_decode_Erro)) && return 1
  ((iloop%1000==0)) && return 1
  ((char==_ble_decode_IsolatedESC)) && char=27
  ((ble_decode_char_rest--,ichar++,iloop++))
  return 0
}

## @fn ble-decode-char/.getent
##   @var[in] _ble_decode_char2_seq
##   @var[in] char
##   @var[out] ent
function ble-decode-char/.getent {
  builtin eval "ent=\${_ble_decode_cmap_$_ble_decode_char2_seq[char]-}"
  if [[ $ent == ?*_ || $ent == _ && $_ble_decode_char2_seq == _27 ]]; then
    ble/decode/wait-input 5 char || ent=${ent%_}
  fi

  # CSI sequence
  #   ent=     の時 → (CSI の結果)
  #   ent=_    の時 → (CSI の結果) + _
  #   ent=num  の時 → num のまま (CSI の結果に拘わらず確定)
  #   ent=num_ の時 → num_ のまま
  local csistat=
  ble-decode-char/csi/consume "$char"
  if [[ $csistat && ! ${ent%_} ]]; then
    if ((csistat==_ble_decode_KCODE_ERROR)); then
      if [[ $bleopt_decode_error_cseq_vbell ]]; then
        local ret
        ble/string#split ret "${_ble_decode_char2_seq//_/ } $char"
        ble-decode-unkbd "${ret[@]}"
        ble/term/visible-bell "unrecognized CSI sequence: $ret"
      fi
      [[ $bleopt_decode_error_cseq_abell ]] && ble/term/audible-bell
      if [[ $bleopt_decode_error_cseq_discard ]]; then
        csistat=$_ble_decode_KCODE_IGNORE
      else
        csistat=
      fi
    fi
    if [[ ! $ent ]]; then
      ent=$csistat
    else
      ent=${csistat%_}_
    fi
  fi

  # ble/util/assert '[[ $ent =~ ^[0-9]*_?$ ]]'
}

## @fn ble/decode/process-char/.convert-c0 char
##   C0制御文字および [DEL] を [C-文字] に変換します。char = 0..31,127 はそれぞ
##   れ C-@ C-a ... C-z C-[ C-\ C-] C-^ C-_ C-? に変換されます。
##   @param[in] char
##   @var[out] ret
function ble/decode/process-char/.convert-c0 {
  ret=$1
  if ((0<=ret&&ret<32)); then
    ((ret|=(ret==0||ret>26?64:96)|_ble_decode_Ctrl))
  elif ((ret==127)); then # C-?
    ((ret=63|_ble_decode_Ctrl))
  fi
}

## @fn ble/decode/send-unmodified-key/.add-modifier mod
##   @param[in] mod
##     The modifier flag
##   @arr[in] seq
##     The character sequence that generated this modifier.
function ble/decode/send-unmodified-key/.add-modifier {
  local mflag1=$1 mflag=$_ble_decode_char2_modifier
  if ((mflag1&mflag)); then
    # 既に同じ修飾がある場合は通常と同じ処理をする。
    # 例えば ESC ESC は3番目に来る文字に Meta 修飾をするのではなく、
    # 2番目の ESC (C-[ に翻訳される) に対して
    # 更に Meta 修飾をして C-M-[ を出力する。
    return 1
  else
    # ※以下では key 内に既に mflag
    # と重複する修飾がある場合は考慮していない。
    # 重複があったという情報はここで消える。
    ((_ble_decode_char2_modkcode=key|mflag,
      _ble_decode_char2_modifier=mflag1|mflag))
    ble/array#push _ble_decode_char2_modseq "${seq[@]}"
    return 0
  fi
}

## @fn ble/decode/send-unmodified-key key seq
##   指定されたキーを修飾して ble-decode-key に渡します。
##   ESC は次に来る文字を meta 修飾します。
##   _ble_decode_IsolatedESC は meta にならずに ESC として渡されます。
##   @param[in] key
##     処理対象のキーコードを指定します。
##   @param[in] seq
##     指定したキーを表現する文字シーケンスを指定します。
##     /(_文字コード)+/ の形式の文字コードの列です。
function ble/decode/send-unmodified-key {
  local key=$1
  ((key==_ble_decode_KCODE_IGNORE)) && return 0

  local seq
  ble/string#split-words seq "${2//_/ }"
  # Note: @ESC は現在の実装では seq の先頭にしか来ない筈。
  ((seq[0]==_ble_decode_IsolatedESC)) && seq[0]=27

  # Processing of prefix ESC characters.
  if [[ $2 == _27 ]]; then
    # We configure readline so that char 27 means a prefix ESC character (which
    # is sent immediately before the subsequent characters).  We attempt to
    # interpret it as the meta modifier regardless of custom conversions to
    # key.  The key is used as is when the meta modifier is already set.
    ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Meta" && return 0
  fi

  # Processing of independent ESC keys.  We first convert @ESC to C-[ or ESC.
  # Then, we attempt independent ESC keys as the meta modifier.
  if
    if ((key==_ble_decode_IsolatedESC)); then
      if [[ $2 == "_$_ble_decode_IsolatedESC" ]]; then
        # When it is generated by a single character @ESC, it means the timeout
        # ESC received by readline.  In this case, we translate it to key C-[.
        key=$((_ble_decode_Ctrl|91))
      else
        # Otherwise, it is generated by a CSI sequence or a custom conversion by
        # "ble-bind -k".  In this case, we trnslate it to 27.
        key=27
      fi
    else
      # A key ESC explicitly specified by the user can also operate as the meta
      # modifier when "bleopt decode_isolated_esc" is enabled.
      ((key==27))
    fi
  then
    if ! ble/decode/uses-isolated-esc; then
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Meta" && return 0
    fi
  fi

  if ((_ble_decode_KCODE_SHIFT<=key&&key<=_ble_decode_KCODE_HYPER)); then
    case $1 in
    ($_ble_decode_KCODE_SHIFT)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Shft" && return 0 ;;
    ($_ble_decode_KCODE_CONTROL)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Ctrl" && return 0 ;;
    ($_ble_decode_KCODE_ALTER)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Altr" && return 0 ;;
    ($_ble_decode_KCODE_META)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Meta" && return 0 ;;
    ($_ble_decode_KCODE_SUPER)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Supr" && return 0 ;;
    ($_ble_decode_KCODE_HYPER)
      ble/decode/send-unmodified-key/.add-modifier "$_ble_decode_Hypr" && return 0 ;;
    esac
  fi

  if [[ $_ble_decode_char2_modifier ]]; then
    local mflag mcode mseq
    mflag=$_ble_decode_char2_modifier
    mcode=$_ble_decode_char2_modkcode
    mseq=("${_ble_decode_char2_modseq[@]}")
    _ble_decode_char2_modifier=
    _ble_decode_char2_modkcode=
    _ble_decode_char2_modseq=()
    if ((key&mflag)); then
      local _ble_decode_key__chars
      _ble_decode_key__chars=("${mseq[@]}")
      ble-decode-key "$mcode"
    else
      seq=("${mseq[@]}" "${seq[@]}")
      ((key|=mflag))
    fi
  fi

  local _ble_decode_key__chars
  _ble_decode_key__chars=("${seq[@]}")
  ble-decode-key "$key"
}

function ble-decode-char/is-intermediate { [[ $_ble_decode_char2_seq ]]; }

function ble-decode-char/bind {
  local -a seq; ble/string#split-words seq "$1"
  local kc=$2

  local i iN=${#seq[@]} char tseq=
  for ((i=0;i<iN;i++)); do
    local char=${seq[i]}

    builtin eval "local okc=\${_ble_decode_cmap_$tseq[char]-}"
    if ((i+1==iN)); then
      if [[ ${okc//[0-9]} == _ ]]; then
        builtin eval "_ble_decode_cmap_$tseq[char]=\${kc}_"
      else
        builtin eval "_ble_decode_cmap_$tseq[char]=\${kc}"
      fi
    else
      if [[ ! $okc ]]; then
        builtin eval "_ble_decode_cmap_$tseq[char]=_"
      else
        builtin eval "_ble_decode_cmap_$tseq[char]=\${okc%_}_"
      fi
      tseq=${tseq}_$char
    fi
  done
}
function ble-decode-char/unbind {
  local -a seq; ble/string#split-words seq "$1"

  local tseq=
  local i iN=${#seq}
  for ((i=0;i<iN-1;i++)); do
    tseq=${tseq}_${seq[i]}
  done

  local char=${seq[iN-1]}
  local isfirst=1 ent=
  while
    builtin eval "ent=\${_ble_decode_cmap_$tseq[char]-}"

    if [[ $isfirst ]]; then
      # 数字を消す
      isfirst=
      if [[ $ent == *_ ]]; then
        # ent = 1234_ (両方在る時は片方消して終わり)
        builtin eval "_ble_decode_cmap_$tseq[char]=_"
        break
      fi
    else
      # _ を消す
      if [[ $ent != _ ]]; then
        # ent = 1234_ (両方在る時は片方消して終わり)
        builtin eval "_ble_decode_cmap_$tseq[char]=${ent%_}"
        break
      fi
    fi

    builtin unset -v "_ble_decode_cmap_$tseq[char]"
    builtin eval "((\${#_ble_decode_cmap_$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    char=${tseq##*_}
    tseq=${tseq%_*}
  done
}
## @fn ble-decode-char/print [tseq nseq...]
##   @var[in] ble_bind_print sgr0 sgrf sgrq sgrc sgro
function ble-decode-char/print {
  [[ $ble_bind_print ]] || local sgr0= sgrf= sgrq= sgrc= sgro=
  local IFS=$_ble_term_IFS q=\' Q="'\''"
  local tseq=$1 nseq ccode
  nseq=("${@:2}")
  builtin eval "local -a ccodes; ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret; ble-decode-unkbd "$ccode"
    local cnames
    cnames=("${nseq[@]}" "$ret")

    builtin eval "local ent=\${_ble_decode_cmap_$tseq[ccode]}"
    if [[ ${ent%_} ]]; then
      local key=${ent%_} ret

      local qkspec qcnames
      if [[ $sgrq ]]; then
        ble-decode-unkbd "$key"
        ble/string#quote-word "$ret" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qkspec=$ret
        ble/string#quote-word "${cnames[*]}" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qcnames=$ret
      else
        ble-decode-unkbd "$key"
        qkspec="'${ret//$q/$Q}'"
        qcnames="'${cnames[*]//$q/$Q}'" # WA #D1570 checked
      fi
      ble/util/print "${sgrf}ble-bind$sgr0 $sgro-k$sgr0 $qcnames $qkspec"
    fi

    if [[ ${ent//[0-9]} == _ ]]; then
      ble-decode-char/print "${tseq}_$ccode" "${cnames[@]}"
    fi
  done
}

# **** ble-decode-key ****

## @arr _ble_decode_${keymap}_kmap_${_ble_decode_key__seq}[key]
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
##     - "_" [TIMEOUT]
##     - "_" [TIMEOUT] ":command"
##     - "1:command"
##
##     始めの文字が "_" の場合はキーシーケンスに続きがある事を表します。
##     つまり、このキーシーケンスを prefix とするより長いキーシーケンスが登録されている事を表します。
##     command が指定されている場合には、より長いシーケンスでの一致に全て失敗した時点で
##     command が実行されます。シーケンスを受け取った段階では実行されません。
##     TIMEOUT (整数値) が指定されている場合は、このキーを受け取った後に続きのキーが TIMEOUT msec
##     以内に到着しなかった時に限りその場で command を実行します。
##
##     初めの文字が "1" の場合はキーシーケンスが確定的である事を表します。
##     つまり、このキーシーケンスを prefix とするより長いシーケンスが登録されてなく、
##     このシーケンスを受け取った段階で command を実行する事が確定する事を表します。
##

## @var _ble_decode_keymap_list := ( ':' kmap )+
##   初期化済みの kmap の名前の一覧を保持します。
##   既定の kmap (名前無し) は含まれません。
_ble_decode_keymap_list=
function ble/decode/keymap#registered {
  [[ :$_ble_decode_keymap_list: == *:"$1":* ]]
}
## @fn ble/decode/keymap#.register kmap
##   @exit 新しく keymap が登録された時に成功します。
##     既存の keymap だった時に失敗します。
##   @remarks
##     この関数は keymap cache から読み出されます。
function ble/decode/keymap#.register {
  local kmap=$1
  if [[ $kmap && :$_ble_decode_keymap_list: != *:"$kmap":* ]]; then
    _ble_decode_keymap_list=$_ble_decode_keymap_list:$kmap
  fi
}
function ble/decode/keymap#.unregister {
  _ble_decode_keymap_list=$_ble_decode_keymap_list:
  _ble_decode_keymap_list=${_ble_decode_keymap_list//:"$1":/:}
  _ble_decode_keymap_list=${_ble_decode_keymap_list%:}
}
function ble/decode/is-keymap {
  ble/decode/keymap#registered "$1" || ble/is-function "ble-decode/keymap:$1/define"
}

function ble/decode/keymap#is-empty {
  ! ble/is-array "_ble_decode_${1}_kmap_" ||
    builtin eval -- "((\${#_ble_decode_${1}_kmap_[*]}==0))"
}

function ble/decode/keymap#.onload {
  local kmap=$1
  local delay=$_ble_base_run/$$.bind.delay.$kmap
  if [[ -s $delay ]]; then
    source "$delay"
    >| "$delay"
  fi
}
function ble/decode/keymap#load {
  local opts=:$2:
  ble/decode/keymap#registered "$1" && return 0

  local init=ble-decode/keymap:$1/define
  ble/is-function "$init" || return 1

  ble/decode/keymap#.register "$1"
  local ble_bind_keymap=$1
  if ! "$init" || ble/decode/keymap#is-empty "$1"; then
    ble/decode/keymap#.unregister "$1"
    return 1
  fi

  [[ $opts == *:dump:* ]] &&
    ble/decode/keymap#dump "$1" >&3
  ble/decode/keymap#.onload "$1"
  return 0
}
## @fn ble/decode/keymap#unload [keymap_name...]
function ble/decode/keymap#unload {
  if (($#==0)); then
    local list; ble/string#split-words list "${_ble_decode_keymap_list//:/ }"
    set -- "${list[@]}"
  fi

  while (($#)); do
    local array_names array_name
    builtin eval -- "array_names=(\"\${!_ble_decode_${1}_kmap_@}\")"
    for array_name in "${array_names[@]}"; do
      builtin unset -v "$array_name"
    done
    ble/decode/keymap#.unregister "$1"
    shift
  done
}

if [[ ${_ble_decode_kmaps-} ]]; then
  ## @fn ble/decode/keymap/cleanup-old-keymaps
  ##   古い形式の keymap を削除する (#D1076)
  ##   0.4.0-devel1+e13e979 以前は unload 時に keymaps を削除していなかった為に、
  ##   reload した時に keycode 不整合で無限ループになってしまうバグがあった。
  function ble/decode/keymap/cleanup-old-keymaps {
    # Note: 古い形式では必ずしも _ble_decode_kmaps に keymap
    #   が登録されていなかったので、配列データから抽出する必要がある。
    local -a list=()
    local var
    for var in "${!_ble_decode_@}"; do
      [[ $var == _ble_decode_*_kmap_ ]] || continue
      var=${var#_ble_decode_}
      var=${var%_kmap_}
      ble/array#push list "$var"
    done

    local keymap_name
    for keymap_name in "${list[@]}"; do
      ble/decode/keymap#unload "$keymap_name"
    done
    builtin unset -v _ble_decode_kmaps
  }
  ble/decode/keymap/cleanup-old-keymaps
fi

function ble/decode/keymap#dump {
  if (($#)); then
    local kmap=$1 arrays
    builtin eval "arrays=(\"\${!_ble_decode_${kmap}_kmap_@}\")"
    ble/util/print "ble/decode/keymap#.register $kmap"
    ble/util/declare-print-definitions "${arrays[@]}"
    ble/util/print "ble/decode/keymap#.onload $kmap"
  else
    local list; ble/string#split-words list "${_ble_decode_keymap_list//:/ }"
    local keymap_name
    for keymap_name in "${list[@]}"; do
      ble/decode/keymap#dump "$keymap_name"
    done
  fi
}

## @fn ble-decode/GET_BASEMAP -v varname
##   既定の基底 keymap を返します。
function ble-decode/GET_BASEMAP {
  [[ $1 == -v ]] || return 1
  local ret; bleopt/get:default_keymap
  [[ $ret == vi ]] && ret=vi_imap
  builtin eval "$2=\$ret"
}
## @fn[custom] ble-decode/INITIALIZE_DEFMAP -v varname
##   既定の keymap を決定します。
##   ble-decode.sh 使用コードで上書きして使用します。
function ble-decode/INITIALIZE_DEFMAP {
  ble-decode/GET_BASEMAP "$@" &&
    ble/decode/keymap#load "${!2}" &&
    return 0

  # fallback
  ble/decode/keymap#load safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

## @fn[custom] ble/widget/.SHELL_COMMAND command
##   ble-bind -c で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND { local IFS=$_ble_term_IFS; builtin eval -- "$*"; }
## @fn[custom] ble/widget/.EDIT_COMMAND command
##   ble-bind -x で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND { local IFS=$_ble_term_IFS; builtin eval -- "$*"; }

## @fn ble-decode-key/bind keymap keys command
##   @param[in] keymap keys command
function ble-decode-key/bind {
  if ! ble/decode/keymap#registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return 0
  fi

  local kmap=$1 keys=$2 cmd=$3

  # Check existence of widget
  if local widget=${cmd%%[$_ble_term_IFS]*}; ! ble/is-function "$widget"; then
    local message="ble-bind: Unknown widget \`${widget#'ble/widget/'}'."
    [[ $cmd == ble/widget/ble/widget/* ]] &&
      message="$message Note: The prefix 'ble/widget/' is redundant."
    ble/util/print "$message" >&2
    return 1
  fi

  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq; ble/string#split-words seq "$keys"

  local i iN=${#seq[@]} tseq=
  for ((i=0;i<iN;i++)); do
    local key=${seq[i]}

    builtin eval "local ocmd=\${$dicthead$tseq[key]}"
    if ((i+1==iN)); then
      if [[ ${ocmd::1} == _ ]]; then
        builtin eval "$dicthead$tseq[key]=${ocmd%%:*}:\$cmd"
      else
        builtin eval "$dicthead$tseq[key]=1:\$cmd"
      fi
    else
      if [[ ! $ocmd ]]; then
        builtin eval "$dicthead$tseq[key]=_"
      elif [[ ${ocmd::1} == 1 ]]; then
        builtin eval "$dicthead$tseq[key]=_:\${ocmd#*:}"
      fi
      tseq=${tseq}_$key
    fi
  done
}

function ble-decode-key/set-timeout {
  if ! ble/decode/keymap#registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return 0
  fi

  local kmap=$1 keys=$2 timeout=$3
  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq; ble/string#split-words seq "$keys"
  [[ $timeout == - ]] && timeout=

  local i iN=${#seq[@]}
  local key=${seq[iN-1]}
  local tseq=
  for ((i=0;i<iN-1;i++)); do
    tseq=${tseq}_${seq[i]}
  done

  builtin eval "local ent=\${$dicthead$tseq[key]}"
  if [[ $ent == _* ]]; then
    local cmd=; [[ $ent == *:* ]] && cmd=${ent#*:}
    builtin eval "$dicthead$tseq[key]=_$timeout${cmd:+:}\$cmd"
  else
    ble/util/print "ble-bind -T: specified partial keyspec not found." >&2
    return 1
  fi
}

## @fn ble-decode-key/unbind keymap keys
function ble-decode-key/unbind {
  if ! ble/decode/keymap#registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return 0
  fi

  local kmap=$1 keys=$2
  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq; ble/string#split-words seq "$keys"

  local i iN=${#seq[@]}
  local key=${seq[iN-1]}
  local tseq=
  for ((i=0;i<iN-1;i++)); do
    tseq=${tseq}_${seq[i]}
  done

  local isfirst=1 ent=
  while
    builtin eval "ent=\${$dicthead$tseq[key]}"

    if [[ $isfirst ]]; then
      # command を消す
      isfirst=
      if [[ ${ent::1} == _ ]]; then
        # ent = _[TIMEOUT] または _[TIMEOUT]:command の時は、単に command を消して終わる。
        # (未だ bind が残っているので、登録は削除せず break)。
        builtin eval "$dicthead$tseq[key]=\${ent%%:*}"
        break
      fi
    else
      # prefix の ent は _ か _:command のどちらかの筈。
      if [[ $ent == *:* ]]; then
        # _:command の場合には 1:command に書き換える。
        # (1:command の bind が残っているので登録は削除せず break)。
        builtin eval "$dicthead$tseq[key]=1:\${ent#*:}"
        break
      fi
    fi

    builtin unset -v "$dicthead$tseq[key]"
    builtin eval "((\${#$dicthead$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    key=${tseq##*_}
    tseq=${tseq%_*}
  done
}

function ble/decode/keymap#get-cursor {
  cursor=_ble_decode_${1}_kmap_cursor
  cursor=${!cursor-}
}
function ble/decode/keymap#set-cursor {
  local keymap=$1 cursor=$2
  if ! ble/decode/keymap#registered "$keymap"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$keymap"
    return 0
  fi
  builtin eval "_ble_decode_${keymap}_kmap_cursor=\$cursor"
  if [[ $keymap == "$_ble_decode_keymap" && $cursor ]]; then
    ble/term/cursor-state/set-internal "$((cursor))"
  fi
}

## @fn ble/decode/keymap#print keymap [tseq nseq]
##   @param keymap
##   @param[in,internal] tseq nseq
##   @var[in] ble_bind_print sgr0 sgrf sgrq sgrc sgro
function ble/decode/keymap#print {
  # 引数の無い場合: 全ての kmap を dump
  local kmap
  if (($#==0)); then
    for kmap in ${_ble_decode_keymap_list//:/ }; do
      ble/util/print "$sgrc# keymap $kmap$sgr0"
      ble/decode/keymap#print "$kmap"
    done
    return 0
  fi

  [[ $ble_bind_print ]] || local sgr0= sgrf= sgrq= sgrc= sgro=
  local kmap=$1 tseq=$2 nseq=$3
  local dicthead=_ble_decode_${kmap}_kmap_
  local kmapopt=
  [[ $kmap ]] && kmapopt=" $sgro-m$sgr0 $sgrq'$kmap'$sgr0"

  local q=\' Q="'\''"
  local key keys
  builtin eval "keys=(\${!$dicthead$tseq[@]})"
  for key in "${keys[@]}"; do
    local ret; ble-decode-unkbd "$key"
    local knames=$nseq${nseq:+ }$ret
    builtin eval "local ent=\${$dicthead$tseq[key]}"

    local qknames
    if [[ $sgrq ]]; then
      ble/string#quote-word "$knames" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qknames=$ret
    else
      qknames="'${knames//$q/$Q}'"
    fi
    if [[ $ent == *:* ]]; then
      local cmd=${ent#*:}

      local o v
      case $cmd in
      ('ble/widget/.SHELL_COMMAND '*) o=c v=${cmd#'ble/widget/.SHELL_COMMAND '}; builtin eval "v=$v" ;;
      ('ble/widget/.EDIT_COMMAND '*)  o=x v=${cmd#'ble/widget/.EDIT_COMMAND '} ; builtin eval "v=$v" ;;
      ('ble/widget/.MACRO '*)         o=s; ble/util/chars2keyseq ${cmd#*' '}; v=$ret ;;
      ('ble/widget/'*)                o=f v=${cmd#ble/widget/} ;;
      (*)                             o=@ v=$cmd  ;;
      esac

      local qv
      if [[ $sgrq ]]; then
        ble/string#quote-word "$v" quote-empty:sgrq="$sgrq":sgr0="$sgr0"; qv=$ret
      else
        qv="'${v//$q/$Q}'"
      fi
      ble/util/print "${sgrf}ble-bind$sgr0$kmapopt $sgro-$o$sgr0 $qknames $qv"
    fi

    if [[ ${ent::1} == _ ]]; then
      ble/decode/keymap#print "$kmap" "${tseq}_$key" "$knames"
      if [[ $ent == _[0-9]* ]]; then
        local timeout=${ent%%:*}; timeout=${timeout:1}
        ble/util/print "${sgrf}ble-bind$sgr0$kmapopt $sgro-T$sgr0 $qknames $timeout"
      fi
    fi
  done
}

## @var _ble_decode_keymap
##
##   現在選択されている keymap
##
## @arr _ble_decode_keymap_stack
##
##   呼び出し元の keymap を記録するスタック
##
_ble_decode_keymap=
_ble_decode_keymap_stack=()

## @fn ble/decode/keymap/push kmap
function ble/decode/keymap/push {
  if ble/decode/keymap#registered "$1"; then
    ble/array#push _ble_decode_keymap_stack "$_ble_decode_keymap"
    _ble_decode_keymap=$1

    # set cursor-state
    local cursor; ble/decode/keymap#get-cursor "$1"
    [[ $cursor ]] && ble/term/cursor-state/set-internal "$((cursor))"
    return 0
  elif ble/decode/keymap#load "$1" && ble/decode/keymap#registered "$1"; then
    ble/decode/keymap/push "$1" # 再実行
  else
    ble/util/print "[ble: keymap '$1' not found]" >&2
    return 1
  fi
}
## @fn ble/decode/keymap/pop
function ble/decode/keymap/pop {
  local count=${#_ble_decode_keymap_stack[@]}
  local last=$((count-1))
  ble/util/assert '((last>=0))' || return 1

  # reset cursor-state
  local cursor
  ble/decode/keymap#get-cursor "$_ble_decode_keymap"
  if [[ $cursor ]]; then
    local i
    for ((i=last;i>=0;i--)); do
      ble/decode/keymap#get-cursor "${_ble_decode_keymap_stack[i]}"
      [[ $cursor ]] && break
    done
    ble/term/cursor-state/set-internal "$((${cursor:-0}))"
  fi

  local old_keymap=_ble_decode_keymap
  _ble_decode_keymap=${_ble_decode_keymap_stack[last]}
  builtin unset -v '_ble_decode_keymap_stack[last]'
}
## @fn ble/decode/keymap/get-parent
##   @var[out] ret
function ble/decode/keymap/get-parent {
  local len=${#_ble_decode_keymap_stack[@]}
  if ((len)); then
    ret=${_ble_decode_keymap_stack[len-1]}
  else
    ret=
  fi
}
## @fn ble/decode/keymap/get-major-keymap
##   @var[out] keymap
function ble/decode/keymap/get-major-keymap {
  keymap=$_ble_decode_keymap
  local index=${#_ble_decode_keymap_stack[@]}
  while :; do
    case $keymap in (vi_?map|emacs) return 0 ;; esac
    ((--index<0)) && break
    keymap=${_ble_decode_keymap_stack[index]}
  done
  return 1
}

## @arr _ble_decode_key__chars
##   ble-decode-key から参照される配列です。引数に指定したキーを生成した文字シー
##   ケンスを保持します。
_ble_decode_key__chars=()

## @var _ble_decode_key__seq
##   今迄に入力された未処理のキーの列を保持します
##   /(_\d+)*/ の形式の文字列です。
_ble_decode_key__seq=

## @var _ble_decode_key__hook
##   キー処理に対する hook を外部から設定する為の変数です。
_ble_decode_key__hook=

## @fn ble-decode-key/is-intermediate
##   未処理のキーがあるかどうかを判定します。
function ble-decode-key/is-intermediate { [[ $_ble_decode_key__seq ]]; }

## @arr _ble_decode_key_batch
_ble_decode_key_batch=()

## @fn ble-decode-key/batch/flush
function ble-decode-key/batch/flush {
  ((${#_ble_decode_key_batch[@]})) || return 1
  local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_
  builtin eval "local command=\${${dicthead}[_ble_decode_KCODE_BATCH_CHAR]-}"
  command=${command:2}
  if [[ $command ]]; then
    local chars; chars=("${_ble_decode_key_batch[@]}")
    _ble_decode_key_batch=()
    ble/decode/widget/call-interactively "$command" "${chars[@]}"; local ext=$?
    ((ext!=125)) && return 0
  fi

  ble/decode/widget/call-interactively ble/widget/__batch_char__.default "${chars[@]}"; local ext=$?
  return "$ext"
}
function ble/widget/__batch_char__.default {
  builtin eval "local widget_defchar=\${${dicthead}[_ble_decode_KCODE_DEFCHAR]-}"
  widget_defchar=${widget_defchar:2}
  builtin eval "local widget_default=\${${dicthead}[_ble_decode_KCODE_DEFAULT]-}"
  widget_default=${widget_default:2}

  local -a unprocessed_chars=()
  local key command
  for key in "${KEYS[@]}"; do
    if [[ $widget_defchar ]]; then
      ble/decode/widget/call-interactively "$widget_defchar" "$key"; local ext=$?
      ((ext!=125)) && continue
    fi
    if [[ $widget_default ]]; then
      ble/decode/widget/call-interactively "$widget_default" "$key"; local ext=$?
      ((ext!=125)) && continue
    fi

    ble/array#push unprocessed_chars "$key"
  done

  if ((${#unprocessed_chars[@]})); then
    local ret; ble-decode-unkbd "${unprocessed_chars[@]}"
    [[ $bleopt_decode_error_kseq_vbell ]] && ble/term/visible-bell "unprocessed chars: $ret"
    [[ $bleopt_decode_error_kseq_abell ]] && ble/term/audible-bell
  fi
  return 0
}


## @fn ble-decode-key key...
##   キー入力の処理を行います。登録されたキーシーケンスに一致した場合、
##   関連付けられたコマンドを実行します。
##   登録されたキーシーケンスの前方部分に一致する場合、即座に処理は行わず
##   入力されたキーの列を _ble_decode_key__seq に記録します。
##
##   @param[in] key
##     入力されたキー
##
function ble-decode-key {
  local CHARS
  CHARS=("${_ble_decode_key__chars[@]}")

  local key
  while (($#)); do
    key=$1; shift
#%if debug_keylogger
    ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_keys "$key"
#%end
    if [[ $_ble_decode_keylog_keys_enabled && $_ble_decode_keylog_depth == 0 ]]; then
      ble/array#push _ble_decode_keylog_keys "$key"
      ((_ble_decode_keylog_keys_count++))
    fi

    # Note: マウス移動はシーケンスの一部と見做さず独立に処理する。
    #   widget が登録されていれば処理しそれ以外は無視。
    local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_
    if (((key&_ble_decode_MaskChar)==_ble_decode_KCODE_MOUSE_MOVE)); then
      builtin eval "local command=\${${dicthead}[key]-}"
      command=${command:2}
      ble-decode/widget/.call-keyseq
      continue
    fi

    if [[ $_ble_decode_key__hook ]]; then
      local hook=$_ble_decode_key__hook
      _ble_decode_key__hook=
      ble-decode/widget/.call-async-read "$hook $key" "$key"
      continue
    fi

    builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[key]-}"

    # TIMEOUT: timeout が設定されている場合はその時間だけ待って
    # 続きを処理するかその場で確定するか判断する。
    if [[ $ent == _[0-9]* ]]; then
      local node_type=_
      if (($#==0)) && ! ble/decode/has-input; then
        local timeout=${ent%%:*}; timeout=${timeout:1}
        ble/decode/wait-input "$timeout" || node_type=1
      fi
      if [[ $ent == *:* ]]; then
        ent=$node_type:${ent#*:}
      else
        ent=$node_type
      fi
    fi

    if [[ $ent == 1:* ]]; then
      # /1:command/    (続きのシーケンスはなく ent で確定である事を示す)
      local command=${ent:2}
      if [[ $command ]]; then
        ble-decode/widget/.call-keyseq
      else
        _ble_decode_key__seq=
      fi
    elif [[ $ent == _ || $ent == _:* ]]; then
      # /_(:command)?/ (続き (1つ以上の有効なシーケンス) がある事を示す)
      _ble_decode_key__seq=${_ble_decode_key__seq}_$key
    else
      # 遡って適用 (部分一致、または、既定動作)
      ble-decode-key/.invoke-partial-match "$key" && continue

      # エラーの表示
      local kseq=${_ble_decode_key__seq}_$key ret
      ble-decode-unkbd "${kseq//_/ }"
      local kspecs=$ret
      [[ $bleopt_decode_error_kseq_vbell ]] && ble/term/visible-bell "unbound keyseq: $kspecs"
      [[ $bleopt_decode_error_kseq_abell ]] && ble/term/audible-bell

      # 残っている文字の処理
      if [[ $_ble_decode_key__seq ]]; then
        if [[ $bleopt_decode_error_kseq_discard ]]; then
          _ble_decode_key__seq=
        else
          local -a keys
          ble/string#split-words keys "${_ble_decode_key__seq//_/ } $key"
          _ble_decode_key__seq=
          # 2文字目以降を処理
          ble-decode-key "${keys[@]:1}"
        fi
      fi
    fi

  done

  if ((${#_ble_decode_key_batch[@]})); then
    if ! ble/decode/has-input || ((${#_ble_decode_key_batch[@]}>=50)); then
      ble-decode-key/batch/flush
    fi
  fi
  return 0
}

## @fn ble-decode-key/.invoke-partial-match fail
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
##     がクリアされ、一致しなかった残りの部分に対して再度 ble-decode-key を呼
##     び出して再解釈が行われます。
##     1, 2 のいずれでも一致が見付からなかった場合には、_ble_decode_key__seq を
##     呼出時の状態に戻し関数は失敗します。つまり、この場合 _ble_decode_key__seq
##     は、呼出元からは変化していない様に見えます。
##
function ble-decode-key/.invoke-partial-match {
  local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_

  local next=$1
  if [[ $_ble_decode_key__seq ]]; then
    local last=${_ble_decode_key__seq##*_}
    _ble_decode_key__seq=${_ble_decode_key__seq%_*}

    builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[last]-}"
    if [[ $ent == _*:* ]]; then
      local command=${ent#*:}
      if [[ $command ]]; then
        ble-decode/widget/.call-keyseq
      else
        _ble_decode_key__seq=
      fi
      ble-decode-key "$next"
      return 0
    else # ent = _
      if ble-decode-key/.invoke-partial-match "$last"; then
        ble-decode-key "$next"
        return 0
      else
        # 元に戻す
        _ble_decode_key__seq=${_ble_decode_key__seq}_$last
        return 1
      fi
    fi
  else
    # ここでは指定した単体のキーに対する既定の処理を実行する
    # $next 単体でも設定がない場合はここに来る。
    # 通常の文字などは全てここに流れてくる事になる。

    # 既定の文字ハンドラ
    local key=$1
    if ble-decode-key/ischar "$key"; then
      if ble/decode/has-input && builtin eval "[[ \${${dicthead}[_ble_decode_KCODE_BATCH_CHAR]-} ]]"; then
        ble/array#push _ble_decode_key_batch "$key"
        return 0
      fi

      builtin eval "local command=\${${dicthead}[_ble_decode_KCODE_DEFCHAR]-}"
      command=${command:2}
      if [[ $command ]]; then
        local seq_save=$_ble_decode_key__seq
        ble-decode/widget/.call-keyseq; local ext=$?
        ((ext!=125)) && return 0
        _ble_decode_key__seq=$seq_save # 125 の時はまた元に戻して次の試行を行う
      fi
    fi

    # 既定のキーハンドラ
    builtin eval "local command=\${${dicthead}[_ble_decode_KCODE_DEFAULT]-}"
    command=${command:2}
    ble-decode/widget/.call-keyseq; local ext=$?
    ((ext!=125)) && return 0

    return 1
  fi
}

function ble-decode-key/ischar {
  local key=$1
  (((key&_ble_decode_MaskFlag)==0&&32<=key&&key<_ble_decode_FunctionKeyBase))
}

#------------------------------------------------------------------------------
# ble-decode/widget

## @var _ble_decode_widget_last
##   次のコマンドで LASTWIDGET として使用するコマンド名を保持します。
##   以下の関数で使用されます。
##
##   - ble-decode/widget/.call-keyseq
##   - ble-decode/widget/.call-async-read
##   - ble/decode/widget/call
##   - ble/decode/widget/call-interactively
##   - (keymap/vi.sh) ble/keymap:vi/repeat/invoke
##
_ble_decode_widget_last=

function ble-decode/widget/.invoke-hook {
  local key=$1
  local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_
  builtin eval "local hook=\${$dicthead[key]-}"
  hook=${hook:2}
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget.hook.0"
#%end.i
  [[ $hook ]] && builtin eval -- "$hook"
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget.hook.1 $hook"
#%end.i
}

## @fn ble-decode/widget/.call-keyseq
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
function ble-decode/widget/.call-keyseq {
  ble-decode-key/batch/flush
  [[ $command ]] || return 125

  # for keylog suppress
  local _ble_decode_keylog_depth=$((_ble_decode_keylog_depth+1))

  # set up variables
  local WIDGET=$command KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; ble/string#split-words KEYS "${_ble_decode_key__seq//_/ } $key"
  _ble_decode_widget_last=$WIDGET
  _ble_decode_key__seq=

  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_BEFORE_WIDGET"
#%if leakvar
ble/debug/leakvar#check $"leakvar" widget.0
#%end.i
  builtin eval -- "$WIDGET"; local ext=$?
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget $WIDGET"
#%end.i
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_AFTER_WIDGET"
  ((_ble_decode_keylog_depth==1)) &&
    _ble_decode_keylog_chars_count=0 _ble_decode_keylog_keys_count=0
  return "$ext"
}
## @fn ble-decode/widget/.call-async-read widget keys
##   _ble_decode_{char,key}__hook の呼び出しに使用します。
##   _ble_decode_widget_last は更新しません。
function ble-decode/widget/.call-async-read {
  # for keylog suppress
  local _ble_decode_keylog_depth=$((_ble_decode_keylog_depth+1))

  # set up variables
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; ble/string#split-words KEYS "$2"
  builtin eval -- "$WIDGET"; local ext=$?
  ((_ble_decode_keylog_depth==1)) &&
    _ble_decode_keylog_chars_count=0 _ble_decode_keylog_keys_count=0
  return "$ext"
}
## @fn ble/decode/widget/call-interactively widget keys...
## @fn ble/decode/widget/call widget keys...
##   指定した名前の widget を呼び出します。
##   call-interactively では、現在の keymap に応じた __before_widget__
##   及び __after_widget__ フックも呼び出します。
function ble/decode/widget/call-interactively {
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; KEYS=("${@:2}")
  _ble_decode_widget_last=$WIDGET
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_BEFORE_WIDGET"
#%if leakvar
ble/debug/leakvar#check $"leakvar" widget.0
#%end.i
  builtin eval -- "$WIDGET"; local ext=$?
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget $WIDGET"
#%end.i
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_AFTER_WIDGET"
  return "$ext"
}
function ble/decode/widget/call {
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; KEYS=("${@:2}")
  _ble_decode_widget_last=$WIDGET
#%if leakvar
ble/debug/leakvar#check $"leakvar" widget.0
#%end.i
  builtin eval -- "$WIDGET"
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget $WIDGET"
#%end.i
}
## @fn ble/decode/widget/dispatch widget args...
function ble/decode/widget/dispatch {
  local ret; ble/string#quote-command ble/widget/"${1#ble/widget/}" "${@:2}"
  local WIDGET=$ret
  _ble_decode_widget_last=$WIDGET
#%if leakvar
ble/debug/leakvar#check $"leakvar" widget.0
#%end.i
  builtin eval -- "$WIDGET"
#%if leakvar
ble/debug/leakvar#check $"leakvar" "widget $WIDGET"
#%end.i
}
## @fn ble/decode/widget/suppress-widget
##   __before_widget__ に登録された関数から呼び出します。
##   __before_widget__ 内で必要な処理を完了した時に、
##   WIDGET の呼び出しをキャンセルします。
##   __after_widget__ の呼び出しはキャンセルされません。
function ble/decode/widget/suppress-widget {
  WIDGET=
}

## @fn ble/decode/widget/redispatch-by-keys
##   @var[out] _ble_decode_keylog_depth
function ble/decode/widget/redispatch-by-keys {
  ble/decode/widget/skip-lastwidget
  if ((_ble_decode_keylog_depth==1)); then
    # Note: 一旦 pop してから _ble_decode_keylog_depth=0
    #   で ble-decode-key を呼び出す事により再記録させる。
    # Note: 更に _ble_decode_keylog_depth=0 にする事で、
    #   _ble_decode_keylog_chars_count の呼び出し元によるクリアを抑制する。
    ble/decode/keylog#pop
    _ble_decode_keylog_depth=0
  fi
  ble-decode-key "$@"
}
## @fn ble/decode/widget/redispatch
##   @var[in] KEYS
##   @var[out] _ble_decode_keylog_depth
function ble/decode/widget/redispatch {
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}

function ble/decode/widget/skip-lastwidget {
  _ble_decode_widget_last=$LASTWIDGET
}

## @fn ble/decode/widget/keymap-dispatch args
##   関数 ble/widget/NAME の中から呼び出します。
##   現在の keymap に固有の同名の関数 "ble/widget/KEYMAP/NAME" が
##   存在する場合にはそれを呼びします。
##   それ以外の場合には "ble/widget/default/NAME" を呼び出します。
function ble/decode/widget/keymap-dispatch {
  local name=${FUNCNAME[1]#ble/widget/}
  local widget=ble/widget/$_ble_decode_keymap/$name
  ble/is-function "$widget" || widget=ble/widget/default/$name
  "$widget" "$@"
}

#------------------------------------------------------------------------------
# ble/decode/has-input

## @fn ble/decode/has-input
##   ユーザからの未処理の入力があるかどうかを判定します。
##
##   @exit
##     ユーザからの未処理の入力がある場合に成功します。
##     それ以外の場合に失敗します。
##
##   Note: Bash 4.0 未満では read -t 0 が使えない為、
##     正しく判定する事ができません。
##
function ble/decode/has-input {
  ((_ble_decode_input_count||ble_decode_char_rest)) ||
    { [[ ! $ble_decode_char_sync ]] && ble/util/is-stdin-ready; } ||
    ble/encoding:"$bleopt_input_encoding"/is-intermediate ||
    ble-decode-char/is-intermediate

  # Note: 文字の途中やキーのエスケープシーケンスの途中の時には、
  #   標準有力に文字がなくても Readline が先読みして溜めているので、
  #   それも考慮に入れて未処理の入力があるかどうかを判定する。
  #
  # Note: キーシーケンスの途中の時には Readline が溜めているという事もないし、
  #   またユーザが続きを入力するのを待っている状態なので idle と思って良い。
  #   従って ble-decode-key/is-intermediate についてはチェックしない。
}

## @fn ble/decode/has-input-char
##   cseq (char -> key) にとって次の文字が来ているかどうか
function ble/decode/has-input-char {
  ((_ble_decode_input_count||ble_decode_char_rest)) ||
    { [[ ! $ble_decode_char_sync ]] && ble/util/is-stdin-ready; } ||
    ble/encoding:"$bleopt_input_encoding"/is-intermediate
}

## @fn ble/decode/wait-input timeout [type]
function ble/decode/wait-input {
  local timeout=$1 type=${2-}
  if [[ $type == char ]]; then
    ble/decode/has-input-char && return 0
  else
    ble/decode/has-input && return 0
  fi

  if [[ ! $ble_decode_char_sync ]]; then
    while ((timeout>0)); do
      local w=$((timeout<20?timeout:20))
      ble/util/msleep "$w"
      ((timeout-=w))
      ble/util/is-stdin-ready '' 0 && return 0
    done
  fi
  return 1
}

function ble/util/idle/IS_IDLE {
  ! ble/decode/has-input
}

# 
#------------------------------------------------------------------------------
# logging

#%if debug_keylogger
_ble_debug_keylog_enabled=0
_ble_debug_keylog_bytes=()
_ble_debug_keylog_chars=()
_ble_debug_keylog_keys=()
function ble/debug/keylog#start {
  _ble_debug_keylog_enabled=1
}
function ble/debug/keylog#end {
  {
    local IFS=$_ble_term_IFS
    ble/util/print '===== bytes ====='
    ble/util/print "${_ble_debug_keylog_bytes[*]}"
    ble/util/print
    ble/util/print '===== chars ====='
    local ret; ble-decode-unkbd "${_ble_debug_keylog_chars[@]}"
    ble/string#split ret ' ' "$ret"
    ble/util/print "${ret[*]}"
    ble/util/print
    ble/util/print '===== keys ====='
    local ret; ble-decode-unkbd "${_ble_debug_keylog_keys[@]}"
    ble/string#split ret ' ' "$ret"
    ble/util/print "${ret[*]}"
    ble/util/print
  } | fold -w 40

  _ble_debug_keylog_enabled=0
  _ble_debug_keylog_bytes=()
  _ble_debug_keylog_chars=()
  _ble_debug_keylog_keys=()
}
#%else
_ble_debug_keylog_enabled=0
#%end

## @var _ble_decode_keylog_depth
##   現在の widget 呼び出しの深さを表します。
##   入れ子の ble-decode-char, ble-decode-key による
##   文字・キーを記録しない様にする為に用います。
## @var _ble_decode_keylog_keys_enabled
##   現在キーの記録が有効かどうかを保持します。
## @arr _ble_decode_keylog_keys
##   記録したキーを保持します。
## @var _ble_decode_keylog_chars_enabled
##   現在文字の記録が有効かどうかを保持します。
## @arr _ble_decode_keylog_chars
##   記録した文字を保持します。
## @var _ble_decode_keylog_chars_count
##   1 widget を呼び出す迄に記録された文字の数です。
_ble_decode_keylog_depth=0
_ble_decode_keylog_keys_enabled=
_ble_decode_keylog_keys_count=0
_ble_decode_keylog_keys=()
_ble_decode_keylog_chars_enabled=
_ble_decode_keylog_chars_count=0
_ble_decode_keylog_chars=()

## @fn ble/decode/keylog#start [tag]
function ble/decode/keylog#start {
  [[ $_ble_decode_keylog_keys_enabled ]] && return 1
  _ble_decode_keylog_keys_enabled=${1:-1}
  _ble_decode_keylog_keys=()
}
## @fn ble/decode/keylog#end
##   @var[out] ret
function ble/decode/keylog#end {
  ret=("${_ble_decode_keylog_keys[@]}")
  _ble_decode_keylog_keys_enabled=
  _ble_decode_keylog_keys=()
}
## @fn ble/decode/keylog#pop
##   現在の WIDGET 呼び出しに対応する KEYS が記録されているとき、これを削除します。
##   @var[in] _ble_decode_keylog_depth
##   @var[in] _ble_decode_keylog_keys_enabled
##   @arr[in] KEYS
function ble/decode/keylog#pop {
  [[ $_ble_decode_keylog_keys_enabled && $_ble_decode_keylog_depth == 1 ]] || return 1
  local new_size=$((${#_ble_decode_keylog_keys[@]}-_ble_decode_keylog_keys_count))
  ((new_size<0)) && new_size=0
  _ble_decode_keylog_keys=("${_ble_decode_keylog_keys[@]::new_size}")
  _ble_decode_keylog_keys_count=0
}

## @fn ble/decode/charlog#start [tag]
function ble/decode/charlog#start {
  [[ $_ble_decode_keylog_chars_enabled ]] && return 1
  _ble_decode_keylog_chars_enabled=${1:-1}
  _ble_decode_keylog_chars=()
}
## @fn ble/decode/charlog#end
##   @var[out] ret
function ble/decode/charlog#end {
  [[ $_ble_decode_keylog_chars_enabled ]] || { ret=(); return 1; }
  ret=("${_ble_decode_keylog_chars[@]}")
  _ble_decode_keylog_chars_enabled=
  _ble_decode_keylog_chars=()
}
## @fn ble/decode/charlog#end-exclusive
##   現在の WIDGET 呼び出しに対応する文字を除いて記録を取得して完了します。
##   @var[out] ret
function ble/decode/charlog#end-exclusive {
  ret=()
  [[ $_ble_decode_keylog_chars_enabled ]] || return 1
  local size=$((${#_ble_decode_keylog_chars[@]}-_ble_decode_keylog_chars_count))
  ((size>0)) && ret=("${_ble_decode_keylog_chars[@]::size}")
  _ble_decode_keylog_chars_enabled=
  _ble_decode_keylog_chars=()
}
## @fn ble/decode/charlog#end-exclusive-depth1
##   トップレベルの WIDGET 呼び出しの時は end-exclusive にします。
##   二次的な WIDGET 呼び出しの時には inclusive に end します。
##
##   @var[out] ret
##     記録を返します。
##
##   これは exit-default -> end-keyboard-macro という具合に
##   WIDGET が呼び出されて記録が完了する場合がある為です。
##   この場合 exit-default は記録に残したいので自身を呼び出した
##   文字の列も記録に含ませる必要があります。
##   但し、マクロ再生中に呼び出される end-keyboard-macro
##   は無視する必要があります。
##
function ble/decode/charlog#end-exclusive-depth1 {
  if ((_ble_decode_keylog_depth==1)); then
    ble/decode/charlog#end-exclusive
  else
    ble/decode/charlog#end
  fi
}

## @fn ble/decode/charlog#encode chars...
function ble/decode/charlog#encode {
  local -a buff=()
  for char; do
    ((char==0)) && char=$_ble_decode_EscapedNUL
    ble/util/c2s "$char"
    ble/array#push buff "$ret"
  done
  IFS= builtin eval 'ret="${buff[*]}"'
}
## @fn ble/decode/charlog#decode text
function ble/decode/charlog#decode {
  local text=$1 n=${#1} i chars
  chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "${text:i:1}"
    ((ret==_ble_decode_EscapedNUL)) && ret=0
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}

## @fn ble/decode/keylog#encode keys...
##   キーの列からそれに対応する文字列を構築します
function ble/decode/keylog#encode {
  ret=
  ble/util/c2s 155; local csi=$ret

  local key
  local -a buff=()
  for key; do
    # 通常の文字
    if ble-decode-key/ischar "$key"; then
      ble/util/c2s "$key"

      # Note: 現在の LC_CTYPE で表現できない Unicode の時、
      #   ret == \u???? もしくは \U???????? の形式になる。
      #   その場合はここで処理せず、後の部分で CSI 27;1;code ~ の形式で記録する。
      if ((${#ret}==1)); then
        ble/array#push buff "$ret"
        continue
      fi
    fi

    local c=$((key&_ble_decode_MaskChar))

    # C-? は制御文字として登録する
    if (((key&_ble_decode_MaskFlag)==_ble_decode_Ctrl&&(c==64||91<=c&&c<=95||97<=c&&c<=122))); then
      # Note: ^@ (NUL) は文字列にできないので除外
      if ((c!=64)); then
        ble/util/c2s "$((c&0x1F))"
        ble/array#push buff "$ret"
        continue
      fi
    fi

    # Note: Meta 修飾は単体の ESC と紛らわしいので CSI 27 で記録する。
    local mod=1
    (((key&_ble_decode_Shft)&&(mod+=0x01),
      (key&_ble_decode_Altr)&&(mod+=0x02),
      (key&_ble_decode_Ctrl)&&(mod+=0x04),
      (key&_ble_decode_Supr)&&(mod+=0x08),
      (key&_ble_decode_Hypr)&&(mod+=0x10),
      (key&_ble_decode_Meta)&&(mod+=0x20)))
    ble/array#push buff "${csi}27;$mod;$c~"
  done
  IFS= builtin eval 'ret="${buff[*]-}"'
}
## @fn ble/decode/keylog#decode-chars text
function ble/decode/keylog#decode-chars {
  local text=$1 n=${#1} i
  local -a chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "${text:i:1}"
    ((ret==27)) && ret=$_ble_decode_IsolatedESC
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}

## @fn ble/widget/.MACRO char...
##   bind '"keyseq":"macro"' の束縛に使用する。
_ble_decode_macro_count=0
function ble/widget/.MACRO {
  # マクロ無限再帰検出
  if ((ble_decode_char_char&_ble_decode_Macr)); then
    if ((_ble_decode_macro_count++>=bleopt_decode_macro_limit)); then
      ((_ble_decode_macro_count==bleopt_decode_macro_limit+1)) &&
        ble/term/visible-bell "Macro invocation is canceled by decode_macro_limit"
      return 1
    fi
  else
    _ble_decode_macro_count=0
  fi

  local -a chars=()
  local char
  for char; do
    ble/array#push chars "$((char|_ble_decode_Macr))"
  done
  ble-decode-char "${chars[@]}"
}

## @fn ble/widget/.CHARS char...
##   lib/init-bind.sh で特別なバイト列を受信するのに使う関数
function ble/widget/.CHARS {
  ble-decode-char "$@"
}

#------------------------------------------------------------------------------
# key definitions (c.f. init-cmap.sh)                              @decode.cmap

## @fn ble/decode/c2dqs code
##   bash builtin bind で用いる事のできるキー表記に変換します。
##   @var[out] ret
function ble/decode/c2dqs {
  local i=$1

  # bind で用いる
  # リテラル "～" 内で特別な表記にする必要がある物
  if ((0<=i&&i<32)); then
    # C0 characters
    if ((1<=i&&i<=26)); then
      ble/util/c2s "$((i+96))"
      ret="\\C-$ret"
    elif ((i==27)); then
      ret="\\e"
    elif ((i==28)); then
      # Workaround \C-\\, \C-\ in Bash-3.0..5.0
      ret="\\x1c"
    else
      ble/decode/c2dqs "$((i+64))"
      ret="\\C-$ret"
    fi
  elif ((32<=i&&i<127)); then
    ble/util/c2s "$i"

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
    # ble/util/c2s だと UTF-8 encode されてしまうので駄目
  fi
}

## @fn binder; ble/decode/cmap/.generate-binder-template
##   3文字以上の bind -x を _ble_decode_cmap から自動的に行うソースを生成
##   binder には bind を行う関数を指定する。
#
# ※この関数は bash-3.1 では使えない。
#   bash-3.1 ではバグで呼出元と同名の配列を定義できないので
#   local -a ccodes が空になってしまう。
#   幸いこの関数は bash-3.1 では使っていないのでこのままにしてある。
#   追記: 公開されている patch を見たら bash-3.1.4 で修正されている様だ。
#
function ble/decode/cmap/.generate-binder-template {
  local tseq=$1 qseq=$2 nseq=$3 depth=${4:-1} ccode
  local apos="'" escapos="'\\''"
  builtin eval "local -a ccodes; ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret
    ble/decode/c2dqs "$ccode"
    local qseq1=$qseq$ret
    local nseq1="$nseq $ccode"

    builtin eval "local ent=\${_ble_decode_cmap_$tseq[ccode]}"
    if [[ ${ent%_} ]]; then
      if ((depth>=3)); then
        ble/util/print "\$binder \"$qseq1\" \"${nseq1# }\""
      fi
    fi

    if [[ ${ent//[0-9]} == _ ]]; then
      ble/decode/cmap/.generate-binder-template "${tseq}_$ccode" "$qseq1" "$nseq1" "$((depth+1))"
    fi
  done
}

function ble/decode/cmap/.emit-bindx {
  local q="'" Q="'\''"
  ble/util/print "builtin bind -x '\"${1//$q/$Q}\":_ble_decode_hook $2; builtin eval -- \"\$_ble_decode_bind_hook\"'"
}
function ble/decode/cmap/.emit-bindr {
  ble/util/print "builtin bind -r \"$1\""
}

_ble_decode_cmap_initialized=
function ble/decode/cmap/initialize {
  [[ $_ble_decode_cmap_initialized ]] && return 0
  _ble_decode_cmap_initialized=1

  local init=$_ble_base/lib/init-cmap.sh
  local dump=$_ble_base_cache/decode.cmap.$_ble_decode_kbd_ver.$TERM.dump
  if [[ -s $dump && $dump -nt $init ]]; then
    source "$dump"
  else
    ble/edit/info/immediate-show text 'ble.sh: generating "'"$dump"'"...'
    source "$init"
    ble-bind -D | ble/bin/awk '
      {
        sub(/^declare +(-[aAilucnrtxfFgGI]+ +)?/, "");
        sub(/^-- +/, "");
      }
      /^_ble_decode_(cmap|csimap|kbd)/ {
        if (!($0 ~ /^_ble_decode_csimap_kitty_u/))
          gsub(/["'\'']/, "");
        print
      }
    ' >| "$dump"
  fi

  if ((_ble_bash>=40300)); then
    # 3文字以上 bind/unbind ソースの生成 (init-bind.sh bindAllSeq で使用)
    local fbinder=$_ble_base_cache/decode.cmap.allseq
    _ble_decode_bind_fbinder=$fbinder
    if ! [[ -s $_ble_decode_bind_fbinder.bind && $_ble_decode_bind_fbinder.bind -nt $init &&
              -s $_ble_decode_bind_fbinder.unbind && $_ble_decode_bind_fbinder.unbind -nt $init ]]; then
      ble/edit/info/immediate-show text  'ble.sh: initializing multi-character sequence binders... '
      ble/decode/cmap/.generate-binder-template >| "$fbinder"
      binder=ble/decode/cmap/.emit-bindx source "$fbinder" >| "$fbinder.bind"
      binder=ble/decode/cmap/.emit-bindr source "$fbinder" >| "$fbinder.unbind"
      ble/edit/info/immediate-show text  'ble.sh: initializing multi-character sequence binders... done'
    fi
  fi
}

function ble/decode/cmap/decode-chars.hook {
  ble/array#push ble_decode_bind_keys "$1"
  _ble_decode_key__hook=ble/decode/cmap/decode-chars.hook
}
## @fn ble/decode/cmap/decode-chars chars...
##   文字コードの列からキーの列へ変換します。
##   @arr[out] keys
function ble/decode/cmap/decode-chars {
  ble/decode/cmap/initialize

  # initialize
  local _ble_decode_csi_mode=0
  local _ble_decode_csi_args=
  local _ble_decode_char2_seq=
  local _ble_decode_char2_reach_key=
  local _ble_decode_char2_reach_seq=
  local _ble_decode_char2_modifier=
  local _ble_decode_char2_modkcode=
  local -a _ble_decode_char2_modseq=()

  # suppress unrelated triggers
  local _ble_decode_char__hook=
#%if debug_keylogger
  local _ble_debug_keylog_enabled=
#%end
  local _ble_decode_keylog_keys_enabled=
  local _ble_decode_keylog_chars_enabled=
  local _ble_decode_show_progress_hook=
  local _ble_decode_erase_progress_hook=

  # suppress errors
  local bleopt_decode_error_cseq_abell=
  local bleopt_decode_error_cseq_vbell=
  local bleopt_decode_error_cseq_discard=

  # set up hook and run
  local -a ble_decode_bind_keys=()
  local _ble_decode_key__hook=ble/decode/cmap/decode-chars.hook
  local ble_decode_char_sync=1 # ユーザ入力があっても中断しない
  ble-decode-char "$@" "$_ble_decode_KCODE_IGNORE"

  keys=("${ble_decode_bind_keys[@]}")
  if [[ $_ble_decode_char2_modkcode ]]; then
    ble/array#push keys "$_ble_decode_char2_modkcode"
  fi
}

#------------------------------------------------------------------------------
# **** binder for bash input ****                                  @decode.bind

_ble_decode_bind_hook=

# **** ^U ^V ^W ^? 対策 ****                                   @decode.bind.uvw

# ref #D0003, #D1092
_ble_decode_bind__uvwflag=
function ble/decode/readline/adjust-uvw {
  [[ $_ble_decode_bind__uvwflag ]] && return 0
  _ble_decode_bind__uvwflag=1

  # 何故か stty 設定直後には bind できない物たち
  # Note: bind 'set bind-tty-special-chars on' の時に以下が必要である (#D1092)
  builtin bind -x $'"\025":_ble_decode_hook 21; builtin eval -- "$_ble_decode_bind_hook"'  # ^U
  builtin bind -x $'"\026":_ble_decode_hook 22; builtin eval -- "$_ble_decode_bind_hook"'  # ^V
  builtin bind -x $'"\027":_ble_decode_hook 23; builtin eval -- "$_ble_decode_bind_hook"'  # ^W
  builtin bind -x $'"\177":_ble_decode_hook 127; builtin eval -- "$_ble_decode_bind_hook"' # ^?
  # Note: 更に terminology は erase を DEL ではなく HT に設定しているので、以下
  # も再設定する必要がある。他の端末でも似た物があるかもしれないので、念の為端
  # 末判定はせずに常に上書きを実行する様にする。
  builtin bind -x $'"\010":_ble_decode_hook 8; builtin eval -- "$_ble_decode_bind_hook"'   # ^H
}

# **** POSIXLY_CORRECT workaround ****

# ble.pp の関数を上書き
#

# Note: bash で set -o vi の時、builtin unset -v POSIXLY_CORRECT や local
#   POSIXLY_CORRECT が設定されると、C-i の既定の動作の切り替えに伴って C-i の束
#   縛が消滅する。ユーザが POSIXLY_CORRECT を触った時や自分で触った時に、改めて
#   束縛し直す必要がある。以下の patch を提出したところ 5.1 以降で修正された。
#
#   https://lists.gnu.org/archive/html/bug-bash/2019-02/msg00035.html
#
if ((_ble_bash>=50100)); then
  function ble/base/workaround-POSIXLY_CORRECT {
    [[ $_ble_decode_bind_state == none ]] && return 0
    builtin bind -x '"\C-i":_ble_decode_hook 9; builtin eval -- "$_ble_decode_bind_hook"'
  }
fi

# **** ble-decode-bind ****                                   @decode.bind.main

## @fn ble/decode/readline/.generate-source-to-unbind-default
##   既存の ESC で始まる binding を削除するコードを生成し標準出力に出力します。
##   更に、既存の binding を復元する為のコードを同時に生成し tmp/$$.bind.save に保存します。
function ble/decode/readline/.generate-source-to-unbind-default {
  # 1 ESC で始まる既存の binding を全て削除
  # 2 bind を全て記録 at $$.bind.save
  {
    if ((_ble_bash>=40300)); then
      ble/util/print '__BINDX__'
      builtin bind -X
    fi
    ble/util/print '__BINDP__'
    builtin bind -sp
  } | ble/decode/readline/.generate-source-to-unbind-default/.process

  # Note: 2>/dev/null は、(1) bind -X のエラーメッセージ、及び、
  # (2) LC_ALL 復元時のエラーメッセージ (外側の値が不正な時) を捨てる為に必要。
} 2>/dev/null
function ble/decode/readline/.generate-source-to-unbind-default/.process {
  # Note: #D1355 LC_ALL 切り替えに伴うエラーメッセージは呼び出し元で /dev/null に繋いでいる。
  local q=\' Q="'\''"
  LC_ALL=C ble/bin/awk -v q="$q" '
    BEGIN {
      IS_XPG4 = AWKTYPE == "xpg4";
      rep_Q         = str2rep(q "\\" q q);
      rep_bslash    = str2rep("\\");
      rep_kseq_1c5c = str2rep("\"\\x1c\\x5c\"");
      rep_kseq_1c   = str2rep("\"\\x1c\"");
      mode = 1;
    }

    # Note: Solaris xpg4 awk processes the escape sequences in the replacement
    #   (the second argument), so we need to escape backslashes in the
    #   replacement in advance.
    function str2rep(str) {
      if (IS_XPG4) sub(/\\/, "\\\\\\\\", str);
      return str;
    }

    function quote(text) {
      gsub(q, rep_Q, text);
      return q text q;
    }

    function unescape_control_modifier(str, _, i, esc, chr) {
      for (i = 0; i < 32; i++) {
        if (i == 0 || i == 31)
          esc = sprintf("\\\\C-%c", i + 64);
        else if (27 <= i && i <= 30)
          esc = sprintf("\\\\C-\\%c", i + 64);
        else
          esc = sprintf("\\\\C-%c", i + 96);

        chr = sprintf("%c", i);
        gsub(esc, chr, str);
      }
      gsub(/\\C-\?/, sprintf("%c", 127), str);
      return str;
    }
    function unescape(str) {
      if (str ~ /\\C-/)
        str = unescape_control_modifier(str);
      gsub(/\\e/, sprintf("%c", 27), str);
      gsub(/\\"/, "\"", str);
      gsub(/\\\\/, rep_bslash, str);
      return str;
    }

    function output_bindr(line0, _seq) {
      if (match(line0, /^"(([^"\\]|\\.)+)"/) > 0) {
        _seq = substr(line0, 2, RLENGTH - 2);

        # Note (bash-3.1): Although `bind -sp` outputs `\M-` instead of `\e`,
        #   we need to specify `\e` instead of `\M-` for `bind -r`.
        gsub(/\\M-/, "\\e", _seq);

        print "builtin bind -r " quote(_seq);
      }
    }

    /^__BINDP__$/ { mode = 1; next; }
    /^__BINDX__$/ { mode = 2; next; }

    mode == 1 && $0 ~ /^"/ {
      # Workaround Bash-5.0 bug (cf #D1078)
      sub(/^"\\C-\\\\\\"/, rep_kseq_1c5c);
      sub(/^"\\C-\\\\?"/, rep_kseq_1c);

      output_bindr($0);

      print "builtin bind " quote($0) > "/dev/stderr";
    }

    mode == 2 && $0 ~ /^"/ {
      output_bindr($0);

      line = $0;

      # Note (4.3 <= bash < 5.1): One a key-binding is registered, the command
      #   string remains in the output of `bind -X` even after the key-binding
      #   is removed by `bind -r` or overwritten by another key-binding.  To
      #   avoid the re-binding of ble.sh key-bindings, we explicitly reject
      #   the key-bindings containing _ble_decode_hook.
      if (line ~ /(^|[^[:alnum:]])(ble-decode\/.hook|_ble_decode_hook)($|[^[:alnum:]])/) next;

      # Note (bash < 5.3): The results obtained from `bind -X` cannot be
      #   directly specified to `bind -x`.  While `bind -x` accepts literal
      #   strings as the shell command except for the surrounding double quotes
      #   "...", `bind -X` prints the command escaped by rl_untranslate_keyseq.
      #   We need to remove the surrounding double quotes and unescape its
      #   content.  The types of escape include \C-a, \C-?, \e, \\, \", etc.
      #   The C escape sequences such as \n\r\f\t\v\b\a are not used.
      # Note (bash >= 5.3): The colonless form of the key-binding specification
      #   is introduced, and `bind -X` now uses this form.  With this form, the
      #   command uses the escaped form by rl_untranslate_keyseq for both `bind
      #   -x` and `bind -X` consistently, so we do not need to adjust the line.
      if (match(line, /^("([^"\\]|\\.)*":) "(([^"\\]|\\.)*)"/) > 0) {
        rlen = RLENGTH;
        match(line, /^"([^"\\]|\\.)*":/);
        rlen1 = RLENGTH;
        rlen2 = rlen - rlen1 - 3;
        sequence = substr(line, 1        , rlen1);
        command  = substr(line, rlen1 + 3, rlen2);

        if (command ~ /\\/)
          command = unescape(command);

        line = sequence command;
      }

      print "builtin bind -x " quote(line) > "/dev/stderr";
    }
  ' 2>| "$_ble_base_run/$$.bind.save"
}

## @var _ble_decode_bind_state
##   none, emacs, vi
_ble_decode_bind_state=none
_ble_decode_bind_bindp=
_ble_decode_bind_encoding=

function ble/decode/readline/bind {
  _ble_decode_bind_encoding=$bleopt_input_encoding
  local file=$_ble_base_cache/decode.bind.$_ble_bash.$_ble_decode_bind_encoding.bind
  [[ -s $file && $file -nt $_ble_base/lib/init-bind.sh ]] || source "$_ble_base/lib/init-bind.sh"

  # * 一時的に 'set convert-meta off' にする。
  #
  #   bash-3.0 - 5.0a 全てにおいて 'set convert-meta on' の時、
  #   128-255 を bind しようとすると 0-127 を bind してしまう。
  #   32 bit 環境で LC_CTYPE=C で起動すると 'set convert-meta on' になる様だ。
  #
  #   一応、以下の関数は ble/term/attach で呼び出しているので、
  #   ble/decode/readline/bind の呼び出しが ble/term/attach より後なら大丈夫の
  #   筈だが、念の為にここでも呼び出しておく事にする。
  #
  ble/term/rl-convert-meta/enter

  source "$file"
  _ble_decode_bind__uvwflag=
  ble/util/assign _ble_decode_bind_bindp 'builtin bind -p' # TERM 変更検出用
}
function ble/decode/readline/unbind {
  ble/function#try ble/encoding:"$bleopt_input_encoding"/clear
  source "$_ble_base_cache/decode.bind.$_ble_bash.$_ble_decode_bind_encoding.unbind"
}
function ble/decode/readline/rebind {
  [[ $_ble_decode_bind_state == none ]] && return 0
  ble/decode/readline/unbind
  ble/decode/readline/bind
}

#------------------------------------------------------------------------------
# ble-bind                                                      @decode.blebind

function ble/decode/bind/.initialize-kmap {
  [[ $kmap ]] && return 0
  ble-decode/GET_BASEMAP -v kmap
  if ! ble/decode/is-keymap "$kmap"; then
    ble/util/print "ble-bind: the default keymap '$kmap' is unknown." >&2
    flags=R$flags
    return 1
  fi
  return 0
}

function ble/decode/bind/option:help {
  ble/util/cat <<EOF
ble-bind --help
ble-bind -k [TYPE:]cspecs [[TYPE:]kspec]
ble-bind --csi PsFt [TYPE:]kspec
ble-bind [-m keymap] -fxc@s [TYPE:]kspecs command
ble-bind [-m keymap] -T [TYPE:]kspecs timeout
ble-bind [-m keymap] --cursor cursor_code
ble-bind [-m keymap]... (-PD|--print|--dump)
ble-bind (-L|--list-widgets)

TYPE:SPEC
  TYPE specifies the format of SPEC. The default is  "kspecs".

  kspecs  ble.sh keyboard spec
  keys    List of key codes
  chars   List of character codes in Unicode
  keyseq  Key sequence in the Readline format
  raw     Raw byte sequence

TIMEOUT
  specifies the timeout duration in milliseconds.

CURSOR_CODE
  specifies the cursor shape by the DECSCUSR code.

EOF
}

## @fn ble/decode/bind/get-optarg label count [has_optarg optarg | optarg]
##   @param[in] has_optarg optarg
##     When the third argument is non-empty, ${4-$3} is used as the first
##     optional argument.
##   @arr[out] optarg
function ble/decode/bind/get-optarg {
  optarg=()
  local label=$1 req=$2
  ((req>=1)) || return 0

  if [[ $3 ]]; then
    ((req--))
    ble/array#push optarg "${4-$3}"
  fi
  ((req>=1)) || return 0

  if ((${#args[@]}-iarg<req)); then
    flags=E$flags
    if ((req==1)); then
      ble/util/print "ble-bind: the option \`$label' requires an argument." >&2
    else
      ble/util/print "ble-bind: the option \`$label' requires $req arguments." >&2
    fi
    return 2
  fi

  ble/array#push optarg "${args[@]:iarg:req}"
  ((iarg+=req))
  return 0
}

function ble/decode/bind/option:csi {
  local ret key=
  if [[ $2 ]]; then
    ble-decode-kbd "$2"
    ble/string#split-words key "$ret"
    if ((${#key[@]}!=1)); then
      ble/util/print "ble-bind --csi: the second argument is not a single key!" >&2
      return 1
    elif ((key&~_ble_decode_MaskChar)); then
      ble/util/print "ble-bind --csi: the second argument should not have modifiers!" >&2
      return 1
    fi
  fi

  local rex
  if rex='^([1-9][0-9]*)~$' && [[ $1 =~ $rex ]]; then
    # --csi '<num>~' kname
    #
    #   以下のシーケンスを有効にする。
    #   - CSI <num> ~         kname
    #   - CSI <num> ; <mod> ~ Mod-kname (modified function key)
    #   - CSI <num> $         S-kname (rxvt)
    #   - CSI <num> ^         C-kname (rxvt)
    #   - CSI <num> @         C-S-kname (rxvt)
    #
    _ble_decode_csimap_tilde[BASH_REMATCH[1]]=$key
    if [[ ! ${_ble_decode_csimap_dict[key]} ]]; then
      _ble_decode_csimap_dict[key]=tilde:${BASH_REMATCH[1]}
    fi

    # "CSI <num> $" は CSI sequence の形式に沿っていないので、
    # 個別に登録する必要がある。
    local -a cseq
    cseq=(27 91)
    local ret i iN num="${BASH_REMATCH[1]}\$"
    for ((i=0,iN=${#num};i<iN;i++)); do
      ble/util/s2c "${num:i:1}"
      ble/array#push cseq "$ret"
    done

    local IFS=$_ble_term_IFS
    if [[ $key ]]; then
      ble-decode-char/bind "${cseq[*]}" "$((key|_ble_decode_Shft))"
    else
      ble-decode-char/unbind "${cseq[*]}"
    fi
  elif [[ $1 == [a-zA-Z] ]]; then
    # --csi '<Ft>' kname
    local ret; ble/util/s2c "$1"
    _ble_decode_csimap_alpha[ret]=$key
    if [[ ! ${_ble_decode_csimap_dict[key]} ]]; then
      _ble_decode_csimap_dict[key]=alpha:$ret
    fi
  else
    ble/util/print "ble-bind --csi: not supported type of csi sequences: CSI \`$1'." >&2
    return 1
  fi
}

function ble/decode/bind/option:list-widgets {
  declare -f | ble/bin/sed -n 's/^ble\/widget\/\([a-zA-Z][^.[:blank:]();&|]\{1,\}\)[[:blank:]]*()[[:blank:]]*$/\1/p'
}
function ble/decode/bind/option:dump {
  if (($#)); then
    local keymap
    for keymap; do
      ble/decode/keymap#dump "$keymap"
    done
  else
    ble/util/declare-print-definitions "${!_ble_decode_kbd__@}" "${!_ble_decode_cmap_@}" "${!_ble_decode_csimap_@}"
    ble/decode/keymap#dump
  fi
}
## @fn ble/decode/bind/option:print
##   @var[in] flags
function ble/decode/bind/option:print {
  local ble_bind_print=1
  local sgr0= sgrf= sgrq= sgrc= sgro=
  if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
    local ret
    ble/color/face2sgr command_function; sgrf=$ret
    ble/color/face2sgr syntax_quoted; sgrq=$ret
    ble/color/face2sgr syntax_comment; sgrc=$ret
    ble/color/face2sgr argument_option; sgro=$ret
    sgr0=$_ble_term_sgr0
  fi

  local keymap
  ble-decode/INITIALIZE_DEFMAP -v keymap # 初期化を強制する
  if (($#)); then
    for keymap; do
      ble/decode/keymap#print "$keymap"
    done
  else
    ble-decode-char/csi/print
    ble-decode-char/print
    ble/decode/keymap#print
  fi
}

function ble-bind {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/decode/bind "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}
function ble/decode/bind {
  # Note (#D2092): Reasoning for the check [[ $_ble_bash_options_adjusted ]]:
  # We expect ble-bind is normally called from .blerc, but ble-bind can also be
  # interactively called in user commands.  In such a case, we need to adjust
  # the shell options because they might break the implementation of ble-bind
  # and related functions.  However, the adjustment has a considerable overhead
  # of about 0.2-0.3ms for each call, and ble-bind can internally be called
  # hundreds or thousands times (particularly for the initial cache creation).
  # We try to reduce the overhead by running the adjustment only when the
  # current context is outside the ble.sh context.  We neglect the cases where
  # the user temporarily change shell options inside the ble.sh context and
  # call ble-bind.
  local set shopt
  [[ $_ble_bash_options_adjusted ]] || ble/base/.adjust-bash-options set shopt

  local IFS=$_ble_term_IFS q=\' Q="''\'"

  # @var flags
  #   D ... something done
  #   E ... parse error
  #   R ... runtime error
  #   c ... color=always
  #   n ... color=none
  local flags= kmap=${ble_bind_keymap-} ret
  local -a keymaps; keymaps=()
  ble/decode/initialize

  local -a args
  args=("$@")
  local iarg=0 arg c optarg
  while ((iarg<$#)); do
    local arg=${args[iarg++]}
    if [[ $arg == --?* ]]; then
      local name=${arg:2} has_optarg= optarg=
      if [[ $name == *=* ]]; then
        has_optarg=set
        optarg=${name#*=}
        name=${name%%=*}
      fi

      case $name in
      (color)
        if [[ ! $has_optarg || $optarg == always ]]; then
          flags=c${flags//[cn]}
        elif [[ $optarg == never ]]; then
          flags=n${flags//[cn]}
        elif [[ $optarg == auto ]]; then
          flags=${flags//[cn]}
        else
          flags=E$flags
          ble/util/print "ble-bind: unrecognized color '--color=$optarg'." >&2
        fi ;;
      (help)
        ble/decode/bind/option:help
        flags=D$flags ;;
      (csi)
        flags=D$flags
        ble/decode/bind/get-optarg --csi 2 "$has_optarg" "$optarg" || break
        ble/decode/bind/option:csi "${optarg[0]}" "${optarg[1]}" ;;
      (cursor)
        flags=D$flags
        ble/decode/bind/get-optarg --cursor 1 "$has_optarg" "$optarg" || break
        ble/decode/bind/.initialize-kmap &&
          ble/decode/keymap#set-cursor "$kmap" "${optarg[0]}" ;;
      (list-widgets|list-functions)
        flags=D$flags
        ble/decode/bind/option:list-widgets ;;
      (dump)
        flags=D$flags
        ble/decode/bind/option:dump "${keymaps[@]}" ;;
      (print)
        flags=D$flags
        ble/decode/bind/option:print "${keymaps[@]}" ;;
      (*)
        flags=E$flags
        ble/util/print "ble-bind: unrecognized long option $arg" >&2 ;;
      esac
    elif [[ $arg == -?* ]]; then
      arg=${arg:1}
      while ((${#arg})); do
        c=${arg::1} arg=${arg:1}
        case $c in
        (k)
          flags=D$flags
          ble/decode/bind/get-optarg -k 2 "$arg" || break 2
          arg=

          ble-decode-kbd "${optarg[0]}"; local cseq=$ret
          if [[ ${optarg[1]} && ${optarg[1]} != - ]]; then
            ble-decode-kbd "${optarg[1]}"; local kc=$ret
            ble-decode-char/bind "$cseq" "$kc"
          else
            ble-decode-char/unbind "$cseq"
          fi ;;
        (m)
          ble/decode/bind/get-optarg -m 1 "$arg" || break 2
          arg=
          if ! ble/decode/is-keymap "$optarg"; then
            ble/util/print "ble-bind: the keymap '$optarg' is unknown." >&2
            flags=E$flags
            continue
          fi
          kmap=$optarg
          ble/array#push keymaps "$optarg" ;;
        (D)
          flags=D$flags
          ble/decode/bind/option:dump "${keymaps[@]}" ;;
        ([Pd])
          flags=D$flags
          ble/decode/bind/option:print "${keymaps[@]}" ;;
        (['fxc@s'])
          flags=D$flags

          # 旧形式の指定 -xf や -cf に対応する処理
          [[ $c != f && $arg == f* ]] && arg=${arg:1}
          ble/decode/bind/get-optarg "-$c" 2 "$arg" || break 2
          arg=

          ble-decode-kbd "${optarg[0]}"; local kbd=$ret
          if [[ ${optarg[1]} && ${optarg[1]} != - ]]; then
            local command=${optarg[1]}

            # コマンドの種類
            case $c in
            (f) command=ble/widget/$command ;; # ble/widget/ 関数
            (x) command="ble/widget/.EDIT_COMMAND '${command//$q/$Q}'" ;; # 編集用の関数
            (c) command="ble/widget/.SHELL_COMMAND '${command//$q/$Q}'" ;; # コマンド実行
            (s) local ret; ble/util/keyseq2chars "$command"; command="ble/widget/.MACRO ${ret[*]}" ;;
            ('@') ;; # 直接実行
            (*)
              ble/util/print "error: unsupported binding type \`-$c'." >&2
              continue ;;
            esac

            ble/decode/bind/.initialize-kmap &&
              ble-decode-key/bind "$kmap" "$kbd" "$command"
          else
            ble/decode/bind/.initialize-kmap &&
              ble-decode-key/unbind "$kmap" "$kbd"
          fi ;;
        (T)
          flags=D$flags
          ble/decode/bind/get-optarg -T 2 "$arg" || break 2
          arg=
          ble-decode-kbd "${optarg[0]}"; local kbd=$ret
          ble/decode/bind/.initialize-kmap &&
            ble-decode-key/set-timeout "$kmap" "$kbd" "${optarg[1]}" ;;
        (L)
          flags=D$flags
          ble/decode/bind/option:list-widgets ;;
        (*)
          ble/util/print "ble-bind: unrecognized short option \`-$c'." >&2
          flags=E$flags ;;
        esac
      done
    else
      ble/util/print "ble-bind: unrecognized argument \`$arg'." >&2
      flags=E$flags
    fi
  done

  local ext=0
  case $flags in
  (*E*) ext=2 ;;
  (*R*) ext=1 ;;
  (*D*) ;;
  (*)   ble/decode/bind/option:print "${keymaps[@]}" ;;
  esac
  [[ $_ble_bash_options_adjusted ]] || ble/base/.restore-bash-options set shopt
  return "$ext"
}

#------------------------------------------------------------------------------
# ble/decode/read-inputrc                                       @decode.inputrc

function ble/decode/read-inputrc/test {
  local text=$1
  if [[ ! $text ]]; then
    ble/util/print "ble.sh (bind):\$if: test condition is not supplied." >&2
    return 1
  elif local rex=$'[ \t]*([<>]=?|[=!]?=)[ \t]*(.*)$'; [[ $text =~ $rex ]]; then
    local op=${BASH_REMATCH[1]}
    local rhs=${BASH_REMATCH[2]}
    local lhs=${text::${#text}-${#BASH_REMATCH}}
  else
    local lhs=application
    local rhs=$text
  fi

  case $lhs in
  (application)
    local ret; ble/string#tolower "$rhs"
    [[ $ret == bash || $ret == blesh ]]
    return "$?" ;;

  (mode)
    if [[ -o emacs ]]; then
      builtin test emacs "$op" "$rhs"
    elif [[ -o vi ]]; then
      builtin test vi "$op" "$rhs"
    else
      false
    fi
    return "$?" ;;

  (term)
    if [[ $op == '!=' ]]; then
      builtin test "$TERM" "$op" "$rhs" && builtin test "${TERM%%-*}" "$op" "$rhs"
    else
      builtin test "$TERM" "$op" "$rhs" || builtin test "${TERM%%-*}" "$op" "$rhs"
    fi
    return "$?" ;;

  (version)
    local lhs_major lhs_minor
    if ((_ble_bash<40400)); then
      ((lhs_major=2+_ble_bash/10000,
        lhs_minor=_ble_bash/100%100))
    elif ((_ble_bash<50000)); then
      ((lhs_major=7,lhs_minor=0))
    else
      ((lhs_major=3+_ble_bash/10000,
        lhs_minor=_ble_bash/100%100))
    fi

    local rhs_major rhs_minor
    if [[ $rhs == *.* ]]; then
      local version
      ble/string#split version . "$rhs"
      rhs_major=${version[0]}
      rhs_minor=${version[1]}
    else
      ((rhs_major=rhs,rhs_minor=0))
    fi

    local lhs_ver=$((lhs_major*10000+lhs_minor))
    local rhs_ver=$((rhs_major*10000+rhs_minor))
    [[ $op == '=' ]] && op='=='
    let "$lhs_ver$op$rhs_ver"
    return "$?" ;;

  (*)
    if local ret; ble/util/rlvar#read "$lhs"; then
      builtin test "$ret" "$op" "$rhs"
      return "$?"
    else
      ble/util/print "ble.sh (bind):\$if: unknown readline variable '${lhs//$q/$Q}'." >&2
      return 1
    fi ;;
  esac
}

function ble/decode/read-inputrc {
  local file=$1 ref=$2 q=\' Q="''\'"
  if [[ -f $ref && $ref == */* && $file != /* ]]; then
    local relative_file=${ref%/*}/$file
    [[ -f $relative_file ]] && file=$relative_file
  fi
  if [[ ! -f $file ]]; then
    ble/util/print "ble.sh (bind):\$include: the file '${1//$q/$Q}' not found." >&2
    return 1
  fi

  local -a script=()
  local ret line= iline=0
  while ble/bash/read line || [[ $line ]]; do
    ((++iline))
    ble/string#trim "$line"; line=$ret
    [[ ! $line || $line == '#'* ]] && continue

    if [[ $line == '$'* ]]; then
      local directive=${line%%[$IFS]*}
      case $directive in
      ('$if')
        local args=${line#'$if'}
        ble/string#trim "$args"; args=$ret
        ble/array#push script "if ble/decode/read-inputrc/test '${args//$q/$Q}'; then :" ;;
      ('$else')  ble/array#push script 'else :' ;;
      ('$endif') ble/array#push script 'fi' ;;
      ('$include')
        local args=${line#'$include'}
        ble/string#trim "$args"; args=$ret
        ble/array#push script "ble/decode/read-inputrc '${args//$q/$Q}' '${file//$q/$Q}'" ;;
      (*)
        ble/util/print "ble.sh (bind):$file:$iline: unrecognized directive '$directive'." >&2 ;;
      esac
    else
      ble/array#push script "ble/builtin/bind/.process -- '${line//$q/$Q}'"
    fi
  done < "$file"

  IFS=$'\n' builtin eval 'script="${script[*]}"'
  builtin eval -- "$script"
}

#------------------------------------------------------------------------------
# ble/builtin/bind                                                @builtin.bind

_ble_builtin_bind_keymap=
function ble/builtin/bind/set-keymap {
  local opt_keymap= flags=
  ble/builtin/bind/option:m "$1" &&
    _ble_builtin_bind_keymap=$opt_keymap
  return 0
}

## @fn ble/builtin/bind/option:m keymap
##   @var[in,out] opt_keymap flags
function ble/builtin/bind/option:m {
  local name=$1
  local ret; ble/string#tolower "$name"; local keymap=$ret
  case $keymap in
  (emacs|emacs-standard|emacs-meta|emacs-ctlx) ;;
  (vi|vi-command|vi-move|vi-insert) ;;
  (*) keymap= ;;
  esac
  if [[ ! $keymap ]]; then
    ble/util/print "ble.sh (bind): unrecognized keymap name '$name'" >&2
    flags=e$flags
    return 1
  else
    opt_keymap=$keymap
    return 0
  fi
}

## @fn ble/builtin/bind/.unquote-macro-string value
##   @var[in] spec
##   @var[out] ret
function ble/builtin/bind/.unquote-macro-string {
  local value=$1 q=\' Q="'\''"

  local delim=${1::1}
  if [[ $delim != [\"\'] ]]; then
    ret=$value
  fi

  local rex='^'$delim'(([^\'$delim']|\\.)*)'$delim'['$_ble_term_IFS']*'
  if ! [[ $value =~ $rex ]]; then
    ble/util/print "ble.sh (bind): no closing '${delim//$q/$Q}' in spec: '${spec//$q/$Q}'" >&2
    return 1
  elif ((${#BASH_REMATCH}<${#value})); then
    local fragment=${value:${#BASH_REMATCH}}
    ble/util/print "ble.sh (bind): warning: unprocessed fragments '${fragment//$q/$Q}' in spec: '${spec//$q/$Q}'" >&2
  fi
  ret=${BASH_REMATCH[1]}
}

## @fn ble/builtin/bind/.decompose-pair spec [opts]
##   keyseq:command の形式の文字列を keyseq と command に分離します。
##   @var[out] keyseq value
function ble/builtin/bind/.decompose-pair.impl {
  local LC_ALL= LC_CTYPE=C
  local ret; ble/string#ltrim "$1"
  local spec=$ret ifs=$_ble_term_IFS q=\' Q="'\''"
  keyseq= value=

  # bind '' と指定した時は無視する
  [[ ! $spec || $spec == 'set'["$ifs"]* ]] && return 3

  # split keyseq / value
  local rex_keyseq='^(("([^\"]|\\.)*"|[^":'$ifs'])*("([^\"]|\\.)*)?)'
  if [[ :$2: == *:user-command:* ]]; then
    # bind -x 'keyseq: command'
    # bind -x 'keyseq: "command"'
    # bind -x 'keyseq "command"'
    if ! ble/string#match "$spec" "$rex_keyseq[$ifs]*[:$ifs]"; then
      ble/util/print "ble.sh (bind): no colon or space after keyseq: '${spec//$q/$Q}'" >&3
      return 1
    fi

    local rematch=$BASH_REMATCH
    keyseq=${BASH_REMATCH[1]}

    ble/string#ltrim "${spec:${#BASH_REMATCH}}"
    if [[ $rematch == *: ]]; then
      if [[ $ret == [\"\']* ]]; then
        ble/builtin/bind/.unquote-macro-string "$ret" 2>&3 || return 1
      fi
    else
      # In bash-5.3, the colonless form can be used to untranslate the value as
      # if it is a keyseq.
      if [[ $ret == \"* ]]; then
        ble/builtin/bind/.unquote-macro-string "$ret" 2>&3 || return 1
        ble/util/keyseq2chars "$ret"
        ble/util/chars2s "${ret[@]}"
      else
        ble/util/print "ble.sh (bind): the user command needs to be surrounded by \"..\": '${spec//$q/$Q}'" >&3
        return 1
      fi
    fi
    value=command:$ret
  else
    # bind 'keyseq: rlfunc'
    # bind 'keyseq: "macro"'
    ble/string#match "$spec" "$rex_keyseq[$ifs]*(:[$ifs]*)?"
    keyseq=${BASH_REMATCH[1]}
    ble/string#trim "${spec:${#BASH_REMATCH}}"
    if [[ $ret == [\"\']* ]]; then
      ble/builtin/bind/.unquote-macro-string "$ret" 2>&3 || return 1
      # Note: With any unprocessed fragments for string macros, Readline seems
      # to extend the range to the first whitespace, and thus the ending
      # delimiter is included as a part of the macro content, which is strange.
      # This implementation does not extend the range.
      value=macro:$ret
    else
      value=rlfunc:$ret
    fi
  fi

  # check values
  if [[ $keyseq == '$'* ]]; then
    # Parser directives such as $if, $else, $endif, $include
    return 3
  elif [[ ! $keyseq ]]; then
    ble/util/print "ble.sh (bind): empty keyseq in spec: '${spec//$q/$Q}'" >&3
    return 1
  elif ble/string#match "$keyseq" '^"([^\"]|\\.)*$'; then
    ble/util/print "ble.sh (bind): no closing '\"' in keyseq: '${keyseq//$q/$Q}'" >&3
    return 1
  elif ble/string#match "$keyseq" '^"([^\"]|\\.)*"'; then
    local rematch=${BASH_REMATCH[0]}
    if ((${#rematch}<${#keyseq})); then
      local fragment=${keyseq:${#rematch}}
      ble/util/print "ble.sh (bind): warning: unprocessed fragments in keyseq '${fragment//$q/$Q}'" >&3
    fi
    keyseq=$rematch
    return 0
  else
    return 0
  fi
}
function ble/builtin/bind/.decompose-pair {
  ble/builtin/bind/.decompose-pair.impl "$@" 3>&2 2>/dev/null # suppress locale error #D1440
}
## @fn ble/builtin/bind/.parse-keyname keyname
##   @var[out] chars
function ble/builtin/bind/.parse-keyname {
  local ret mflags=
  ble/string#tolower "$1"; local lower=$ret
  if [[ $1 == *-* ]]; then
    ble/string#split ret - "$lower"
    local mod
    for mod in "${ret[@]::${#ret[@]}-1}"; do
      case $mod in
      (*m|*meta) mflags=m$mflags ;;
      (*c|*ctrl|*control) mflags=c$mflags ;;
      esac
    done
  fi

  local name=${lower##*-} ch=
  case $name in
  (rubout|del) ch=$'\177' ;;
  (escape|esc) ch=$'\033' ;;
  (newline|lfd) ch=$'\n' ;;
  (return|ret) ch=$'\r' ;;
  (space|spc) ch=' ' ;;
  (tab) ch=$'\t' ;;
  (*) ble/util/substr "${1##*-}" 0 1; ch=$ret ;;
  esac
  ble/util/s2c "$ch"; local key=$ret

  [[ $mflags == *c* ]] && ((key&=0x1F))
  [[ $mflags == *m* ]] && ((key|=0x80))
  chars=("$key")
}

## @fn ble/builtin/bind/.initialize-kmap keymap
##   @var[in,out] keys
##   @var[out] kmap
function ble/builtin/bind/.initialize-kmap {
  local keymap=$1
  kmap=
  case $keymap in
  (emacs|emacs-standard) kmap=emacs ;;
  (emacs-ctlx) kmap=emacs; keys=(24 "${keys[@]}") ;;
  (emacs-meta) kmap=emacs; keys=(27 "${keys[@]}") ;;
  (vi-insert) kmap=vi_imap ;;
  (vi|vi-command|vi-move) kmap=vi_nmap ;;
  (*) ble-decode/GET_BASEMAP -v kmap ;;
  esac

  if ! ble/decode/is-keymap "$kmap"; then
    ble/util/print "ble/builtin/bind: the keymap '$kmap' is unknown." >&2
    return 1
  fi

  return 0
}
## @fn ble/builtin/bind/.initialize-keys-and-value spec [opts]
##   @var[out] keys value
function ble/builtin/bind/.initialize-keys-and-value {
  local spec=$1 opts=$2
  keys= value=

  local keyseq
  ble/builtin/bind/.decompose-pair "$spec" "$opts" || return "$?"

  local chars
  if [[ $keyseq == \"*\" ]]; then
    local ret; ble/util/keyseq2chars "${keyseq:1:${#keyseq}-2}"
    chars=("${ret[@]}")
    ((${#chars[@]})) || ble/util/print "ble.sh (bind): warning: empty keyseq" >&2
  else
    [[ :$opts: == *:nokeyname:* ]] &&
      ble/util/print "ble.sh (bind): warning: readline \"bind -x\" does not support \"keyname\" spec" >&2
    ble/builtin/bind/.parse-keyname "$keyseq"
  fi
  ble/decode/cmap/decode-chars "${chars[@]}"
}

## @fn ble/builtin/bind/option:x spec
##   @var[in] opt_keymap
function ble/builtin/bind/option:x {
  local q=\' Q="''\'"
  local keys value kmap
  if ! ble/builtin/bind/.initialize-keys-and-value "$1" nokeyname:user-command; then
    ble/util/print "ble.sh (bind): unrecognized user-command spec '${1//$q/$Q}'." >&2
    flags=e$flags
    return 1
  elif ! ble/builtin/bind/.initialize-kmap "$opt_keymap"; then
    ble/util/print "ble.sh (bind): sorry, failed to initialize keymap:'$opt_keymap'." >&2
    flags=e$flags
    return 1
  fi

  value=${value#command:}
  local command="ble/widget/.EDIT_COMMAND '${value//$q/$Q}'"
  ble-decode-key/bind "$kmap" "${keys[*]}" "$command"
}
## @fn ble/builtin/bind/option:r keyseq
##   @var[in] opt_keymap
function ble/builtin/bind/option:r {
  local keyseq=$1

  local ret chars keys
  ble/util/keyseq2chars "$keyseq"; chars=("${ret[@]}")
  ble/decode/cmap/decode-chars "${chars[@]}"

  local kmap
  ble/builtin/bind/.initialize-kmap "$opt_keymap" || return 1
  ble-decode-key/unbind "$kmap" "${keys[*]}"
}

_ble_decode_rlfunc2widget_emacs=()
_ble_decode_rlfunc2widget_vi_imap=()
_ble_decode_rlfunc2widget_vi_nmap=()
function ble/builtin/bind/rlfunc2widget/load-dict {
  local kmap=${1-}
  ble/decode/bind/.initialize-kmap

  local rlfunc_file= rlfunc_dict=
  case $kmap in
  (emacs)   rlfunc_file=$_ble_base/lib/core-decode.emacs-rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_emacs ;;
  (vi_imap) rlfunc_file=$_ble_base/lib/core-decode.vi_imap-rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_vi_imap ;;
  (vi_nmap) rlfunc_file=$_ble_base/lib/core-decode.vi_nmap-rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_vi_nmap ;;
  esac

  [[ $rlfunc_file ]] || return 1

  local script='
    if ((!${#NAME[@]})); then
      ble/util/mapfile NAME < "$rlfunc_file"
      [[ $OSTYPE == msys* ]] && NAME=("${NAME[@]%$_ble_term_nl}")
    fi
    dict=("${NAME[@]}")
  '; builtin eval -- "${script//NAME/$rlfunc_dict}"
}

function ble/builtin/bind/rlfunc2widget {
  local kmap=$1 rlfunc=$2
  local IFS=$_ble_term_IFS

  if ble/builtin/bind/rlfunc2widget/load-dict "$kmap"; then
    local line
    for line in "${dict[@]}"; do
      [[ $line == "$rlfunc "* ]] || continue
      local rl widget; ble/bash/read rl widget <<< "$line"
      if [[ $widget == - ]]; then
        ble/util/print "ble.sh (bind): unsupported readline function '${rlfunc//$q/$Q}' for keymap '$kmap'." >&2
        return 1
      elif [[ $widget == '<IGNORE>' ]]; then
        return 2
      fi
      ret=ble/widget/$widget
      return 0
    done
  fi

  if ble/is-function ble/widget/"${rlfunc%%[$IFS]*}"; then
    ret=ble/widget/$rlfunc
    return 0
  fi

  ble/util/print "ble.sh (bind): unsupported readline function '${rlfunc//$q/$Q}'." >&2
  return 1
}

## @fn ble/builtin/bind/rlfunc2widget/type rlfunc [kmap]
##   @var[out] ret
function ble/builtin/bind/rlfunc2widget/type {
  local rlfunc=$1 dict
  if ble/builtin/bind/rlfunc2widget/load-dict "$2"; then
    local line
    for line in "${dict[@]}"; do
      if [[ $line == "$rlfunc "* ]]; then
        ret=rlfunc
        return 0
      fi
    done
  fi

  if ble/is-function ble/widget/"$rlfunc"; then
    ret=widget
    return 0
  fi

  ret=unknown
  return 1
}

## @fn ble/builtin/bind/option:u function
##   @var[in] opt_keymap
function ble/builtin/bind/option:u {
  local rlfunc=$1

  local kmap
  if ! ble/builtin/bind/.initialize-kmap "$opt_keymap" || ! ble/decode/keymap#load "$kmap"; then
    ble/util/print "ble.sh (bind): sorry, failed to initialize keymap:'$opt_keymap'." >&2
    flags=e$flags
    return 1
  fi
  local ret
  ble/builtin/bind/rlfunc2widget "$kmap" "$rlfunc" || return 0
  local command=$ret

  # recursive search
  local -a unbind_keys_list=()
  ble/builtin/bind/option:u/search-recursive "$kmap"

  # unbind
  local keys
  for keys in "${unbind_keys_list[@]}"; do
    ble-decode-key/unbind "$kmap" "$keys"
  done
}
function ble/builtin/bind/option:u/search-recursive {
  local kmap=$1 tseq=$2
  local dicthead=_ble_decode_${kmap}_kmap_
  local key keys
  builtin eval "keys=(\${!$dicthead$tseq[@]})"
  for key in "${keys[@]}"; do
    builtin eval "local ent=\${$dicthead$tseq[key]}"
    if [[ ${ent:2} == "$command" ]]; then
      ble/array#push unbind_keys_list "${tseq//_/ } $key"
    fi
    if [[ ${ent::1} == _ ]]; then
      ble/builtin/bind/option:u/search-recursive "$kmap" "${tseq}_$key"
    fi
  done
}
## @fn ble/builtin/bind/option:-
##   @var[in] opt_keymap
function ble/builtin/bind/option:- {
  local ret; ble/string#trim "$1"; local arg=$ret

  # Note (#D1820): これまで行の途中から始まるコメントを除去していたが、実際に
  # inputrc 色々書き込んで調べると特に無視されている訳では無い事が分かった。
  # なので、行頭に # がある場合にのみ処理を中断することにする。
  [[ ! $arg || $arg == '#'* ]] && return 0

  # # コメント除去 (quote されていない "空白+#" 以降はコメント)
  # local q=\' ifs=$_ble_term_IFS
  # local rex='^(([^\"'$q$ifs']|"([^\"]|\\.)*"|'$q'([^\'$q']|\\.)*'$q'|\\.|['$ifs']+[^#'$_ifs'])*)['$ifs']+#'
  # [[ $arg =~ $rex ]] && arg=${BASH_REMATCH[1]}

  local ifs=$_ble_term_IFS
  if [[ $arg == 'set'["$ifs"]* ]]; then
    if [[ $_ble_decode_bind_state != none ]]; then
      local variable= value= rex=$'^set[ \t]+([^ \t]+)[ \t]+([^ \t].*)$'
      [[ $arg =~ $rex ]] && variable=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}

      case $variable in
      (keymap)
        ble/builtin/bind/set-keymap "$value"
        return 0 ;;
      (editing-mode)
        _ble_builtin_bind_keymap= ;;
      esac

      ble/function#try ble/builtin/bind/set:"$variable" "$value" && return 0
      builtin bind "$arg"
    fi
    return 0
  fi

  local keys value kmap
  if ! ble/builtin/bind/.initialize-keys-and-value "$arg"; then
    local q=\' Q="''\'"
    ble/util/print "ble.sh (bind): unrecognized readline command '${arg//$q/$Q}'." >&2
    flags=e$flags
    return 1
  elif ! ble/builtin/bind/.initialize-kmap "$opt_keymap"; then
    ble/util/print "ble.sh (bind): sorry, failed to initialize keymap:'$opt_keymap'." >&2
    flags=e$flags
    return 1
  fi

  if [[ $value == macro:* ]]; then
    value=${value#macro:}
    # keyboard macro
    local bind_keys="${keys[*]}"
    local ret chars; ble/util/keyseq2chars "$value"; chars=("${ret[@]}")
    local command="ble/widget/.MACRO ${chars[*]}"
    ble/decode/cmap/decode-chars "${chars[@]}"
    [[ ${keys[*]} != "$bind_keys" ]] &&
      ble-decode-key/bind "$kmap" "$bind_keys" "$command"
  elif [[ $value == rlfunc:?* ]]; then
    value=${value#rlfunc:}
    local ret; ble/builtin/bind/rlfunc2widget "$kmap" "$value"; local ext=$?
    if ((ext==0)); then
      local command=$ret
      ble-decode-key/bind "$kmap" "${keys[*]}" "$command"
      return 0
    elif ((ext==2)); then
      return 0
    else
      flags=e$flags
      return 1
    fi
  else
    ble/util/print "ble.sh (bind): readline function name is not specified ($arg)." >&2
    return 1
  fi
}
function ble/builtin/bind/.process {
  flags=
  local IFS=$_ble_term_IFS
  local opt_literal= opt_keymap=$_ble_builtin_bind_keymap opt_print=
  local -a opt_queries=()
  while (($#)); do
    local arg=$1; shift
    if [[ ! $opt_literal ]]; then
      case $arg in
      (--) opt_literal=1
           continue ;;
      (--help)
        if ((_ble_bash<40400)); then
          ble/util/print "ble.sh (bind): unrecognized option $arg" >&2
          flags=e$flags
        else
          # Note: Bash-4.4, 5.0 のバグで unwind_frame が壊れているので
          #   サブシェルで評価 #D0918
          #   https://lists.gnu.org/archive/html/bug-bash/2019-02/msg00033.html
          [[ $_ble_decode_bind_state != none ]] &&
            (builtin bind --help)
          flags=h$flags
        fi
        continue ;;
      (--*)
        ble/util/print "ble.sh (bind): unrecognized option $arg" >&2
        flags=e$flags
        continue ;;
      (-*)
        arg=${arg:1}
        while [[ $arg ]]; do
          local c=${arg::1}
          arg=${arg:1}
          case $c in
          ([lpPsSvVX])
            opt_print=$opt_print$c ;;
          ([mqurfx])
            local optarg=$arg
            arg=
            if [[ ! $optarg ]]; then
              if (($#==0)); then
                ble/util/print "ble.sh (bind): missing option argument for -$c" >&2
                flags=e$flags
                break
              fi
              optarg=$1; shift
            fi
            case $c in
            (m) ble/builtin/bind/option:m "$optarg" ;;
            (x) ble/builtin/bind/option:x "$optarg" ;;
            (r) ble/builtin/bind/option:r "$optarg" ;;
            (u) ble/builtin/bind/option:u "$optarg" ;;
            (q) ble/array#push opt_queries "$optarg" ;;
            (f) ble/decode/read-inputrc "$optarg" ;;
            (*)
              ble/util/print "ble.sh (bind): unsupported option -$c $optarg" >&2
              flags=e$flags ;;
            esac ;;
          (*)
            ble/util/print "ble.sh (bind): unrecognized option -$c" >&2
            flags=e$flags ;;
          esac
        done
        continue ;;
      esac
    fi

    ble/builtin/bind/option:- "$arg"
    opt_literal=1
  done

  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $opt_print == *[pPsSX]* ]] || ((${#opt_queries[@]})); then
      # Note: サブシェル内でバインディングを復元してから出力
      ( ble/decode/readline/unbind
        [[ -s "$_ble_base_run/$$.bind.save" ]] &&
          source "$_ble_base_run/$$.bind.save"
        [[ $opt_print ]] &&
          builtin bind ${opt_keymap:+-m "$opt_keymap"} -"$opt_print"
        declare rlfunc
        for rlfunc in "${opt_queries[@]}"; do
          builtin bind ${opt_keymap:+-m "$opt_keymap"} -q "$rlfunc"
        done )
    elif [[ $opt_print ]]; then
      builtin bind ${opt_keymap:+-m "$opt_keymap"} -"$opt_print"
    fi
  fi

  return 0
}
# inputrc の読み込み
_ble_builtin_bind_inputrc_done=
function ble/builtin/bind/initialize-inputrc {
  [[ $_ble_builtin_bind_inputrc_done ]] && return 0
  _ble_builtin_bind_inputrc_done=1

  if [[ $1 == all ]]; then
    local sys_inputrc=/etc/inputrc
    [[ -e $sys_inputrc ]] && ble/decode/read-inputrc "$sys_inputrc"
  fi
  local inputrc=${INPUTRC:-$HOME/.inputrc}
  [[ -e $inputrc ]] && ble/decode/read-inputrc "$inputrc"
}

# user 設定の読み込み
_ble_builtin_bind_user_settings_loaded=
function ble/builtin/bind/read-user-settings/.collect {
  local map
  for map in vi-insert vi-command emacs; do
    local cache=$_ble_base_cache/decode.readline.$_ble_bash.$map.txt
    if ! [[ -s $cache && $cache -nt $_ble_base/ble.sh ]]; then
      INPUTRC=/dev/null "$BASH" --noprofile --norc -i -c "builtin bind -m $map -p" 2>/dev/null |
        LC_ALL= LC_CTYPE=C ble/bin/sed '/^#/d;s/"\\M-/"\\e/' >| "$cache.part" &&
        ble/bin/mv "$cache.part" "$cache" || continue
    fi
    local cache_content
    ble/util/readfile cache_content "$cache"

    ble/util/print __CLEAR__
    ble/util/print KEYMAP="$map"
    ble/util/print __BIND0__
    ble/util/print "${cache_content%$_ble_term_nl}"
    if ((_ble_bash>=40300)); then
      ble/util/print __BINDX__
      builtin bind -m "$map" -X 2>/dev/null
    fi
    ble/util/print __BINDS__
    builtin bind -m "$map" -s 2>/dev/null
    ble/util/print __BINDP__
    builtin bind -m "$map" -p 2>/dev/null
    ble/util/print __PRINT__
  done
}
function ble/builtin/bind/read-user-settings/.reconstruct {
  local collect q=\'
  ble/util/assign collect ble/builtin/bind/read-user-settings/.collect
  <<< "$collect" LC_ALL= LC_CTYPE=C ble/bin/awk -v q="$q" -v _ble_bash="$_ble_bash" '
    function keymap_register(key, val, type) {
      if (!haskey[key]) {
        keys[nkey++] = key;
        haskey[key] = 1;
      }
      keymap[key] = val;
      keymap_type[key] = type;
    }
    function keymap_clear(_, i, key) {
      for(i = 0; i < nkey; i++) {
        key = keys[i];
        delete keymap[key];
        delete keymap_type[key];
        delete keymap0[key];
        haskey[key] = 0;
      }
      nkey = 0;
    }
    function keymap_print(_, i, key, type, value, text, line) {
      for (i = 0; i < nkey; i++) {
        key = keys[i];
        type = keymap_type[key];
        value = keymap[key];
        if (type == "" && value == keymap0[key]) continue;

        text = key ": " value;
        gsub(/'$q'/, q "\\" q q, text);

        line = "bind";
        if (KEYMAP != "") line = line " -m " KEYMAP;
        if (type == "x") line = line " -x";
        line = line " " q text q;
        print line;
      }
    }

    /^__BIND0__$/ { mode = 0; next; }
    /^__BINDX__$/ { mode = 1; next; }
    /^__BINDS__$/ { mode = 2; next; }
    /^__BINDP__$/ { mode = 3; next; }
    /^__CLEAR__$/ { keymap_clear(); next; }
    /^__PRINT__$/ { keymap_print(); next; }
    sub(/^KEYMAP=/, "") { KEYMAP = $0; }

    /(ble-decode\/.hook|_ble_decode_hook) / { next; }

    function workaround_bashbug(keyseq, _, rex, out, unit) {
      out = "";
      while (keyseq != "") {
        if (mode == 0 || mode == 3) {
          match(keyseq, /^\\C-\\(\\"$)?|^\\M-|^\\.|^./);
        } else {
#%        # bind -X, bind -s には問題はない
          match(keyseq, /^\\[CM]-|^\\.|^./);
        }
        unit = substr(keyseq, 1, RLENGTH);
        keyseq = substr(keyseq, 1 + RLENGTH);

        if (unit == "\\C-\\") {
#%        # Bash 3.0--5.0 Bug https://lists.gnu.org/archive/html/bug-bash/2020-01/msg00037.html
          unit = unit "\\";
        } else if (unit == "\\M-") {
#%        # Bash 3.1 以下では ESC は \M- と出力される
          unit = "\\e";
        }
        out = out unit;
      }
      return out;
    }

    function process_line(line, _, key, val) {
      # extract key and value
      if (match(line, /^"(\\.|[^"])+": /)) {
        key = substr(line, 1, RLENGTH - 2);
        val = substr(line, 1 + RLENGTH);
      } else if (mode == 1 && _ble_bash >= 50300 && match(line, /^"(\\.|[^"])+" /)) {
        key = substr(line, 1, RLENGTH - 1);
        val = substr(line, 1 + RLENGTH);
      } else {
        return 0;
      }
      if (_ble_bash < 50100)
        key = workaround_bashbug(key);

      if (mode) {
        type = mode == 1 ? "x" : mode == 2 ? "s" : "";
        keymap_register(key, val, type);
      } else {
        keymap0[key] = val;
      }
    }

    { process_line($0); }
  ' 2>/dev/null # suppress LC_ALL error messages
}

## @fn ble/builtin/bind/read-user-settings/.cache-enabled
##   @var[in] delay_prefix
function ble/builtin/bind/read-user-settings/.cache-enabled {
  local keymap use_cache=1
  for keymap in emacs vi_imap vi_nmap; do
    ble/decode/keymap#registered "$keymap" && return 1
    [[ -s $delay_prefix.$keymap ]] && return 1
  done
  return 0
}
## @fn ble/builtin/bind/read-user-settings/.cache-alive
##   @var[in] settings
##   @var[in] cache_prefix
function ble/builtin/bind/read-user-settings/.cache-alive {
  [[ -e $cache_prefix.settings ]] || return 1
  [[ $cache_prefix.settings -nt $_ble_base/lib/init-cmap.sh  ]] || return 1
  local keymap
  for keymap in emacs vi_imap vi_nmap; do
    [[ $cache_prefix.settings -nt $_ble_base/core-decode.$cache-rlfunc.txt ]] || return 1
    [[ -e $cache_prefix.$keymap ]] || return 1
  done
  local content
  ble/util/readfile content "$cache_prefix.settings"
  [[ ${content%$'\n'} == "$settings" ]]
}
## @fn ble/builtin/bind/read-user-settings/.cache-save
##   @var[in] delay_prefix
##   @var[in] cache_prefix
function ble/builtin/bind/read-user-settings/.cache-save {
  local keymap content fail=
  for keymap in emacs vi_imap vi_nmap; do
    if [[ -s $delay_prefix.$keymap ]]; then
      ble/util/copyfile "$delay_prefix.$keymap" "$cache_prefix.$keymap"
    else
      >| "$cache_prefix.$keymap"
    fi || fail=1
  done
  [[ $fail ]] && return 1
  ble/util/print "$settings" >| "$cache_prefix.settings"
}
## @fn ble/builtin/bind/read-user-settings/.cache-load
##   @var[in] delay_prefix
##   @var[in] cache_prefix
function ble/builtin/bind/read-user-settings/.cache-load {
  local keymap
  for keymap in emacs vi_imap vi_nmap; do
    ble/util/copyfile "$cache_prefix.$keymap" "$delay_prefix.$keymap"
  done
}

function ble/builtin/bind/read-user-settings {
  if [[ $_ble_decode_bind_state == none ]]; then
    [[ $_ble_builtin_bind_user_settings_loaded ]] && return 0
    _ble_builtin_bind_user_settings_loaded=1

    # Note: We here let readline read inputrc.  We redirect stderr to /dev/null
    # in order to suppress the warning `line editing not enabled'.
    builtin bind 2>/dev/null

    local settings
    ble/util/assign settings ble/builtin/bind/read-user-settings/.reconstruct
    [[ $settings ]] || return 0

    local cache_prefix=$_ble_base_cache/decode.inputrc.$_ble_decode_kbd_ver.$TERM
    local delay_prefix=$_ble_base_run/$$.bind.delay
    if ble/builtin/bind/read-user-settings/.cache-enabled; then
      if ble/builtin/bind/read-user-settings/.cache-alive; then
        ble/builtin/bind/read-user-settings/.cache-load
      else
        builtin eval -- "$settings" 2>/dev/null # suppress "line editing not enabled"
        ble/builtin/bind/read-user-settings/.cache-save
      fi
    else
      builtin eval -- "$settings" 2>/dev/null # suppress "line editing not enabled"
    fi
  fi
}

function ble/builtin/bind {
  local set shopt; ble/base/.adjust-bash-options set shopt

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH

  ble/decode/initialize
  local flags= ext=0
  ble/builtin/bind/.process "$@"
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin bind "$@"; ext=$?
  elif [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] &&
      builtin bind --usage 2>&1 1>/dev/null | ble/bin/grep ^bind >&2
    ext=2
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
  ble/base/.restore-bash-options set shopt
  return "$ext"
}
function bind {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble/builtin/bind "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
}

#------------------------------------------------------------------------------
# ble/decode/initialize, attach, detach                          @decode.attach

function ble/decode/initialize/.has-broken-suse-inputrc {
  # 1. Check if this is openSUSE and has /etc/input.keys.
  local content=
  [[ -s /etc/inputrc.keys && -r /etc/os-release ]] &&
    ble/util/readfile content /etc/os-release &&
    [[ $content == *'SUSE'* ]] || return 1

  # Note #1926: Even after the fix
  # https://github.com/openSUSE/aaa_base/pull/84, "inputrc.keys" causes
  # problems through extra bindings of the [home]/[end] escape sequences to
  # [prior], [Enter] to "accept-line", etc.  Thus, we comment out the following
  # part of codes and always return 0 when there is "/etc/inputrc.keys".

  # 2. Check if the file "inputrc.keys" has the bug.
  # ((_ble_bash<50000)) || return 1 # Bash 5.0+ are not suffered
  # ble/util/readfile content /etc/inputrc.keys &&
  #   [[ $content == *'"\M-[2~":'* ]] || return 1

  return 0
}

_ble_decode_initialized=
_ble_decode_initialize_inputrc=auto
function ble/decode/initialize {
  [[ $_ble_decode_initialized ]] && return 0
  _ble_decode_initialized=1
  ble/decode/cmap/initialize

  if [[ $_ble_decode_initialize_inputrc == auto ]]; then
    if ble/decode/initialize/.has-broken-suse-inputrc; then
      # Note: #D1662 WA openSUSE (aaa_base < 202102) has broken /etc/inputrc
      [[ ${INPUTRC-} == /etc/inputrc || ${INPUTRC-} == /etc/inputrc.keys ]] &&
        local INPUTRC=~/.inputrc
      _ble_decode_initialize_inputrc=user
    else
      _ble_decode_initialize_inputrc=diff
    fi
  fi
  case $_ble_decode_initialize_inputrc in
  (all)
    ble/builtin/bind/initialize-inputrc all ;;
  (user)
    ble/builtin/bind/initialize-inputrc ;;
  (diff)
    ble/builtin/bind/read-user-settings ;;
  esac
}

function ble/decode/reset-default-keymap {
  # 現在の ble-decode/keymap の設定
  local old_base_keymap=${_ble_decode_keymap_stack[0]:-$_ble_decode_keymap}
  ble-decode/INITIALIZE_DEFMAP -v _ble_decode_keymap # 0ms
  _ble_decode_keymap_stack=()
  if [[ $_ble_decode_keymap != "$old_base_keymap" ]]; then
    [[ $old_base_keymap ]] &&
      _ble_decode_keymap=$old_base_keymap ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_DETACH"
    ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_ATTACH" # 7ms for vi-mode

    # update cursor
    local cursor; ble/decode/keymap#get-cursor "$_ble_decode_keymap"
    [[ $cursor ]] && ble/term/cursor-state/set-internal "$((cursor))"
  fi
}

## @fn ble/decode/attach
##   @var[in] _ble_decode_keymap
##     この関数を呼び出す前に ble/decode/reset-default-keymap を用いて
##     _ble_decode_keymap が使用可能な状態になっている必要がある。
function ble/decode/attach {
  # 失敗すると悲惨なことになるのでチェック
  if ble/decode/keymap#is-empty "$_ble_decode_keymap"; then
    ble/util/print "ble.sh: The keymap '$_ble_decode_keymap' is empty." >&2
    return 1
  fi

  [[ $_ble_decode_bind_state != none ]] && return 0
  ble/util/save-editing-mode _ble_decode_bind_state
  [[ $_ble_decode_bind_state == none ]] && return 1

  # bind/unbind 中に C-c で中断されると大変なので先に stty を設定する必要がある
  ble/term/attach # 3ms

  # 既定の keymap に戻す
  ble/util/reset-keymap-of-editing-mode

  # 元のキー割り当ての保存・unbind
  builtin eval -- "$(ble/decode/readline/.generate-source-to-unbind-default)" # 21ms

  # ble.sh bind の設置
  ble/decode/readline/bind # 20ms

  return 0
}

function ble/decode/detach {
  [[ $_ble_decode_bind_state != none ]] || return 1

  local current_editing_mode=
  ble/util/save-editing-mode current_editing_mode
  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode _ble_decode_bind_state

  ble/term/detach

  # ble.sh bind の削除
  ble/decode/readline/unbind

  # 元のキー割り当ての復元
  if [[ -s "$_ble_base_run/$$.bind.save" ]]; then
    source "$_ble_base_run/$$.bind.save"
    >| "$_ble_base_run/$$.bind.save"
  fi

  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode current_editing_mode

  _ble_decode_bind_state=none
}

#------------------------------------------------------------------------------
# **** encoding = UTF-8 ****

function ble/encoding:UTF-8/generate-binder { return 0; }

# 以下は lib/init-bind.sh の中にある物と等価なので殊更に設定しなくて良い。

# ## @fn ble/encoding:UTF-8/generate-binder
# ##   lib/init-bind.sh の esc1B==3 の設定用。
# ##   lib/init-bind.sh の中から呼び出される。
# function ble/encoding:UTF-8/generate-binder {
#   ble/init:bind/bind-s '"\C-@":"\xC0\x80"'
#   ble/init:bind/bind-s '"\e":"\xDF\xBC"' # isolated ESC (U+07FC)
#   local i ret
#   for i in {0..255}; do
#     ble/decode/c2dqs "$i"
#     ble/init:bind/bind-s "\"\e$ret\": \"\xC0\x9B$ret\""
#   done
# }

_ble_encoding_utf8_decode_mode=0
_ble_encoding_utf8_decode_code=0
_ble_encoding_utf8_decode_table=(
  'M&&E,A[i++]='{0..127}
  'C=C<<6|'{0..63}',--M==0&&(A[i++]=C)'
  'M&&E,C='{0..31}',M=1'
  'M&&E,C='{0..15}',M=2'
  'M&&E,C='{0..7}',M=3'
  'M&&E,C='{0..3}',M=4'
  'M&&E,C='{0..1}',M=5'
  'M&&E,A[i++]=_ble_decode_Erro|'{254,255}
)
function ble/encoding:UTF-8/clear {
  _ble_encoding_utf8_decode_mode=0
  _ble_encoding_utf8_decode_code=0
}
function ble/encoding:UTF-8/is-intermediate {
  ((_ble_encoding_utf8_decode_mode))
}
function ble/encoding:UTF-8/decode {
  local C=$_ble_encoding_utf8_decode_code
  local M=$_ble_encoding_utf8_decode_mode
  local E='M=0,A[i++]=_ble_decode_Erro|C'
  local -a A=()
  local i=0 b
  for b; do
    ((_ble_encoding_utf8_decode_table[b&255]))
  done
  _ble_encoding_utf8_decode_code=$C
  _ble_encoding_utf8_decode_mode=$M
  ((i)) && ble-decode-char "${A[@]}"
}

## @fn ble/encoding:UTF-8/c2bc code
##   @param[in]  code
##   @var  [out] ret
function ble/encoding:UTF-8/c2bc {
  local code=$1
  ((ret=code<0x80?1:
    (code<0x800?2:
    (code<0x10000?3:
    (code<0x200000?4:5)))))
}

## @fn ble/encoding:C/generate-binder
##   lib/init-bind.sh の esc1B==3 の設定用。
##   lib/init-bind.sh の中から呼び出される。
function ble/encoding:C/generate-binder {
  ble/init:bind/bind-s '"\C-@":"\x9B\x80"'
  ble/init:bind/bind-s '"\e":"\x9B\x8B"' # isolated ESC (U+07FC) に後で変換
  local i ret
  for i in {0..255}; do
    ble/decode/c2dqs "$i"
    ble/init:bind/bind-s "\"\e$ret\": \"\x9B\x9B$ret\""
  done
}

## @fn ble/encoding:C/decode byte
##
##   受け取ったバイトをそのまま文字コードと解釈する。
##   但し、bind の都合 (bashbug の回避) により以下の変換を行う。
##
##   \x9B\x80 (155 128) → C-@
##   \x9B\x8B (155 139) → isolated ESC U+07FC (2044)
##   \x9B\x9B (155 155) → ESC
##
##   実際にこの組み合わせの入力が来ると誤変換されるが、
##   この組み合わせは不正な CSI シーケンスなので、
##   入力に混入した時の動作は元々保証外である。
##
_ble_encoding_c_csi=
function ble/encoding:C/clear {
  _ble_encoding_c_csi=
}
function ble/encoding:C/is-intermediate {
  [[ $_ble_encoding_c_csi ]]
}
function ble/encoding:C/decode {
  local -a A=()
  local i=0 b
  for b; do
    if [[ $_ble_encoding_c_csi ]]; then
      _ble_encoding_c_csi=
      case $b in
      (155) A[i++]=27 # ESC
            continue ;;
      (139) A[i++]=2044 # isolated ESC U+07FC
            continue ;;
      (128) A[i++]=0 # C-@
            continue ;;
      esac
      A[i++]=155
    fi

    if ((b==155)); then
      _ble_encoding_c_csi=1
    else
      A[i++]=$b
    fi
  done
  ((i)) && ble-decode-char "${A[@]}"
}

## @fn ble/encoding:C/c2bc charcode
##   @var[out] ret
function ble/encoding:C/c2bc {
  ret=1
}
