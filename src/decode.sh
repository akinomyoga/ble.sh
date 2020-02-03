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

## オプション default_keymap
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
  (auto|emacs|vi|safe) ;;
  (*)
    ble/util/print "bleopt: Invalid value default_keymap='value'. The value should be one of \`auto', \`emacs', \`vi'." >&2
    return 1 ;;
  esac
}

## 関数 bleopt/get:default_keymap
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

## オプション decode_isolated_esc
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

## オプション decode_abort_char
bleopt/declare -n decode_abort_char 28

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

_ble_decode_IsolatedESC=$((0x07FF))
_ble_decode_EscapedNUL=$((0x07FE)) # charlog#encode で用いる
_ble_decode_FunctionKeyBase=0x110000

## 関数 ble-decode-kbd/.set-keycode keyname key
##
## 関数 ble-decode-kbd/.get-keycode keyname
##   @var[out] ret
if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  _ble_decode_kbd_ver=4
  _ble_decode_kbd__n=0
  if ((_ble_bash>=40200)); then
    declare -gA _ble_decode_kbd__k2c=()
  else
    declare -A _ble_decode_kbd__k2c=()
  fi
  _ble_decode_kbd__c2k=()

  function ble-decode-kbd/.set-keycode {
    local keyname=$1
    local code=$2
    : ${_ble_decode_kbd__c2k[code]:=$keyname}
    _ble_decode_kbd__k2c[$keyname]=$code
  }
  function ble-decode-kbd/.get-keycode {
    ret=${_ble_decode_kbd__k2c[$1]}
  }
else
  _ble_decode_kbd_ver=3
  _ble_decode_kbd__n=0
  _ble_decode_kbd__k2c_keys=
  _ble_decode_kbd__k2c_vals=()
  _ble_decode_kbd__c2k=()
  function ble-decode-kbd/.set-keycode {
    local keyname=$1
    local code=$2
    : ${_ble_decode_kbd__c2k[code]:=$keyname}
    _ble_decode_kbd__k2c_keys=$_ble_decode_kbd__k2c_keys:$keyname:
    _ble_decode_kbd__k2c_vals[${#_ble_decode_kbd__k2c_vals[@]}]=$code
  }
  function ble-decode-kbd/.get-keycode {
    local keyname=$1
    local tmp=${_ble_decode_kbd__k2c_keys%%:$keyname:*}
    if [[ ${#tmp} == ${#_ble_decode_kbd__k2c_keys} ]]; then
      ret=
    else
      local -a arr; ble/string#split-words arr "${tmp//:/ }"
      ret=${_ble_decode_kbd__k2c_vals[${#arr[@]}]}
    fi
  }
fi

## 関数 ble-decode-kbd/.get-keyname keycode
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
## 関数 ble-decode-kbd/generate-keycode keyname
##   指定した名前に対応する keycode を取得します。
##   指定した名前の key が登録されていない場合は、
##   新しく kecode を割り当てて返します。
##   @param[in]  keyname keyname
##   @var  [out] ret     keycode
function ble-decode-kbd/generate-keycode {
  local keyname=$1
  if ((${#keyname}==1)); then
    ble/util/s2c "$1"
  elif [[ $keyname && ! ${keyname//[a-zA-Z_0-9]} ]]; then
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

  # Note: 暫定的な対応なので後で変更するかもしれない
  ble-decode-kbd/generate-keycode mouse
  _ble_decode_KCODE_MOUSE=$ret
  ble-decode-kbd/generate-keycode mouse_move
  _ble_decode_KCODE_MOUSE_MOVE=$ret

  # Note: ここに新しく kcode を追加した時には init-cmap.sh に何か変更をして、
  # cmap 及び keymap が更新される様にする必要がある。emacs.sh, vi.sh については
  # init-cmap.sh を見て自動的に更新されるので特別な処置は必要ない筈。
}

ble-decode-kbd/.initialize

## 関数 ble-decode-kbd kspecs...
##   @param[in] kspecs
##   @var[out] ret
function ble-decode-kbd {
  local kspecs; ble/string#split-words kspecs "$*"
  local kspec code codes
  codes=()
  for kspec in "${kspecs[@]}"; do
    code=0
    while [[ $kspec == ?-* ]]; do
      case "${kspec::1}" in
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
      ble/util/s2c "$kspec" 0
      ((code|=ret))
    elif [[ $kspec && ! ${kspec//[@_0-9a-zA-Z]} ]]; then
      ble-decode-kbd/.get-keycode "$kspec"
      [[ $ret ]] || ble-decode-kbd/generate-keycode "$kspec"
      ((code|=ret))
    elif [[ $kspec == ^? ]]; then
      if [[ $kspec == '^?' ]]; then
        ((code|=0x7F))
      elif [[ $kspec == '^`' ]]; then
        ((code|=0x20))
      else
        ble/util/s2c "$kspec" 1
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

## 関数 ble-decode-unkbd/.single-key key
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

## 関数 ble-decode-unkbd keys...
##   @param[in] keys
##     キーを表す整数値の列を指定します。
##   @var[out] ret
function ble-decode-unkbd {
  local -a kspecs
  local key
  for key in $*; do
    ble-decode-unkbd/.single-key "$key"
    kspecs[${#kspecs[@]}]=$ret
  done
  ret="${kspecs[*]}"
}

# **** ble-decode-byte ****

## 設定関数 ble-decode/PROLOGUE
## 設定関数 ble-decode/EPILOGUE
function ble-decode/PROLOGUE { :; }
function ble-decode/EPILOGUE { :; }

_ble_decode_input_count=0
_ble_decode_input_buffer=()
_ble_decode_input_original_info=()

_ble_decode_show_progress_hook=ble-decode/.hook/show-progress
_ble_decode_erase_progress_hook=ble-decode/.hook/erase-progress
function ble-decode/.hook/show-progress {
  if [[ $_ble_edit_info_scene == store ]]; then
    _ble_decode_input_original_info=("${_ble_edit_info[@]}")
    return
  elif [[ $_ble_edit_info_scene == default ]]; then
    _ble_decode_input_original_info=()
  elif [[ $_ble_edit_info_scene != decode_input_progress ]]; then
    return
  fi

  if ((_ble_decode_input_count)); then
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
    return
  fi

  local mill=$((value*1000/total))
  local cent=${mill::${#mill}-1} frac=${mill:${#mill}-1}
  local text="(${cent:-0}.$frac% $label)"

  if ble/util/is-unicode-output; then
    local ret
    ble/string#create-unicode-progress-bar "$value" "$total" 10
    text=$sgr$ret$'\e[m '$text
  fi

  ble-edit/info/show ansi "$text"

  _ble_edit_info_scene=decode_input_progress
}
function ble-decode/.hook/erase-progress {
  [[ $_ble_edit_info_scene == decode_input_progress ]] || return
  if ((${#_ble_decode_input_original_info[@]})); then
    ble-edit/info/show store "${_ble_decode_input_original_info[@]}"
  else
    ble-edit/info/default
  fi
}

function ble-decode/.hook {
  if ble/util/is-stdin-ready; then
    ble/array#push _ble_decode_input_buffer "$@"
    return
  fi

  # Note: bind -x 内の set +v は揮発性なのでできるだけ先頭で set +v しておく。
  # (PROLOGUE 内から呼ばれる) stdout.on より前であれば大丈夫 #D0930
  [[ $_ble_bash_options_adjusted ]] && set +v || :

  local IFS=$' \t\n'
  ble-decode/PROLOGUE

  # abort #D0998
  if (($1==bleopt_decode_abort_char)); then
    local nbytes=${#_ble_decode_input_buffer[@]}
    local nchars=${#_ble_decode_char_buffer[@]}
    if ((nbytes||nchars)); then
      _ble_decode_input_buffer=()
      _ble_decode_char_buffer=()
      ble/term/visible-bell "Abort by 'bleopt decode_abort_char=$bleopt_decode_abort_char'"
      shift
      # 何れにしても EPILOGUE を実行する必要があるので下に流れる。
      # ble/term/visible-bell を表示する為には PROLOGUE の後でなければならない事にも注意する。
    fi
  fi

  local chars
  chars=("${_ble_decode_input_buffer[@]}" "$@")
  _ble_decode_input_buffer=()
  _ble_decode_input_count=${#chars[@]}

  if ((_ble_decode_input_count>=200)); then
    local c
    for c in "${chars[@]}"; do
      ((--_ble_decode_input_count%100==0)) && eval -- "$_ble_decode_show_progress_hook"
#%if debug_keylogger
      ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_bytes "$c"
#%end
      "ble/encoding:$bleopt_input_encoding/decode" "$c"
    done
  else
    local c
    for c in "${chars[@]}"; do
      ((--_ble_decode_input_count))
#%if debug_keylogger
      ((_ble_debug_keylog_enabled)) && ble/array#push _ble_debug_keylog_bytes "$c"
#%end
      "ble/encoding:$bleopt_input_encoding/decode" "$c"
    done
  fi

  eval -- "$_ble_decode_erase_progress_hook"
  ble-decode/EPILOGUE
}

## 公開関数 ble-decode-byte bytes...
##   バイト値を整数で受け取って、現在の文字符号化方式に従ってデコードをします。
##   デコードした結果得られた文字は ble-decode-char を呼び出す事によって処理します。
##
##   Note: 現在 ble.sh 内部では使用されていません。
##     この関数はユーザが呼び出す事を想定した関数です。
function ble-decode-byte {
  while (($#)); do
    "ble/encoding:$bleopt_input_encoding/decode" "$1"
    shift
  done
}

# **** ble-decode-char/csi ****

_ble_decode_csi_mode=0
_ble_decode_csi_args=
_ble_decode_csimap_tilde=()
_ble_decode_csimap_alpha=()
function ble-decode-char/csi/print {
  local num ret
  for num in "${!_ble_decode_csimap_tilde[@]}"; do
    ble-decode-unkbd "${_ble_decode_csimap_tilde[num]}"
    ble/util/print "ble-bind --csi '$num~' $ret"
  done

  for num in "${!_ble_decode_csimap_alpha[@]}"; do
    local s; ble/util/c2s "$num"; s=$ret
    ble-decode-unkbd "${_ble_decode_csimap_alpha[num]}"
    ble/util/print "ble-bind --csi '$s' $ret"
  done
}

function ble-decode-char/csi/clear {
  _ble_decode_csi_mode=0
}
function ble-decode-char/csi/.modify-key {
  local mod=$(($1-1))
  if ((mod>=0)); then
    # Note: xterm, mintty では modifyOtherKeys で通常文字に対するシフトは
    #   文字自体もそれに応じて変化させ、更に修飾フラグも設定する。
    if ((33<=key&&key<_ble_decode_FunctionKeyBase)); then
      if ((mod==0x01)); then
        # S- だけの時には単に S- を外す
        mod=0
      elif ((65<=key&&key<=90)); then
        # 他の修飾がある時は英大文字は小文字に統一する
        ((key|=0x20))
      fi
    fi

    # Note: Supr 0x08 以降は独自
    ((mod&0x01&&(key|=_ble_decode_Shft),
      mod&0x02&&(key|=_ble_decode_Meta),
      mod&0x04&&(key|=_ble_decode_Ctrl),
      mod&0x08&&(key|=_ble_decode_Supr),
      mod&0x10&&(key|=_ble_decode_Hypr),
      mod&0x20&&(key|=_ble_decode_Altr)))
  fi
}
function ble-decode-char/csi/.decode {
  local char=$1 rex key
  if ((char==126)); then # ~
    if rex='^27;([1-9][0-9]*);?([1-9][0-9]*)$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # xterm "CSI 2 7 ; <mod> ; <char> ~" sequences
      local key=$((BASH_REMATCH[2]&_ble_decode_MaskChar))
      ble-decode-char/csi/.modify-key "${BASH_REMATCH[1]}"
      csistat=$key
      return
    fi

    if rex='^([1-9][0-9]*)(;([1-9][0-9]*))?$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # "CSI <key> ; <mod> ~" sequences
      key=${_ble_decode_csimap_tilde[BASH_REMATCH[1]]}
      if [[ $key ]]; then
        ble-decode-char/csi/.modify-key "${BASH_REMATCH[3]}"
        csistat=$key
        return
      fi
    fi
  elif ((char==117)); then # u
    if rex='^([0-9]*)(;[0-9]*)?$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # xterm/mlterm "CSI <char> ; <mode> u" sequences
      # Note: 実は "CSI 1 ; mod u" が kp5 とする端末がある事に注意する。
      local rematch1=${BASH_REMATCH[1]}
      if [[ $rematch1 != 1 ]]; then
        local key=$rematch1 mods=${BASH_REMATCH:${#rematch1}+1}
        ble-decode-char/csi/.modify-key "$mods"
        csistat=$key
      fi
      return
    fi
  elif ((char==94||char==64)); then # ^, @
    if rex='^[1-9][0-9]*$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # rxvt "CSI <key> ^", "CSI <key> @" sequences
      key=${_ble_decode_csimap_tilde[BASH_REMATCH[1]]}
      if [[ $key ]]; then
        ((key|=_ble_decode_Ctrl,
          char==64&&(key|=_ble_decode_Shft)))
        ble-decode-char/csi/.modify-key "${BASH_REMATCH[3]}"
        csistat=$key
        return
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
      return
    fi
  elif ((char==82||char==110)); then # R or n
    if rex='^([0-9]+);([0-9]+)$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      # DSR(6) に対する応答 CPR "CSI Pn ; Pn R"
      # Note: Poderosa は DSR(Pn;Pn) "CSI Pn ; Pn n" で返す。
      ble/term/CPR/notify $((10#${BASH_REMATCH[1]})) $((10#${BASH_REMATCH[2]}))
      csistat=$_ble_decode_KCODE_IGNORE
      return
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
      local button=$((10#${BASH_REMATCH[1]}))
      ((_ble_term_mouse_button=button&~0x1C,
        char==109&&(_ble_term_mouse_button|=0x70),
        _ble_term_mouse_x=10#${BASH_REMATCH[2]},
        _ble_term_mouse_y=10#${BASH_REMATCH[3]}))
      local key=$_ble_decode_KCODE_MOUSE
      ((button&32)) && key=$_ble_decode_KCODE_MOUSE_MOVE
      ble-decode-char/csi/.modify-key $((button>>2&0x07))
      csistat=$key
      return
    fi
  elif ((char==116)); then # t
    if rex='^<([0-9]+);([0-9]+)$'; [[ $_ble_decode_csi_args =~ $rex ]]; then
      ## mouse_select
      ((_ble_term_mouse_button=128,
        _ble_term_mouse_x=10#${BASH_REMATCH[1]},
        _ble_term_mouse_y=10#${BASH_REMATCH[2]}))
      local key=$_ble_decode_KCODE_MOUSE
      csistat=$key
    fi
  fi

  # pc-style "CSI 1; <mod> A" sequences
  key=${_ble_decode_csimap_alpha[char]}
  if [[ $key ]]; then
    if rex='^(1?|1;([1-9][0-9]*))$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      ble-decode-char/csi/.modify-key "${BASH_REMATCH[2]}"
      csistat=$key
      return
    fi
  fi

  csistat=$_ble_decode_KCODE_ERROR
}

## 関数 ble-decode-char/csi/consume char
##   @param[in] char
##   @var[out] csistat
function ble-decode-char/csi/consume {
  csistat=

  # 一番頻度の高い物
  ((_ble_decode_csi_mode==0&&$1!=27&&$1!=155)) && return 1

  local char=$1
  case "$_ble_decode_csi_mode" in
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
    ble/util/is-stdin-ready ||
    ble/encoding:"$bleopt_input_encoding"/is-intermediate
}

_ble_decode_char__hook=

## 配列 _ble_decode_cmap_${_ble_decode_char__seq}[char]
##   文字列からキーへの写像を保持する。
##   各要素は文字の列 ($_ble_decode_char__seq $char) に対する定義を保持する。
##   各要素は以下の形式の何れかである。
##   key+ 文字の列がキー key に一意に対応する事を表す。
##   _    文字の列が何らかのキーを表す文字列の prefix になっている事を表す。
##   key_ 文字の列がキー key に対応すると同時に、
##        他のキーの文字列の prefix になっている事を表す。
_ble_decode_cmap_=()

# _ble_decode_char__seq が設定されている時は、
# 必ず _ble_decode_char2_reach も設定されている様にする。
_ble_decode_char2_seq=
_ble_decode_char2_reach=
_ble_decode_char2_modifier=
_ble_decode_char2_modkcode=
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
  # Note: ループ中で set -- ... を使っている。
  while
    if ((iloop++%50==0)); then
      ((iloop>50)) && eval -- "$_ble_decode_show_progress_hook"
      if [[ ! $ble_decode_char_sync ]] && ble/decode/has-input-for-char; then
        ble/array#push _ble_decode_char_buffer "$@"
        return 148
      fi
    fi
    # 入れ子の ble-decode-char 呼び出しによる入力。
    if ((${#_ble_decode_char_buffer[@]})); then
      ((ble_decode_char_total+=${#_ble_decode_char_buffer[@]}))
      set -- "${_ble_decode_char_buffer[@]}" "$@"
      _ble_decode_char_buffer=()
    fi
    (($#))
  do
    local char=$1; shift
    ble_decode_char_rest=$#
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

    local ent
    ble-decode-char/.getent
    if [[ ! $ent ]]; then
      # シーケンスが登録されていない時
      if [[ $_ble_decode_char2_reach ]]; then
        local reach rest
        reach=($_ble_decode_char2_reach)
        rest=${_ble_decode_char2_seq:reach[1]}
        rest=(${rest//_/ } $char)

        _ble_decode_char2_reach=
        _ble_decode_char2_seq=
        ble-decode-char/csi/clear

        ble-decode-char/.send-modified-key "${reach[0]}"
        ((ble_decode_char_total+=${#rest[@]}))
        set -- "${rest[@]}" "$@"
      else
        ble-decode-char/.send-modified-key "$char"
      fi
    elif [[ $ent == *_ ]]; then
      # /\d*_/ (_ は続き (1つ以上の有効なシーケンス) がある事を示す)
      _ble_decode_char2_seq=${_ble_decode_char2_seq}_$char
      if [[ ${ent%_} ]]; then
        _ble_decode_char2_reach="${ent%_} ${#_ble_decode_char2_seq}"
      elif [[ ! $_ble_decode_char2_reach ]]; then
        # 1文字目
        _ble_decode_char2_reach="$char ${#_ble_decode_char2_seq}"
      fi
    else
      # /\d+/  (続きのシーケンスはなく ent で確定である事を示す)
      _ble_decode_char2_seq=
      _ble_decode_char2_reach=
      ble-decode-char/csi/clear
      ble-decode-char/.send-modified-key "$ent"
    fi
  done
  return 0
}

## 関数 ble-decode-char/.getent
##   @var[in] _ble_decode_char2_seq
##   @var[in] char
##   @var[out] ent
function ble-decode-char/.getent {
  builtin eval "ent=\${_ble_decode_cmap_$_ble_decode_char2_seq[char]-}"

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
        local ret; ble-decode-unkbd ${_ble_decode_char2_seq//_/ } $char
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

function ble-decode-char/.process-modifier {
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
    return 0
  fi
}

## 関数 ble-decode-char/.send-modified-key key
##   指定されたキーを修飾して ble-decode-key に渡します。
##   key = 0..31 は C-@ C-a ... C-z C-[ C-\ C-] C-^ C-_ に変換されます。
##   ESC は次に来る文字を meta 修飾します。
##   _ble_decode_IsolatedESC は meta にならずに ESC として渡されます。
##   @param[in] key
##     処理対象のキーコードを指定します。
function ble-decode-char/.send-modified-key {
  local key=$1
  ((key==_ble_decode_KCODE_IGNORE)) && return

  if ((0<=key&&key<32)); then
    ((key|=(key==0||key>26?64:96)|_ble_decode_Ctrl))
  fi

  if (($1==27)); then
    ble-decode-char/.process-modifier "$_ble_decode_Meta" && return
  elif (($1==_ble_decode_IsolatedESC)); then
    ((key=(_ble_decode_Ctrl|91)))
    if ! ble/decode/uses-isolated-esc; then
      ble-decode-char/.process-modifier "$_ble_decode_Meta" && return
    fi
  elif ((_ble_decode_KCODE_SHIFT<=$1&&$1<=_ble_decode_KCODE_HYPER)); then
    case "$1" in
    ($_ble_decode_KCODE_SHIFT)
      ble-decode-char/.process-modifier "$_ble_decode_Shft" && return ;;
    ($_ble_decode_KCODE_CONTROL)
      ble-decode-char/.process-modifier "$_ble_decode_Ctrl" && return ;;
    ($_ble_decode_KCODE_ALTER)
      ble-decode-char/.process-modifier "$_ble_decode_Altr" && return ;;
    ($_ble_decode_KCODE_META)
      ble-decode-char/.process-modifier "$_ble_decode_Meta" && return ;;
    ($_ble_decode_KCODE_SUPER)
      ble-decode-char/.process-modifier "$_ble_decode_Supr" && return ;;
    ($_ble_decode_KCODE_HYPER)
      ble-decode-char/.process-modifier "$_ble_decode_Hypr" && return ;;
    esac
  fi

  if [[ $_ble_decode_char2_modifier ]]; then
    local mflag=$_ble_decode_char2_modifier
    local mcode=$_ble_decode_char2_modkcode
    _ble_decode_char2_modifier=
    _ble_decode_char2_modkcode=
    if ((key&mflag)); then
      ble-decode-key "$mcode"
    else
      ((key|=mflag))
    fi
  fi

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

    unset -v "_ble_decode_cmap_$tseq[char]"
    builtin eval "((\${#_ble_decode_cmap_$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    char=${tseq##*_}
    tseq=${tseq%_*}
  done
}
function ble-decode-char/dump {
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
      ble-decode-unkbd "$key"; local kspec=$ret
      ble/util/print "ble-bind -k '${cnames[*]}' '$kspec'"
    fi

    if [[ ${ent//[0-9]} == _ ]]; then
      ble-decode-char/dump "${tseq}_$ccode" "${cnames[@]}"
    fi
  done
}

# **** ble-decode-key ****

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

## 変数 _ble_decode_keymap_list := ( ':' kmap )+
##   初期化済みの kmap の名前の一覧を保持します。
##   既定の kmap (名前無し) は含まれません。
_ble_decode_keymap_list=
function ble-decode/keymap/registered {
  [[ :$_ble_decode_keymap_list: == *:"$1":* ]]
}
## 関数 ble-decode/keymap/.register kmap
##   @exit 新しく keymap が登録された時に成功します。
##     既存の keymap だった時に失敗します。
##   @remarks
##     この関数は keymap cache から読み出されます。
function ble-decode/keymap/.register {
  local kmap=$1
  if [[ $kmap && :$_ble_decode_keymap_list: != *:"$kmap":* ]]; then
    _ble_decode_keymap_list=$_ble_decode_keymap_list:$kmap
  fi
}
function ble-decode/keymap/.unregister {
  _ble_decode_keymap_list=$_ble_decode_keymap_list:
  _ble_decode_keymap_list=${_ble_decode_keymap_list//:"$1":/:}
  _ble_decode_keymap_list=${_ble_decode_keymap_list%:}
}
function ble-decode/keymap/is-keymap {
  ble-decode/keymap/registered "$1" || ble/is-function "ble-decode/keymap:$1/define"
}

function ble-decode/keymap/is-empty {
  ! ble/is-array "_ble_decode_${1}_kmap_" ||
    builtin eval -- "((\${#_ble_decode_${1}_kmap_[*]}==0))"
}

function ble-decode/keymap/.onload {
  local kmap=$1
  local delay=$_ble_base_run/$$.bind.delay.$kmap
  if [[ -s $delay ]]; then
    source "$delay"
    : >| "$delay"
  fi
}

_ble_decode_keymap_load=
function ble-decode/keymap/load {
  local opts=:$2:
  ble-decode/keymap/registered "$1" && return 0

  local init=ble-decode/keymap:$1/define
  ble/is-function "$init" || return 1

  ble-decode/keymap/.register "$1"
  local ble_bind_keymap=$1
  if ! "$init" || ble-decode/keymap/is-empty "$1"; then
    ble-decode/keymap/.unregister "$1"
    return 1
  fi

  [[ $opts == *:dump:* ]] &&
    ble-decode/keymap/dump "$1" >&3
  ble-decode/keymap/.onload "$1"
  return 0
}
## 関数 ble-decode/keymap/unload [keymap_name...]
function ble-decode/keymap/unload {
  if (($#==0)); then
    local list; ble/string#split-words list "${_ble_decode_keymap_list//:/ }"
    set -- "${list[@]}"
  fi

  while (($#)); do
    local array_names array_name
    builtin eval -- "array_names=(\"\${!_ble_decode_${1}_kmap_@}\")"
    for array_name in "${array_names[@]}"; do
      unset -v "$array_name"
    done
    ble-decode/keymap/.unregister "$1"
    shift
  done
}

if [[ $_ble_decode_kmaps ]]; then
  ## 関数 ble-decode/keymap/cleanup-old-keymaps
  ##   古い形式の keymap を削除する (#D1076)
  ##   0.4.0-devel1+e13e979 以前は unload 時に keymaps を削除していなかった為に、
  ##   reload した時に keycode 不整合で無限ループになってしまうバグがあった。
  function ble-decode/keymap/cleanup-old-keymaps {
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
      ble-decode/keymap/unload "$keymap_name"
    done
    unset -v _ble_decode_kmaps
  }
  ble-decode/keymap/cleanup-old-keymaps
fi

function ble-decode/keymap/dump {
  if (($#)); then
    local kmap=$1 arrays
    builtin eval "arrays=(\"\${!_ble_decode_${kmap}_kmap_@}\")"
    ble/util/print "ble-decode/keymap/.register $kmap"
    ble/util/declare-print-definitions "${arrays[@]}"
    ble/util/print "ble-decode/keymap/.onload $kmap"
  else
    local list; ble/string#split-words list "${_ble_decode_keymap_list//:/ }"
    local keymap_name
    for keymap_name in "${list[@]}"; do
      ble-decode/keymap/dump "$keymap_name"
    done
  fi
}

## 関数 ble-decode/GET_BASEMAP -v varname
##   既定の基底 keymap を返します。
function ble-decode/GET_BASEMAP {
  [[ $1 == -v ]] || return 1
  local ret; bleopt/get:default_keymap
  [[ $ret == vi ]] && ret=vi_imap
  builtin eval "$2=\$ret"
}
## 設定関数 ble-decode/INITIALIZE_DEFMAP -v varname
##   既定の keymap を決定します。
##   ble-decode.sh 使用コードで上書きして使用します。
function ble-decode/INITIALIZE_DEFMAP {
  ble-decode/GET_BASEMAP "$@" &&
    ble-decode/keymap/load "${!2}" &&
    return 0

  # fallback
  ble-decode/keymap/load safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

## 設定関数 ble/widget/.SHELL_COMMAND command
##   ble-bind -c で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND { eval "$*"; }
## 設定関数 ble/widget/.EDIT_COMMAND command
##   ble-bind -x で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND { eval "$*"; }

## 関数 ble-decode-key/bind keymap keys command
##   @param[in] keymap keys command
function ble-decode-key/bind {
  if ! ble-decode/keymap/registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return
  fi

  local kmap=$1 keys=$2 cmd=$3

  # Check existence of widget
  if local widget=${cmd%%[$_ble_term_IFS]*}; ! ble/is-function "$widget"; then
    local message="ble-bind: Unknown widget \`${widget#'ble/widget/'}'."
    [[ $command == ble/widget/ble/widget/* ]] &&
      message="$message Note: The prefix 'ble/widget/' is redundant."
    ble/util/print "$message" 1>&2
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
  if ! ble-decode/keymap/registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return
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

## 関数 ble-decode-key/unbind keymap keys
function ble-decode-key/unbind {
  if ! ble-decode/keymap/registered "$1"; then
    ble/util/print-quoted-command "$FUNCNAME" "$@" >> "$_ble_base_run/$$.bind.delay.$1"
    return
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

    unset -v "$dicthead$tseq[key]"
    builtin eval "((\${#$dicthead$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    key=${tseq##*_}
    tseq=${tseq%_*}
  done
}

function ble-decode-key/dump {
  # 引数の無い場合: 全ての kmap を dump
  local kmap
  if (($#==0)); then
    for kmap in ${_ble_decode_keymap_list//:/ }; do
      ble/util/print "# keymap $kmap"
      ble-decode-key/dump "$kmap"
    done
    return
  fi

  local kmap=$1 tseq=$2 nseq=$3
  local dicthead=_ble_decode_${kmap}_kmap_
  local kmapopt=
  [[ $kmap ]] && kmapopt=" -m '$kmap'"

  local key keys
  builtin eval "keys=(\${!$dicthead$tseq[@]})"
  for key in "${keys[@]}"; do
    local ret; ble-decode-unkbd "$key"
    local knames=$nseq${nseq:+ }$ret
    builtin eval "local ent=\${$dicthead$tseq[key]}"
    if [[ $ent == *:* ]]; then
      local cmd=${ent#*:} q=\' Q="'\''"
      case "$cmd" in
      ('ble/widget/.SHELL_COMMAND '*)
        ble/util/print "ble-bind$kmapopt -c '${knames//$q/$Q}' ${cmd#ble/widget/.SHELL_COMMAND }" ;;
      ('ble/widget/.EDIT_COMMAND '*)
        ble/util/print "ble-bind$kmapopt -x '${knames//$q/$Q}' ${cmd#ble/widget/.EDIT_COMMAND }" ;;
      ('ble/widget/.MACRO '*)
        local ret; ble/util/chars2keyseq ${cmd#*' '}
        ble/util/print "ble-bind$kmapopt -s '${knames//$q/$Q}' '${ret//$q/$Q}'" ;;
      ('ble/widget/'*)
        ble/util/print "ble-bind$kmapopt -f '${knames//$q/$Q}' '${cmd#ble/widget/}'" ;;
      (*)
        ble/util/print "ble-bind$kmapopt -@ '${knames//$q/$Q}' '${cmd}'" ;;
      esac
    fi

    if [[ ${ent::1} == _ ]]; then
      ble-decode-key/dump "$kmap" "${tseq}_$key" "$knames"
      if [[ $ent == _[0-9]* ]]; then
        local timeout=${ent%%:*}; timeout=${timeout:1}
        ble/util/print "ble-bind$kmapopt -T '${knames//$q/$Q}' $timeout"
      fi
    fi
  done
}

## 変数 _ble_decode_keymap
##
##   現在選択されている keymap
##
## 配列 _ble_decode_keymap_stack
##
##   呼び出し元の keymap を記録するスタック
##
_ble_decode_keymap=emacs
_ble_decode_keymap_stack=()

## 関数 ble-decode/keymap/push kmap
function ble-decode/keymap/push {
  if ble-decode/keymap/registered "$1"; then
    ble/array#push _ble_decode_keymap_stack "$_ble_decode_keymap"
    _ble_decode_keymap=$1
  elif ble-decode/keymap/load "$1" && ble-decode/keymap/registered "$1"; then
    ble-decode/keymap/push "$1" # 再実行
  else
    ble/util/print "[ble: keymap '$1' not found]" >&2
    return 1
  fi
}
## 関数 ble-decode/keymap/pop
function ble-decode/keymap/pop {
  local count=${#_ble_decode_keymap_stack[@]}
  local last=$((count-1))
  ble/util/assert '((last>=0))' || return
  _ble_decode_keymap=${_ble_decode_keymap_stack[last]}
  unset -v '_ble_decode_keymap_stack[last]'
}


## @var _ble_decode_key__seq
##   今迄に入力された未処理のキーの列を保持します
##   /(_\d+)*/ の形式の文字列です。
_ble_decode_key__seq=

## @var _ble_decode_key__hook
##   キー処理に対する hook を外部から設定する為の変数です。
_ble_decode_key__hook=

## 関数 ble-decode-key/is-intermediate
##   未処理のキーがあるかどうかを判定します。
function ble-decode-key/is-intermediate { [[ $_ble_decode_key__seq ]]; }

## @arr _ble_decode_key_batch
_ble_decode_key_batch=()

function ble-decode-key/batch/flush {
  ((${#_ble_decode_key_batch[@]})) || return
  eval "local command=\${${dicthead}[_ble_decode_KCODE_BATCH_CHAR]-}"
  command=${command:2}
  if [[ $command ]]; then
    local chars; chars=("${_ble_decode_key_batch[@]}")
    _ble_decode_key_batch=()
    ble/decode/widget/call-interactively "$command" "${chars[@]}"; local ext=$?
    ((ext!=125)) && return
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


## 関数 ble-decode-key key
##   キー入力の処理を行います。登録されたキーシーケンスに一致した場合、
##   関連付けられたコマンドを実行します。
##   登録されたキーシーケンスの前方部分に一致する場合、即座に処理は行わず
##   入力されたキーの列を _ble_decode_key__seq に記録します。
##
##   @var[in] key
##     入力されたキー
##
function ble-decode-key {
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

    local dicthead=_ble_decode_${_ble_decode_keymap}_kmap_

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
          local -a keys=(${_ble_decode_key__seq//_/ } $key)
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

## 関数 ble-decode-key/.invoke-partial-match fail
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
      if ble/decode/has-input && eval "[[ \${${dicthead}[_ble_decode_KCODE_BATCH_CHAR]-} ]]"; then
        ble/array#push _ble_decode_key_batch "$key"
        return 0
      fi

      builtin eval "local command=\${${dicthead}[_ble_decode_KCODE_DEFCHAR]-}"
      command=${command:2}
      if [[ $command ]]; then
        local seq_save=$_ble_decode_key__seq
        ble-decode/widget/.call-keyseq; local ext=$?
        ((ext!=125)) && return
        _ble_decode_key__seq=$seq_save # 125 の時はまた元に戻して次の試行を行う
      fi
    fi

    # 既定のキーハンドラ
    builtin eval "local command=\${${dicthead}[_ble_decode_KCODE_DEFAULT]-}"
    command=${command:2}
    ble-decode/widget/.call-keyseq; local ext=$?
    ((ext!=125)) && return

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
  [[ $hook ]] && builtin eval -- "$hook"
}

## 関数 ble-decode/widget/.call-keyseq
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

  # setup variables
  local WIDGET=$command KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS=(${_ble_decode_key__seq//_/ } $key)
  _ble_decode_widget_last=$WIDGET
  _ble_decode_key__seq=

  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_BEFORE_WIDGET"
  builtin eval -- "$WIDGET"; local ext=$?
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_AFTER_WIDGET"
  ((_ble_decode_keylog_depth==1)) &&
    _ble_decode_keylog_chars_count=0 _ble_decode_keylog_keys_count=0
  return "$ext"
}
## 関数 ble-decode/widget/.call-async-read
##   _ble_decode_{char,key}__hook の呼び出しに使用します。
##   _ble_decode_widget_last は更新しません。
function ble-decode/widget/.call-async-read {
  # for keylog suppress
  local _ble_decode_keylog_depth=$((_ble_decode_keylog_depth+1))

  # setup variables
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS=($2)
  builtin eval -- "$WIDGET"; local ext=$?
  ((_ble_decode_keylog_depth==1)) &&
    _ble_decode_keylog_chars_count=0 _ble_decode_keylog_keys_count=0
  return "$ext"
}
## 関数 ble/decode/widget/call-interactively widget keys...
## 関数 ble/decode/widget/call widget keys...
##   指定した名前の widget を呼び出します。
##   call-interactively では、現在の keymap に応じた __before_widget__
##   及び __after_widget__ フックも呼び出します。
function ble/decode/widget/call-interactively {
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; KEYS=("${@:2}")
  _ble_decode_widget_last=$WIDGET
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_BEFORE_WIDGET"
  builtin eval -- "$WIDGET"; local ext=$?
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_AFTER_WIDGET"
  return "$ext"
}
function ble/decode/widget/call {
  local WIDGET=$1 KEYMAP=$_ble_decode_keymap LASTWIDGET=$_ble_decode_widget_last
  local -a KEYS; KEYS=("${@:2}")
  _ble_decode_widget_last=$WIDGET
  builtin eval -- "$WIDGET"
}
## 関数 ble/decode/widget/suppress-widget
##   __before_widget__ に登録された関数から呼び出します。
##   __before_widget__ 内で必要な処理を完了した時に、
##   WIDGET の呼び出しをキャンセルします。
##   __after_widget__ の呼び出しはキャンセルされません。
function ble/decode/widget/suppress-widget {
  WIDGET=
}

## 関数 ble/decode/widget/redispatch
##   @var[in] KEYS
##   @var[out] _ble_decode_keylog_depth
function ble/decode/widget/redispatch {
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
function ble/decode/widget/skip-lastwidget {
  _ble_decode_widget_last=$LASTWIDGET
}

#------------------------------------------------------------------------------
# ble/decode/has-input

## 関数 ble/decode/has-input
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
    ble/util/is-stdin-ready ||
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

## 関数 ble/decode/wait-input timeout
function ble/decode/wait-input {
  local timeout=$1
  while ((timeout>0)); do
    ble/decode/has-input && return 0
    local w=$((timeout<20?timeout:20))
    ble/util/msleep "$w"
    ((timeout-=w))
  done
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
    ble/util/print '===== bytes ====='
    printf '%s\n' "${_ble_debug_keylog_bytes[*]}"
    ble/util/print
    ble/util/print '===== chars ====='
    local ret; ble-decode-unkbd "${_ble_debug_keylog_chars[@]}"
    ble/string#split ret ' ' "$ret"
    printf '%s\n' "${ret[*]}"
    ble/util/print
    ble/util/print '===== keys ====='
    local ret; ble-decode-unkbd "${_ble_debug_keylog_keys[@]}"
    ble/string#split ret ' ' "$ret"
    printf '%s\n' "${ret[*]}"
    ble/util/print
  } | fold -w 40

  _ble_debug_keylog_enabled=0
  _ble_debug_keylog_bytes=()
  _ble_debug_keylog_chars=()
  _ble_debug_keylog_keys=()
}
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

## 関数 ble/decode/keylog#start [tag]
function ble/decode/keylog#start {
  [[ $_ble_decode_keylog_keys_enabled ]] && return 1
  _ble_decode_keylog_keys_enabled=${1:-1}
  _ble_decode_keylog_keys=()
}
## 関数 ble/decode/keylog#end
##   @var[out] ret
function ble/decode/keylog#end {
  ret=("${_ble_decode_keylog_keys[@]}")
  _ble_decode_keylog_keys_enabled=
  _ble_decode_keylog_keys=()
}
## 関数 ble/decode/keylog#pop
##   現在の WIDGET 呼び出しに対応する KEYS が記録されているとき、これを削除します。
##   @var[in] _ble_decode_keylog_depth
##   @var[in] _ble_decode_keylog_keys_enabled
##   @arr[in] KEYS
function ble/decode/keylog#pop {
  [[ $_ble_decode_keylog_keys_enabled && $_ble_decode_keylog_depth == 1 ]] || return
  local new_size=$((${#_ble_decode_keylog_keys[@]}-_ble_decode_keylog_keys_count))
  ((new_size<0)) && new_size=0
  _ble_decode_keylog_keys=("${_ble_decode_keylog_keys[@]::new_size}")
  _ble_decode_keylog_keys_count=0
}

## 関数 ble/decode/charlog#start [tag]
function ble/decode/charlog#start {
  [[ $_ble_decode_keylog_chars_enabled ]] && return 1
  _ble_decode_keylog_chars_enabled=${1:-1}
  _ble_decode_keylog_chars=()
}
## 関数 ble/decode/charlog#end
##   @var[out] ret
function ble/decode/charlog#end {
  [[ $_ble_decode_keylog_chars_enabled ]] || { ret=(); return 1; }
  ret=("${_ble_decode_keylog_chars[@]}")
  _ble_decode_keylog_chars_enabled=
  _ble_decode_keylog_chars=()
}
## 関数 ble/decode/charlog#end-exclusive
##   現在の WIDGET 呼び出しに対応する文字を除いて記録を取得して完了します。
##   @var[out] ret
function ble/decode/charlog#end-exclusive {
  ret=()
  [[ $_ble_decode_keylog_chars_enabled ]] || return
  local size=$((${#_ble_decode_keylog_chars[@]}-_ble_decode_keylog_chars_count))
  ((size>0)) && ret=("${_ble_decode_keylog_chars[@]::size}")
  _ble_decode_keylog_chars_enabled=
  _ble_decode_keylog_chars=()
}
## 関数 ble/decode/charlog#end-exclusive-depth1
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

## 関数 ble/decode/charlog#encode chars...
function ble/decode/charlog#encode {
  local -a buff=()
  for char; do
    ((char==0)) && char=$_ble_decode_EscapedNUL
    ble/util/c2s "$char"
    ble/array#push buff "$ret"
  done
  IFS= eval 'ret="${buff[*]}"'
}
## 関数 ble/decode/charlog#decode text
function ble/decode/charlog#decode {
  local text=$1 n=${#1} i chars
  chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "$text" "$i"
    ((ret==_ble_decode_EscapedNUL)) && ret=0
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}

## 関数 ble/decode/keylog#encode keys...
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
        ble/util/c2s $((c&0x1F))
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
  IFS= eval 'ret="${buff[*]-}"'
}
## 関数 ble/decode/keylog#decode-chars text
function ble/decode/keylog#decode-chars {
  local text=$1 n=${#1} i
  local -a chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "$text" "$i"
    ((ret==27)) && ret=$_ble_decode_IsolatedESC
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}

## 関数 ble/widget/.MACRO char...
##   bind '"keyseq":"macro"' の束縛に使用する。
function ble/widget/.MACRO {
  local -a chars=()
  local char
  for char; do
    ble/array#push chars $((char|_ble_decode_Macr))
  done
  ble-decode-char "${chars[@]}"
}

## 関数 ble/widget/.CHARS char...
##   lib/init-bind.sh で特別なバイト列を受信するのに使う関数
function ble/widget/.CHARS {
  ble-decode-char "$@"
}

#------------------------------------------------------------------------------
# key definitions (c.f. init-cmap.sh)                              @decode.cmap

## 関数 ble/decode/c2dqs code
##   bash builtin bind で用いる事のできるキー表記に変換します。
##   @var[out] ret
function ble/decode/c2dqs {
  local i=$1

  # bind で用いる
  # リテラル "～" 内で特別な表記にする必要がある物
  if ((0<=i&&i<32)); then
    # C0 characters
    if ((1<=i&&i<=26)); then
      ble/util/c2s $((i+96))
      ret="\\C-$ret"
    elif ((i==27)); then
      ret="\\e"
    elif ((i==28)); then
      # Workaround \C-\\, \C-\ in Bash-3.0..5.0
      ret="\\x1c"
    else
      ble/decode/c2dqs $((i+64))
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

## 関数 binder; ble/decode/cmap/.generate-binder-template
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
    qseq1=$qseq$ret
    nseq1="$nseq $ccode"

    builtin eval "local ent=\${_ble_decode_cmap_$tseq[ccode]}"
    if [[ ${ent%_} ]]; then
      if ((depth>=3)); then
        ble/util/print "\$binder \"$qseq1\" \"${nseq1# }\""
      fi
    fi

    if [[ ${ent//[0-9]} == _ ]]; then
      ble/decode/cmap/.generate-binder-template "${tseq}_$ccode" "$qseq1" "$nseq1" $((depth+1))
    fi
  done
}

function ble/decode/cmap/.emit-bindx {
  local ap="'" eap="'\\''"
  ble/util/print "builtin bind -x '\"${1//$ap/$eap}\":ble-decode/.hook $2; builtin eval \"\$_ble_decode_bind_hook\"'"
}
function ble/decode/cmap/.emit-bindr {
  ble/util/print "builtin bind -r \"$1\""
}

_ble_decode_cmap_initialized=
function ble/decode/cmap/initialize {
  [[ $_ble_decode_cmap_initialized ]] && return
  _ble_decode_cmap_initialized=1

  local init=$_ble_base/lib/init-cmap.sh
  local dump=$_ble_base_cache/cmap+default.$_ble_decode_kbd_ver.$TERM.dump
  if [[ $dump -nt $init ]]; then
    source "$dump"
  else
    ble-edit/info/immediate-show text 'ble.sh: generating "'"$dump"'"...'
    source "$init"
    ble-bind -D | ble/bin/sed '
      s/^declare \{1,\}\(-[aAfFgilrtux]\{1,\} \{1,\}\)\{0,1\}//
      s/^-- //
      s/["'"'"']//g
    ' >| "$dump"
  fi

  if ((_ble_bash>=40300)); then
    # 3文字以上 bind/unbind ソースの生成 (init-bind.sh bindAllSeq で使用)
    local fbinder=$_ble_base_cache/cmap+default.binder-source
    _ble_decode_bind_fbinder=$fbinder
    if ! [[ $_ble_decode_bind_fbinder -nt $init ]]; then
      ble-edit/info/immediate-show text  'ble.sh: initializing multichar sequence binders... '
      ble/decode/cmap/.generate-binder-template >| "$fbinder"
      binder=ble/decode/cmap/.emit-bindx source "$fbinder" >| "$fbinder.bind"
      binder=ble/decode/cmap/.emit-bindr source "$fbinder" >| "$fbinder.unbind"
      ble-edit/info/immediate-show text  'ble.sh: initializing multichar sequence binders... done'
    fi
  fi
}

function ble/decode/cmap/decode-chars.hook {
  ble/array#push ble_decode_bind_keys "$1"
  _ble_decode_key__hook=ble/decode/cmap/decode-chars.hook
}
## 関数 ble/decode/cmap/decode-chars chars...
##   文字コードの列からキーの列へ変換します。
##   @arr[out] keys
function ble/decode/cmap/decode-chars {
  ble/decode/cmap/initialize

  # initialize
  local _ble_decode_csi_mode=0
  local _ble_decode_csi_args=
  local _ble_decode_char2_seq=
  local _ble_decode_char2_reach=
  local _ble_decode_char2_modifier=
  local _ble_decode_char2_modkcode=

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

  # setup hook and run
  local -a ble_decode_bind_keys=()
  local _ble_decode_key__hook=ble/decode/cmap/decode-chars.hook
  local ble_decode_char_sync=1 # ユーザ入力があっても中断しない
  ble-decode-char "$@"

  keys=("${ble_decode_bind_keys[@]}")
}

#------------------------------------------------------------------------------
# **** binder for bash input ****                                  @decode.bind

_ble_decode_bind_hook=

# **** ^U ^V ^W ^? 対策 ****                                   @decode.bind.uvw

# ref #D0003, #D1092
_ble_decode_bind__uvwflag=
function ble/decode/bind/adjust-uvw {
  [[ $_ble_decode_bind__uvwflag ]] && return
  _ble_decode_bind__uvwflag=1

  # 何故か stty 設定直後には bind できない物たち
  # Note: bind 'set bind-tty-special-chars on' の時に以下が必要である (#D1092)
  builtin bind -x '"":ble-decode/.hook 21; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 22; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 23; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 127; builtin eval "$_ble_decode_bind_hook"'
}

# **** POSIXLY_CORRECT workaround ****

# ble.pp の関数を上書き
#
# Note: bash で set -o vi の時、
#   unset -v POSIXLY_CORRECT や local POSIXLY_CORRECT が設定されると、
#   C-i の既定の動作の切り替えに伴って C-i の束縛が消滅する。
#   ユーザが POSIXLY_CORRECT を触った時や自分で触った時に、
#   改めて束縛し直す必要がある。
#
function ble/base/workaround-POSIXLY_CORRECT {
  [[ $_ble_decode_bind_state == none ]] && return
  builtin bind -x '"\C-i":ble-decode/.hook 9; builtin eval "$_ble_decode_bind_hook"'
}

# **** ble-decode-bind ****                                   @decode.bind.main

## 関数 ble/decode/bind/.generate-source-to-unbind-default
##   既存の ESC で始まる binding を削除するコードを生成し標準出力に出力します。
##   更に、既存の binding を復元する為のコードを同時に生成し tmp/$$.bind.save に保存します。
function ble/decode/bind/.generate-source-to-unbind-default {
  # 1 ESC で始まる既存の binding を全て削除
  # 2 bind を全て記録 at $$.bind.save
  {
    if ((_ble_bash>=40300)); then
      ble/util/print '__BINDX__'
      builtin bind -X
    fi
    ble/util/print '__BINDP__'
    builtin bind -sp
  } | LC_ALL=C ble/decode/bind/.generate-source-to-unbind-default/.process

  # Note: 2>/dev/null は、(1) bind -X のエラーメッセージ、及び、
  # (2) LC_ALL 復元時のエラーメッセージ (外側の値が不正な時) を捨てる為に必要。
} 2>/dev/null
function ble/decode/bind/.generate-source-to-unbind-default/.process {
  local q=\' b=\\ Q="'\''"
  # Note: Solaris xpg4 awk では gsub の置換後のエスケープシーケンスも処理される
  [[ $_ble_bin_awk_solaris_xpg4 == yes ]] && Q="'$b$b''"
  local QUOT_Q=\"${Q//"$b"/$b$b}\"
  ble/bin/awk -v q="$q" '
    BEGIN {
      Q = '"$QUOT_Q"';
      mode = 1;
    }

    function quote(text) {
      gsub(q, Q, text);
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
      gsub(/\\\\/, "\\", str);
      return str;
    }

    function output_bindr(line0, _seq) {
      if (match(line0, /^"(([^"\\]|\\.)+)"/) > 0) {
        _seq = substr(line0, 2, RLENGTH - 2);

        #%# ※bash-3.1 では bind -sp で \e ではなく \M- と表示されるが、
        #%#   bind -r では \M- ではなく \e と指定しなければ削除できない。
        gsub(/\\M-/, "\\e", _seq);

        print "builtin bind -r " quote(_seq);
      }
    }

    /^__BINDP__$/ { mode = 1; next; }
    /^__BINDX__$/ { mode = 2; next; }

    mode == 1 && $0 ~ /^"/ {
      # Workaround Bash-5.0 bug (cf #D1078)
      sub(/^"\\C-\\\\\\"/, "\"\\x1c\\x5c\"");
      sub(/^"\\C-\\\\?"/, "\"\\x1c\"");

      output_bindr($0);

      print "builtin bind " quote($0) > "/dev/stderr";
    }

    mode == 2 && $0 ~ /^"/ {
      output_bindr($0);

      line = $0;

      #%# ※bash-4.3..5.0 では bind -r しても bind -X に残る。
      #%#   再登録を防ぐ為 ble-decode-bind を明示的に避ける
      if (line ~ /(^|[^[:alnum:]])ble-decode\/.hook($|[^[:alnum:]])/) next;

      #%# ※bind -X で得られた物は直接 bind -x に用いる事はできない。
      #%#   コマンド部分の "" を外して中の escape を外す必要がある。
      #%#   escape には以下の種類がある: \C-a など \C-? \e \\ \"
      #%#     \n\r\f\t\v\b\a 等は使われない様だ。
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
_ble_decode_bind_encoding=

function ble/decode/bind/bind {
  _ble_decode_bind_encoding=$bleopt_input_encoding
  local file=$_ble_base_cache/ble-decode-bind.$_ble_bash.$_ble_decode_bind_encoding.bind
  [[ $file -nt $_ble_base/lib/init-bind.sh ]] || source "$_ble_base/lib/init-bind.sh"

  # * 一時的に 'set convert-meta off' にする。
  #
  #   bash-3.0 - 5.0a 全てにおいて 'set convert-meta on' の時、
  #   128-255 を bind しようとすると 0-127 を bind してしまう。
  #   32 bit 環境で LC_CTYPE=C で起動すると 'set convert-meta on' になる様だ。
  #
  #   一応、以下の関数は ble/term/initialize で呼び出しているので、
  #   ble/decode/bind/bind の呼び出しが ble/term/initialize より後なら大丈夫の筈だが、
  #   念の為にここでも呼び出しておく事にする。
  #
  ble/term/rl-convert-meta/enter

  source "$file"
  _ble_decode_bind__uvwflag=
}
function ble/decode/bind/unbind {
  ble/function#try ble/encoding:"$bleopt_input_encoding"/clear
  source "$_ble_base_cache/ble-decode-bind.$_ble_bash.$_ble_decode_bind_encoding.unbind"
}
function ble/decode/rebind {
  [[ $_ble_decode_bind_state == none ]] && return
  ble/decode/bind/unbind
  ble/decode/bind/bind
}

#------------------------------------------------------------------------------
# ble-bind                                                      @decode.blebind

function ble-bind/.initialize-kmap {
  [[ $kmap ]] && return
  ble-decode/GET_BASEMAP -v kmap
  if ! ble-decode/keymap/is-keymap "$kmap"; then
    ble/util/print "ble-bind: the default keymap '$kmap' is unknown." >&2
    return 1
  fi
  return 0
}

function ble-bind/option:help {
  ble/util/cat <<EOF
ble-bind --help
ble-bind -k cspecs [kspec]
ble-bind --csi PsFt kspec
ble-bind [-m keymap] -fxc@s kspecs command
ble-bind [-m keymap] -T kspecs timeout
ble-bind [-m keymap]... (-PD|--print|--dump)
ble-bind (-L|--list-widgets)

EOF
}

function ble-bind/check-argunment {
  if (($3<$2)); then
    if (($2==1)); then
      ble/util/print "ble-bind: the option \`$1' requires an argument." >&2
    else
      ble/util/print "ble-bind: the option \`$1' requires $2 arguments." >&2
    fi
    return 2
  fi
}
#
#
function ble-bind/option:csi {
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

    # "CSI <num> $" は CSI sequence の形式に沿っていないので、
    # 個別に登録する必要がある。
    local -a cseq
    cseq=(27 91)
    local ret i iN num="${BASH_REMATCH[1]}\$"
    for ((i=0,iN=${#num};i<iN;i++)); do
      ble/util/s2c "$num" "$i"
      ble/array#push cseq "$ret"
    done
    if [[ $key ]]; then
      ble-decode-char/bind "${cseq[*]}" $((key|_ble_decode_Shft))
    else
      ble-decode-char/unbind "${cseq[*]}"
    fi
  elif [[ $1 == [a-zA-Z] ]]; then
    # --csi '<Ft>' kname
    local ret; ble/util/s2c "$1"
    _ble_decode_csimap_alpha[ret]=$key
  else
    ble/util/print "ble-bind --csi: not supported type of csi sequences: CSI \`$1'." >&2
    return 1
  fi
}

function ble-bind/option:list-widgets {
  declare -f | ble/bin/sed -n -r 's/^ble\/widget\/([[:alpha:]][^.[:space:]();&|]+)[[:space:]]*\(\)[[:space:]]*$/\1/p'
}
function ble-bind/option:dump {
  if (($#)); then
    local keymap
    for keymap; do
      ble-decode/keymap/dump "$keymap"
    done
  else
    ble/util/declare-print-definitions "${!_ble_decode_kbd__@}" "${!_ble_decode_cmap_@}" "${!_ble_decode_csimap_@}"
    ble-decode/keymap/dump
  fi
}
function ble-bind/option:print {
  local keymap
  ble-decode/INITIALIZE_DEFMAP -v keymap # 初期化を強制する
  if (($#)); then
    for keymap; do
      ble-decode-key/dump "$keymap"
    done
  else
    ble-decode-char/csi/print
    ble-decode-char/dump
    ble-decode-key/dump
  fi
}

function ble-bind {
  local kmap=$ble_bind_keymap ret
  local -a keymaps; keymaps=()
  ble/decode/initialize

  local arg c
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == --?* ]]; then
      case "${arg:2}" in
      (help)
        ble-bind/option:help ;;
      (csi)
        ble-bind/check-argunment --csi 2 "$#" || return
        ble-bind/option:csi "$1" "$2"
        shift 2 ;;
      (list-widgets|list-functions)
        ble-bind/option:list-widgets ;;
      (dump) ble-bind/option:dump "${keymaps[@]}" ;;
      (print) ble-bind/option:print "${keymaps[@]}" ;;
      (*)
        ble/util/print "ble-bind: unrecognized long option $arg" >&2
        return 2 ;;
      esac
    elif [[ $arg == -?* ]]; then
      arg=${arg:1}
      while ((${#arg})); do
        c=${arg::1} arg=${arg:1}
        case $c in
        (k)
          if (($#<2)); then
            ble/util/print "ble-bind: the option \`-k' requires two arguments." >&2
            return 2
          fi

          ble-decode-kbd "$1"; local cseq=$ret
          if [[ $2 && $2 != - ]]; then
            ble-decode-kbd "$2"; local kc=$ret
            ble-decode-char/bind "$cseq" "$kc"
          else
            ble-decode-char/unbind "$cseq"
          fi
          shift 2 ;;
        (m)
          if (($#<1)); then
            ble/util/print "ble-bind: the option \`-m' requires an argument." >&2
            return 2
          elif ! ble-decode/keymap/is-keymap "$1"; then
            ble/util/print "ble-bind: the keymap '$kmap' is unknown." >&2
            return 1
          fi
          kmap=$1
          ble/array#push keymaps "$1"
          shift ;;
        (D) ble-bind/option:dump "${keymaps[@]}" ;;
        ([Pd]) ble-bind/option:print "${keymaps[@]}" ;;
        (['fxc@s'])
          # 旧形式の指定 -xf や -cf に対応する処理
          [[ $c != f && $arg == f* ]] && arg=${arg:1}

          if (($#<2)); then
            ble/util/print "ble-bind: the option \`-$c' requires two arguments." >&2
            return 2
          fi

          ble-decode-kbd "$1"; local kbd=$ret
          if [[ $2 && $2 != - ]]; then
            local command=$2

            # コマンドの種類
            case $c in
            (f)
              # ble/widget/ 関数
              command=ble/widget/$command ;;
            (x) # 編集用の関数
              local q=\' Q="''\'"
              command="ble/widget/.EDIT_COMMAND '${command//$q/$Q}'" ;;
            (c) # コマンド実行
              local q=\' Q="''\'"
              command="ble/widget/.SHELL_COMMAND '${command//$q/$Q}'" ;;
            (s)
              local ret; ble/util/keyseq2chars "$command"
              command="ble/widget/.MACRO ${ret[*]}" ;;
            ('@') ;; # 直接実行
            (*)
              ble/util/print "error: unsupported binding type \`-$c'." 1>&2
              return 1 ;;
            esac

            ble-bind/.initialize-kmap || return 1 # -> kmap
            ble-decode-key/bind "$kmap" "$kbd" "$command"
          else
            ble-bind/.initialize-kmap || return 1 # -> kmap
            ble-decode-key/unbind "$kmap" "$kbd"
          fi
          shift 2 ;;
        (T)
          ble-decode-kbd "$1"; local kbd=$ret
          if (($#<2)); then
            ble/util/print "ble-bind: the option \`-T' requires two arguments." >&2
            return 2
          fi

          ble-bind/.initialize-kmap || return 1 # -> kmap
          ble-decode-key/set-timeout "$kmap" "$kbd" "$2"
          shift 2 ;;
        (L)
          ble-bind/option:list-widgets ;;
        (*)
          ble/util/print "ble-bind: unrecognized short option \`-$c'." >&2
          return 2 ;;
        esac
      done
    else
      ble/util/print "ble-bind: unrecognized argument \`$arg'." >&2
      return 2
    fi
  done

  return 0
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
    return ;;

  (mode)
    if [[ -o emacs ]]; then
      test emacs "$op" "$rhs"
    elif [[ -o vi ]]; then
      test vi "$op" "$rhs"
    else
      false
    fi
    return ;;

  (term)
    if [[ $op == '!=' ]]; then
      test "$TERM" "$op" "$rhs" && test "${TERM%%-*}" "$op" "$rhs"
    else
      test "$TERM" "$op" "$rhs" || test "${TERM%%-*}" "$op" "$rhs"
    fi
    return ;;
  
  (version)
    local lhs_major lhs_minor
    if ((_ble_bash<40400)); then
      ((lhs_major=2+_ble_bash/10000,
        lhs_minor=_ble_bash/100%100))
    else
      ((lhs_major=3+_ble_bash/10000,
        lhs_minor=0))
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
    return ;;

  (*)
    if local ret; ble/util/read-rl-variable "$lhs"; then
      test "$ret" "$op" "$rhs"
      return
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
  while builtin read -r line || [[ $line ]]; do
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

  IFS=$'\n' eval 'script="${script[*]}"'
  builtin eval "$script"
}

#------------------------------------------------------------------------------
# ble/builtin/bind                                                @builtin.bind

_ble_builtin_bind_keymap=
function ble/builtin/bind/set-keymap {
  local opt_keymap= flags=
  ble/builtin/bind/option:m "$1" &&
    _ble_builtin_bind_keymap=$opt_keymap
}

## 関数 ble/builtin/bind/option:m keymap
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
## 関数 ble/builtin/bind/.decompose-pair spec
##   keyseq:command の形式の文字列を keyseq と command に分離します。
##   @var[out] keyseq value
function ble/builtin/bind/.decompose-pair {
  local ret; ble/string#trim "$1"
  local spec=$ret ifs=$' \t\n' q=\' Q="'\''"
  keyseq= value=

  # bind '' と指定した時は無視する
  [[ ! $spec || $spec == 'set'["$ifs"]* ]] && return 3

  # split keyseq / value
  local rex='^(("([^\"]|\\.)*"|[^":'$ifs'])*("([^\"]|\\.)*)?)['$ifs']*(:['$ifs']*)?'
  [[ $spec =~ $rex ]]
  keyseq=${BASH_REMATCH[1]} value=${spec:${#BASH_REMATCH}}

  # check values
  if [[ $keyseq == '$'* ]]; then
    # Parser directives such as $if, $else, $endif, $include
    return 3
  elif [[ ! $keyseq ]]; then
    ble/util/print "ble.sh (bind): empty keyseq in spec:'${spec//$q/$Q}'" >&2
    flags=e$flags
    return 1
  elif rex='^"([^\"]|\\.)*$'; [[ $keyseq =~ $rex ]]; then
    ble/util/print "ble.sh (bind): no closing '\"' in keyseq:'${keyseq//$q/$Q}'" >&2
    flags=e$flags
    return 1
  elif rex='^"([^\"]|\\.)*"'; [[ $keyseq =~ $rex ]]; then
    local rematch=${BASH_REMATCH[0]}
    if ((${#rematch}<${#keyseq})); then
      local fragment=${keyseq:${#rematch}}
      ble/util/print "ble.sh (bind): warning: unprocessed fragments in keyseq '${fragment//$q/$Q}'" >&2
    fi
    keyseq=$rematch
    return 0
  else
    return 0
  fi
}
## 関数 ble/builtin/bind/.parse-keyname keyname
##   @var[out] chars
function ble/builtin/bind/.parse-keyname {
  local value=$1
  local ret rex='^(control-|c-|ctrl-|meta|m-)-*' mflags=
  while ble/string#tolower "$value"; [[ $ret =~ $rex ]]; do
    value=${value:${#BASH_REMATCH}}
    mflags=${BASH_REMATCH::1}$mflags
  done

  local ch=
  case $ret in
  (rubout|del) ch=$'\177' ;;
  (escape|esc) ch=$'\033' ;;
  (newline|lfd) ch=$'\n' ;;
  (return|ret) ch=$'\r' ;;
  (space|spc) ch=' ' ;;
  (tab) ch=$'\t' ;;
  (*) LC_ALL= LC_CTYPE=C eval 'ch=${value::1}' 2>/dev/null ;;
  esac
  ble/util/s2c "$ch"; local key=$ret

  [[ $mflags == *c* ]] && ((key&=0x1F))
  [[ $mflags == *m* ]] && ((key|=0x80))
  chars=("$key")
}

## 関数 ble/builtin/bind/.initialize-kmap keymap
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

  if ! ble-decode/keymap/is-keymap "$kmap"; then
    ble/util/print "ble/builtin/bind: the keymap '$kmap' is unknown." >&2
    return 1
  fi

  return 0
}
## 関数 ble/builtin/bind/.initialize-keys-and-value
##   @var[out] keys value
function ble/builtin/bind/.initialize-keys-and-value {
  local spec=$1 opts=$2
  keys= value=

  local keyseq
  ble/builtin/bind/.decompose-pair "$spec" || return

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

## 関数 ble/builtin/bind/option:x spec
##   @var[in] opt_keymap
function ble/builtin/bind/option:x {
  local q=\' Q="''\'"
  local keys value kmap
  if ! ble/builtin/bind/.initialize-keys-and-value "$1" nokeyname; then
    ble/util/print "ble.sh (bind): unrecognized readline command '${1//$q/$Q}'." >&2
    flags=e$flags
    return 1
  elif ! ble/builtin/bind/.initialize-kmap "$opt_keymap"; then
    ble/util/print "ble.sh (bind): sorry, failed to initialize keymap:'$opt_keymap'." >&2
    flags=e$flags
    return 1
  fi

  if [[ $value == \"* ]]; then
    local ifs=$' \t\n'
    local rex='^"(([^\"]|\\.)*)"'
    if ! [[ $value =~ $rex ]]; then
      ble/util/print "ble.sh (bind): no closing '\"' in spec:'${1//$q/$Q}'" >&2
      flags=e$flags
      return 1
    fi

    if ((${#BASH_REMATCH}<${#value})); then
      local fragment=${value:${#BASH_REMATCH}}
      ble/util/print "ble.sh (bind): warning: unprocessed fragments:'${fragment//$q/$Q}' in spec:'${1//$q/$Q}'" >&2
    fi

    value=${BASH_REMATCH[1]}
  fi

  [[ $value == \"*\" ]] && value=${value:1:${#value}-2}
  local command="ble/widget/.EDIT_COMMAND '${value//$q/$Q}'"
  ble-decode-key/bind "$kmap" "${keys[*]}" "$command"
}
## 関数 ble/builtin/bind/option:r keyseq
##   @var[in] opt_keymap
function ble/builtin/bind/option:r {
  local keyseq=$1

  local ret chars keys
  ble/util/keyseq2chars "$keyseq"; chars=("${ret[@]}")
  ble/decode/cmap/decode-chars "${chars[@]}"

  local kmap
  ble/builtin/bind/.initialize-kmap "$opt_keymap" || return
  ble-decode-key/unbind "$kmap" "${keys[*]}"
}

_ble_decode_rlfunc2widget_emacs=()
_ble_decode_rlfunc2widget_vi_imap=()
_ble_decode_rlfunc2widget_vi_nmap=()
function ble/builtin/bind/rlfunc2widget {
  local kmap=$1 rlfunc=$2

  local rlfunc_file= rlfunc_dict=
  case $kmap in
  (emacs)   rlfunc_file=$_ble_base/keymap/emacs.rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_emacs ;;
  (vi_imap) rlfunc_file=$_ble_base/keymap/vi_imap.rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_vi_imap ;;
  (vi_nmap) rlfunc_file=$_ble_base/keymap/vi_nmap.rlfunc.txt
            rlfunc_dict=_ble_decode_rlfunc2widget_vi_nmap ;;
  esac

  if [[ $rlfunc_file ]]; then
    local dict script='
    ((${#RLFUNC_DICT[@]})) ||
      ble/util/mapfile RLFUNC_DICT < "$rlfunc_file"
    dict=("${RLFUNC_DICT[@]}")'
    builtin eval -- "${script//RLFUNC_DICT/$rlfunc_dict}"

    local line
    for line in "${dict[@]}"; do
      [[ $line == "$rlfunc "* ]] || continue
      local rl widget; builtin read -r rl widget <<< "$line"
      ret=ble/widget/$widget
      return 0
    done
  fi

  if ble/is-function ble/widget/"${rlfunc%%[$IFS]*}"; then
    ret=ble/widget/$rlfunc
    return 0
  fi

  return 1
}

## 関数 ble/builtin/bind/option:u function
##   @var[in] opt_keymap
function ble/builtin/bind/option:u {
  local rlfunc=$1

  local kmap
  if ! ble/builtin/bind/.initialize-kmap "$opt_keymap" || ! ble-decode/keymap/load "$kmap"; then
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
## 関数 ble/builtin/bind/option:-
##   @var[in] opt_keymap
function ble/builtin/bind/option:- {
  local ret; ble/string#trim "$1"; local arg=$ret

  local ifs=$' \t\n'
  if [[ $arg == 'set'["$ifs"]* ]]; then
    if [[ $_ble_decode_bind_state != none ]]; then
      local variable= value= rex=$'^set[ \t]+([^ \t]+)[ \t]+([^ \t].*)$'
      [[ $arg =~ $rex ]] && variable=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}

      case $variable in
      (keymap)
        ble/builtin/bind/set-keymap "$value"
        return ;;
      (editing-mode)
        _ble_builtin_bind_keymap= ;;
      esac

      builtin bind "$arg"
    fi
    return
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

  if [[ $value == \"* ]]; then
    # keyboard macro
    value=${value#\"} value=${value%\"}
    local ret chars; ble/util/keyseq2chars "$value"; chars=("${ret[@]}")
    local command="ble/widget/.MACRO ${chars[*]}"
    ble-decode-key/bind "$kmap" "${keys[*]}" "$command"
  elif [[ $value ]]; then
    if local ret; ble/builtin/bind/rlfunc2widget "$kmap" "$value"; then
      local command=$ret
      ble-decode-key/bind "$kmap" "${keys[*]}" "$command"
      return 0
    else
      ble/util/print "ble.sh (bind): unsupported readline function '${value//$q/$Q}'." >&2
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
        fi
        continue ;;
      (--*)
        ble/util/print "ble.sh (bind): unrecognized option $arg" >&2
        flags=e$flags
        continue ;;
      (-*)
        local i n=${#arg} c
        for ((i=1;i<n;i++)); do
          c=${arg:i:1}
          case $c in
          ([lpPsSvVX])
            opt_print=$opt_print$c ;;
          ([mqurfx])
            if ((!$#)); then
              ble/util/print "ble.sh (bind): missing option argument for -$c" >&2
              flags=e$flags
            else
              local optarg=$1; shift
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
              esac
            fi ;;
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
      ( ble/decode/bind/unbind
        [[ -s "$_ble_base_run/$$.bind.save" ]] &&
          source "$_ble_base_run/$$.bind.save"
        [[ $opt_print ]] &&
          builtin bind ${opt_keymap:+-m $opt_keymap} -$opt_print
        declare rlfunc
        for rlfunc in "${opt_queries[@]}"; do
          builtin bind ${opt_keymap:+-m $opt_keymap} -q "$rlfunc"
        done )
    elif [[ $opt_print ]]; then
      builtin bind ${opt_keymap:+-m $opt_keymap} -$opt_print
    fi
  fi

  return 0
}
# inputrc の読み込み
_ble_builtin_bind_inputrc_done=
function ble/builtin/bind/initialize-inputrc {
  [[ $_ble_builtin_bind_inputrc_done ]] && return
  _ble_builtin_bind_inputrc_done=1
  local inputrc=${INPUTRC:-$HOME/.inputrc}
  [[ -e $inputrc ]] && ble/decode/read-inputrc "$inputrc"
}

# user 設定の読み込み
_ble_builtin_bind_user_settings_loaded=
function ble/builtin/bind/.reconstruct-user-settings {
  local map q=\'
  for map in vi-insert vi-command emacs; do
    local cache=$_ble_base_cache/decode.readline.$_ble_bash.$map.txt
    if [[ ! -s $cache ]]; then
      "$BASH" --norc -i -c "bind -m $map -p" | ble/bin/sed '/^#/d;s/"\\M-/"\\e/' > $cache.part &&
        ble/bin/mv "$cache.part" "$cache" || continue
    fi
  
    echo __CLEAR__
    echo KEYMAP="$map"
    echo __BIND0__
    ble/bin/cat "$cache"
    if ((_ble_bash>=40300)); then
      echo __BINDX__
      builtin bind -m "$map" -X
    fi
    echo __BINDS__
    builtin bind -m "$map" -s
    echo __BINDP__
    builtin bind -m "$map" -p
    echo __PRINT__
  done | LC_ALL= LC_CTYPE=C awk -v q="$q" -v _ble_bash="$_ble_bash" '
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
  
    /ble-decode\/.hook / { next; }

    function workaround_bashbug(keyseq, _, rex, out, unit) {
      out = "";
      while (keyseq != "") {
        if (mode == 0 || mode == 3) {
          match(keyseq, /^\\C-\\(\\"$)?|^\\M-|^\\.|^./);
        } else {
          #%# bind -X, bind -s には問題はない
          match(keyseq, /^\\[CM]-|^\\.|^./);
        }
        unit = substr(keyseq, 1, RLENGTH);
        keyseq = substr(keyseq, 1 + RLENGTH);

        if (unit == "\\C-\\") {
          #%# Bash 3.0--5.0 Bug https://lists.gnu.org/archive/html/bug-bash/2020-01/msg00037.html
          unit = unit "\\";
        } else if (unit == "\\M-") {
          #%# Bash 3.1 以下では ESC は \M- と出力される
          unit = "\\e";
        }
        out = out unit;
      }
      return out;
    }
  
    match($0, /^"(\\.|[^"])+": /) {
      key = substr($0, 1, RLENGTH - 2);
      val = substr($0, 1 + RLENGTH);
      if (_ble_bash < 50100)
        key = workaround_bashbug(key);
      if (mode) {
        type = mode == 1 ? "x" : mode == 2 ? "s" : "";
        keymap_register(key, val, type);
      } else {
        keymap0[key] = val;
      }
    }
  ' 2>/dev/null # suppress LC_ALL error messages
}
function ble/builtin/bind/read-user-settings {
  if [[ $_ble_decode_bind_state == none ]]; then
    [[ $_ble_builtin_bind_user_settings_loaded ]] && return
    _ble_builtin_bind_user_settings_loaded=1
    bind # inputrc を読ませる
    local settings
    ble/util/assign settings ble/builtin/bind/.reconstruct-user-settings
    eval -- "$settings"
  fi
}

function ble/builtin/bind {
  ble/decode/initialize
  local flags=
  ble/builtin/bind/.process "$@"
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin bind "$@"
  else
    [[ $flags != *e* ]]
  fi
}
function bind { ble/builtin/bind "$@"; }

#------------------------------------------------------------------------------
# ble/decode/initialize, attach, detach                          @decode.attach

_ble_decode_initialized=
function ble/decode/initialize {
  [[ $_ble_decode_initialized ]] && return
  _ble_decode_initialized=1
  ble/decode/cmap/initialize
  ble/builtin/bind/read-user-settings
}

function ble/decode/reset-default-keymap {
  # 現在の ble-decode/keymap の設定
  ble-decode/INITIALIZE_DEFMAP -v _ble_decode_keymap # 0ms
  ble-decode/widget/.invoke-hook "$_ble_decode_KCODE_ATTACH" # 7ms for vi-mode
}

## 関数 ble/decode/attach
##   @var[in] _ble_decode_keymap
##     この関数を呼び出す前に ble/decode/reset-default-keymap を用いて
##     _ble_decode_keymap が使用可能な状態になっている必要がある。
function ble/decode/attach {
  # 失敗すると悲惨なことになるのでチェック
  if ble-decode/keymap/is-empty "$_ble_decode_keymap"; then
    ble/util/print "ble.sh: The keymap '$_ble_decode_keymap' is empty." >&2
    return 1
  fi

  [[ $_ble_decode_bind_state != none ]] && return
  ble/util/save-editing-mode _ble_decode_bind_state
  [[ $_ble_decode_bind_state == none ]] && return 1

  # bind/unbind 中に C-c で中断されると大変なので先に stty を設定する必要がある
  ble/term/initialize # 3ms

  # 既定の keymap に戻す
  ble/util/reset-keymap-of-editing-mode

  # 元のキー割り当ての保存・unbind
  builtin eval -- "$(ble/decode/bind/.generate-source-to-unbind-default)" # 21ms

  # ble.sh bind の設置
  ble/decode/bind/bind # 20ms

  # Note #D1213: linux コンソール (kernel 5.0.0) は "\e[>"
  #  でエスケープシーケンスを閉じてしまう。5.4.8 は大丈夫。
  [[ $TERM == linux ]] ||
    ble/util/buffer $'\e[>c' # DA2 要求 (ble-decode-char/csi/.decode で受信)
}

function ble/decode/detach {
  [[ $_ble_decode_bind_state != none ]] || return

  local current_editing_mode=
  ble/util/save-editing-mode current_editing_mode
  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode _ble_decode_bind_state

  ble/term/finalize

  # ble.sh bind の削除
  ble/decode/bind/unbind

  # 元のキー割り当ての復元
  if [[ -s "$_ble_base_run/$$.bind.save" ]]; then
    source "$_ble_base_run/$$.bind.save"
    : >| "$_ble_base_run/$$.bind.save"
  fi

  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode current_editing_mode

  _ble_decode_bind_state=none
}

#------------------------------------------------------------------------------
# **** encoding = UTF-8 ****

function ble/encoding:UTF-8/generate-binder { :; }

# 以下は lib/init-bind.sh の中にある物と等価なので殊更に設定しなくて良い。

# ## 関数 ble/encoding:UTF-8/generate-binder
# ##   lib/init-bind.sh の esc1B==3 の設定用。
# ##   lib/init-bind.sh の中から呼び出される。
# function ble/encoding:UTF-8/generate-binder {
#   ble/init:bind/bind-s '"\C-@":"\xC0\x80"'
#   ble/init:bind/bind-s '"\e":"\xDF\xBF"' # isolated ESC (U+07FF)
#   local i ret
#   for i in {0..255}; do
#     ble/decode/c2dqs "$i"
#     ble/init:bind/bind-s "\"\e$ret\": \"\xC0\x9B$ret\""
#   done
# }

_ble_decode_byte__utf_8__mode=0
_ble_decode_byte__utf_8__code=0
function ble/encoding:UTF-8/clear {
  _ble_decode_byte__utf_8__mode=0
  _ble_decode_byte__utf_8__code=0
}
function ble/encoding:UTF-8/is-intermediate {
  ((_ble_decode_byte__utf_8__mode))
}
function ble/encoding:UTF-8/decode {
  local code=$_ble_decode_byte__utf_8__code
  local mode=$_ble_decode_byte__utf_8__mode
  local byte=$1
  local cha0= char=
  ((
    byte&=0xFF,
    (mode!=0&&(byte&0xC0)!=0x80)&&(
      cha0=_ble_decode_Erro|code,mode=0
    ),
    byte<0xF0?(
      byte<0xC0?(
        byte<0x80?(
          char=byte
        ):(
          mode==0?(
            char=_ble_decode_Erro|byte
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
          char=_ble_decode_Erro|byte
        )
      )
    )
  ))

  _ble_decode_byte__utf_8__code=$code
  _ble_decode_byte__utf_8__mode=$mode

  local -a CHARS=($cha0 $char)
  ((${#CHARS[*]})) && ble-decode-char "${CHARS[@]}"
}

## 関数 ble/encoding:UTF-8/c2bc code
##   @param[in]  code
##   @var  [out] ret
function ble/encoding:UTF-8/c2bc {
  local code=$1
  ((ret=code<0x80?1:
    (code<0x800?2:
    (code<0x10000?3:
    (code<0x200000?4:5)))))
}

## 関数 ble/encoding:C/generate-binder
##   lib/init-bind.sh の esc1B==3 の設定用。
##   lib/init-bind.sh の中から呼び出される。
function ble/encoding:C/generate-binder {
  ble/init:bind/bind-s '"\C-@":"\x9B\x80"'
  ble/init:bind/bind-s '"\e":"\x9B\x8B"' # isolated ESC (U+07FF)
  local i ret
  for i in {0..255}; do
    ble/decode/c2dqs "$i"
    ble/init:bind/bind-s "\"\e$ret\": \"\x9B\x9B$ret\""
  done
}

## 関数 ble/encoding:C/decode byte
##
##   受け取ったバイトをそのまま文字コードと解釈する。
##   但し、bind の都合 (bashbug の回避) により以下の変換を行う。
##
##   \x9B\x80 (155 128) → C-@
##   \x9B\x8B (155 139) → isolated ESC \u07FF (2047)
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
  if [[ $_ble_encoding_c_csi ]]; then
    _ble_encoding_c_csi=
    case $1 in
    (155) ble-decode-char 27 # ESC
          return ;;
    (139) ble-decode-char 2047 # isolated ESC
          return ;;
    (128) ble-decode-char 0 # C-@
          return ;;
    esac
    ble-decode-char 155
  fi

  if (($1==155)); then
    _ble_encoding_c_csi=1
  else
    ble-decode-char "$1"
  fi
}

## 関数 ble/encoding:C/c2bc charcode
##   @var[out] ret
function ble/encoding:C/c2bc {
  ret=1
}
