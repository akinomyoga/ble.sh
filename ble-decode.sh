#! /bin/bash

: ${bleopt_decode_error_char_abell=}
: ${bleopt_decode_error_char_vbell=1}
: ${bleopt_decode_error_char_discard=}
: ${bleopt_decode_error_kseq_abell=1}
: ${bleopt_decode_error_kseq_vbell=1}
: ${bleopt_decode_error_kseq_discard=1}

## オプション decode_isolated_esc
##   bleopt decode_isolated_esc=meta
##     単体で受信した ESC を、前置詞として受信した ESC と同様に、
##     Meta 修飾または特殊キーのエスケープシーケンスとして扱います。
##   bleopt decode_isolated_esc=esc
##     単体で受信した ESC を、C-[ として扱います。
: ${bleopt_decode_isolated_esc:=auto}

function bleopt/check:decode_isolated_esc {
  case $value in
  (meta|esc|auto) ;;
  (*)
    echo "bleopt: Invalid value decode_isolated_esc='$value'. One of the values 'auto', 'meta' or 'esc' is expected." >&2
    return 1 ;;
  esac
}
function ble-decode/uses-isolated-esc {
  if [[ $bleopt_decode_isolated_esc == esc ]]; then
    return 0
  elif [[ $bleopt_decode_isolated_esc == auto && ! $_ble_decode_key__seq ]]; then
    local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_ key=$((ble_decode_Ctrl|91))
    builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[key]-}"
    [[ ${ent:2} ]] && return 0
  fi

  return 1
}

# **** key names ****

ble_decode_Erro=0x40000000
ble_decode_Meta=0x08000000
ble_decode_Ctrl=0x04000000
ble_decode_Shft=0x02000000
ble_decode_Hypr=0x01000000
ble_decode_Supr=0x00800000
ble_decode_Altr=0x00400000
ble_decode_MaskChar=0x001FFFFF
ble_decode_MaskFlag=0x7FC00000

ble_decode_IsolatedESC=$((0x07FF))

if ((_ble_bash>=40300||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  _ble_decode_kbd_ver=4
  _ble_decode_kbd__n=0
  builtin unset -v _ble_decode_kbd__k2c
  if ((_ble_bash>=40300)); then
    declare -gA _ble_decode_kbd__k2c
  else
    declare -A _ble_decode_kbd__k2c
   fi
  _ble_decode_kbd__c2k=()

  function ble-decode-kbd/.set-keycode {
    local key=$1
    local -i code=$2
    : ${_ble_decode_kbd__c2k[$code]:=$key}
    _ble_decode_kbd__k2c[$key]=$code
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
    local key=$1
    local -i code=$2
    : ${_ble_decode_kbd__c2k[$code]:=$key}
    _ble_decode_kbd__k2c_keys=$_ble_decode_kbd__k2c_keys:$key:
    _ble_decode_kbd__k2c_vals[${#_ble_decode_kbd__k2c_vals[@]}]=$code
  }
  function ble-decode-kbd/.get-keycode {
    local key=$1
    local tmp=${_ble_decode_kbd__k2c_keys%%:$key:*}
    if [[ ${#tmp} == ${#_ble_decode_kbd__k2c_keys} ]]; then
      ret=
    else
      local -a arr; arr=(${tmp//:/ })
      ret=${_ble_decode_kbd__k2c_vals[${#arr[@]}]}
    fi
  }
fi

ble_decode_function_key_base=0x110000

## 関数 ble-decode-kbd/.get-keyname keycode
##
##   keycode に対応するキーの名前を求めます。
##   対応するキーが存在しない場合には空文字列を返します。
##
##   @param[in] keycode keycode
##   @var[out]  ret     keyname
##
function ble-decode-kbd/.get-keyname {
  local -i keycode=$1
  ret=${_ble_decode_kbd__c2k[$keycode]}
  if [[ ! $ret ]] && ((keycode<ble_decode_function_key_base)); then
    ble/util/c2s "$keycode"
  fi
}
## 関数 ble-decode-kbd/.gen-keycode keyname
##   指定した名前に対応する keycode を取得します。
##   指定した名前の key が登録されていない場合は、
##   新しく kecode を割り当てて返します。
##   @param[in]  keyname keyname
##   @var  [out] ret     keycode
function ble-decode-kbd/.gen-keycode {
  local key=$1
  if ((${#key}==1)); then
    ble/util/s2c "$1"
  elif [[ $key && ! ${key//[a-zA-Z_0-9]} ]]; then
    ble-decode-kbd/.get-keycode "$key"
    if [[ ! $ret ]]; then
      ((ret=ble_decode_function_key_base+_ble_decode_kbd__n++))
      ble-decode-kbd/.set-keycode "$key" "$ret"
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

  local ret
  ble-decode-kbd/.gen-keycode __defchar__
  _ble_decode_KCODE_DEFCHAR=$ret
  ble-decode-kbd/.gen-keycode __default__
  _ble_decode_KCODE_DEFAULT=$ret
  ble-decode-kbd/.gen-keycode __before_command__
  _ble_decode_KCODE_BEFORE_COMMAND=$ret
  ble-decode-kbd/.gen-keycode __after_command__
  _ble_decode_KCODE_AFTER_COMMAND=$ret
  ble-decode-kbd/.gen-keycode __attach__
  _ble_decode_KCODE_ATTACH=$ret

  ble-decode-kbd/.gen-keycode shift
  _ble_decode_KCODE_SHIFT=$ret
  ble-decode-kbd/.gen-keycode alter
  _ble_decode_KCODE_ALTER=$ret
  ble-decode-kbd/.gen-keycode control
  _ble_decode_KCODE_CONTROL=$ret
  ble-decode-kbd/.gen-keycode meta
  _ble_decode_KCODE_META=$ret
  ble-decode-kbd/.gen-keycode super
  _ble_decode_KCODE_SUPER=$ret
  ble-decode-kbd/.gen-keycode hyper
  _ble_decode_KCODE_HYPER=$ret
}

ble-decode-kbd/.initialize

## 関数 ble-decode-kbd
##   @var[out] ret
function ble-decode-kbd {
  local keys; ble/string#split-words keys "$*"
  local IFS=$_ble_term_IFS
  local key code codes keys
  codes=()
  for key in "${keys[@]}"; do
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
      key=${key:2}
    done

    if [[ $key == ? ]]; then
      ble/util/s2c "$key" 0
      ((code|=ret))
    elif [[ $key && ! ${key//[_0-9a-zA-Z]/} ]]; then
      ble-decode-kbd/.get-keycode "$key"
      [[ $ret ]] || ble-decode-kbd/.gen-keycode "$key"
      ((code|=ret))
    elif [[ $key == ^? ]]; then
      if [[ $key == '^?' ]]; then
        ((code|=0x7F))
      elif [[ $key == '^`' ]]; then
        ((code|=0x20))
      else
        ble/util/s2c "$key" 1
        ((code|=ret&0x1F))
      fi
    else
      ((code|=ble_decode_Erro))
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
  local char=$((key&ble_decode_MaskChar))
  ble-decode-kbd/.get-keyname "$char"
  if [[ ! $ret ]]; then
    f_unknown=1
    ret=__UNKNOWN__
  fi

  ((key&ble_decode_Shft)) && ret=S-$ret
  ((key&ble_decode_Meta)) && ret=M-$ret
  ((key&ble_decode_Ctrl)) && ret=C-$ret
  ((key&ble_decode_Altr)) && ret=A-$ret
  ((key&ble_decode_Supr)) && ret=s-$ret
  ((key&ble_decode_Hypr)) && ret=H-$ret

  [[ ! $f_unknown ]]
}

## 関数 ble-decode-unkbd keys...
##   @var[in] keys
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

# **** ble-decode-byte ****

## 設定関数 ble-decode/PROLOGUE
## 設定関数 ble-decode/EPILOGUE
function ble-decode/PROLOGUE { :; }
function ble-decode/EPILOGUE { :; }

function ble-decode/.hook {
  local IFS=$' \t\n'
  ble-decode/PROLOGUE

  local c
  for c; do
#%if debug_keylogger
    ((_ble_keylogger_enabled)) && ble/array#push _ble_keylogger_bytes "$c"
#%end
    "ble-decode-byte+$bleopt_input_encoding" "$c"
  done

  ble-decode/EPILOGUE
}

# ## 関数 ble-decode-byte bytes...
# ##   バイト値を整数で受け取って、現在の文字符号化方式に従ってデコードをします。
# ##   デコードした結果得られた文字は ble-decode-char を呼び出す事によって処理します。
# function ble-decode-byte {
#   while (($#)); do
#     "ble-decode-byte+$bleopt_input_encoding" "$1"
#     shift
#   done
# }

# **** ble-decode-char/csi ****

_ble_decode_csi_mode=0
_ble_decode_csi_args=
_ble_decode_csimap_tilde=()
_ble_decode_csimap_alpha=()
function ble-decode-char/csi/print {
  local num ret
  for num in "${!_ble_decode_csimap_tilde[@]}"; do
    ble-decode-unkbd "${_ble_decode_csimap_tilde[num]}"
    echo "ble-bind --csi '$num~' $ret"
  done

  for num in "${!_ble_decode_csimap_alpha[@]}"; do
    local s; ble/util/c2s "$num"; s=$ret
    ble-decode-unkbd "${_ble_decode_csimap_alpha[num]}"
    echo "ble-bind --csi '$s' $ret"
  done
}

function ble-decode-char/csi/clear {
  _ble_decode_csi_mode=0
}
function ble-decode-char/csi/.modify-kcode {
  local mod=$(($1-1))
  if ((mod>=0)); then
    # Note: Meta 0x20 は独自
    ((mod&0x01&&(kcode|=ble_decode_Shft),
      mod&0x02&&(kcode|=ble_decode_Altr),
      mod&0x04&&(kcode|=ble_decode_Ctrl),
      mod&0x08&&(kcode|=ble_decode_Supr),
      mod&0x10&&(kcode|=ble_decode_Hypr),
      mod&0x20&&(kcode|=ble_decode_Meta)))
  fi
}
function ble-decode-char/csi/.decode {
  local char=$1 rex kcode
  if ((char==126)); then
    if rex='^27;([1-9][0-9]*);?([1-9][0-9]*)$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # xterm "CSI 2 7 ; <mod> ; <char> ~" sequences
      local kcode=$((BASH_REMATCH[2]&ble_decode_MaskChar))
      ble-decode-char/csi/.modify-kcode "${BASH_REMATCH[1]}"
      csistat=$kcode
      return
    fi

    if rex='^([1-9][0-9]*)(;([1-9][0-9]*))?$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # "CSI <kcode> ; <mod> ~" sequences
      kcode=${_ble_decode_csimap_tilde[BASH_REMATCH[1]]}
      if [[ $kcode ]]; then
        ble-decode-char/csi/.modify-kcode "${BASH_REMATCH[3]}"
        csistat=$kcode
        return
      fi
    fi
  elif ((char==94||char==64)); then
    if rex='^[1-9][0-9]*$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      # rxvt "CSI <kcode> ^", "CSI <kcode> @" sequences
      kcode=${_ble_decode_csimap_tilde[BASH_REMATCH[1]]}
      if [[ $kcode ]]; then
        ((kcode|=ble_decode_Ctrl,
          char==64&&(kcode|=ble_decode_Shft)))
        ble-decode-char/csi/.modify-kcode "${BASH_REMATCH[3]}"
        csistat=$kcode
        return
      fi
    fi
  fi

  # pc-style "CSI 1; <mod> A" sequences
  kcode=${_ble_decode_csimap_alpha[char]}
  if [[ $kcode ]]; then
    if rex='^(1?|1;([1-9][0-9]*))$' && [[ $_ble_decode_csi_args =~ $rex ]]; then
      ble-decode-char/csi/.modify-kcode "${BASH_REMATCH[2]}"
      csistat=$kcode
      return
    fi
  fi
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

_ble_decode_char__hook=

## 配列 _ble_decode_cmap_${_ble_decode_char__seq}[char]
##   文字列からキーへの写像を保持する。
##   各要素は文字の列 ($_ble_decode_char__seq $char) に対する定義を保持する。
##   各要素は以下の形式の何れかである。
##   kcode+ 文字の列がキー kcode に一意に対応する事を表す。
##   _      文字の列が何らかのキーを表す文字列の prefix になっている事を表す。
##   kcode_ 文字の列がキー kcode に対応すると同時に、
##          他のキーの文字列の prefix になっている事を表す。
_ble_decode_cmap_=()

# _ble_decode_char__seq が設定されている時は、
# 必ず _ble_decode_char2_reach も設定されている様にする。
_ble_decode_char2_seq=
_ble_decode_char2_reach=
_ble_decode_char2_modifier=
_ble_decode_char2_modkcode=
function ble-decode-char {
  while (($#)); do # Note: ループ中で set -- ... を使っている。
    local char=$1; shift
#%if debug_keylogger
    ((_ble_keylogger_enabled)) && ble/array#push _ble_keylogger_chars "$char"
#%end

    # decode error character
    if ((char&ble_decode_Erro)); then
      ((char&=~ble_decode_Erro))
      if [[ $bleopt_decode_error_char_vbell ]]; then
        local name; ble/util/sprintf name 'U+%04x' "$char"
        ble/term/visible-bell "received a misencoded char $name"
      fi
      [[ $bleopt_decode_error_char_abell ]] && ble/term/audible-bell
      [[ $bleopt_decode_error_char_discard ]] && continue
      # ((char&ble_decode_Erro)) : 最適化(過去 sequence は全部吐く)?
    fi

    # hook for quoted-insert, etc
    if [[ $_ble_decode_char__hook ]]; then
      ((char==ble_decode_IsolatedESC)) && char=27 # isolated ESC -> ESC
      local hook=$_ble_decode_char__hook
      _ble_decode_char__hook=
      ble-decode-key/.call-widget "$hook $char" "$char"
      continue
    fi

    local ent
    ble-decode-char/.getent
    if [[ ! $ent ]]; then
      # シーケンスが登録されていない時
      if [[ $_ble_decode_char2_reach ]]; then
        local reach rest
        ble/string#split-words reach "$_ble_decode_char2_reach"
        rest=${_ble_decode_char2_seq:reach[1]}
        ble/string#split-words rest "${rest//_/ } $char"

        _ble_decode_char2_reach=
        _ble_decode_char2_seq=
        ble-decode-char/csi/clear

        ble-decode-char/.send-modified-key "${reach[0]}"
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

##   @var[in] _ble_decode_char2_seq
##   @var[in] char
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
    if [[ ! $ent ]]; then
      ent=$csistat
    else
      ent=${csistat%_}_
    fi
  fi

  # ble-assert '[[ $ent =~ ^[0-9]*_?$ ]]'
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
    # ※以下では kcode 内に既に mflag
    # と重複する修飾がある場合は考慮していない。
    # 重複があったという情報はここで消える。
    ((_ble_decode_char2_modkcode=kcode|mflag,
      _ble_decode_char2_modifier=mflag1|mflag))
    return 0
  fi
}

## 関数 ble-decode-char/.send-modified-key kcode
##   指定されたキーを修飾して ble-decode-key に渡します。
##   kcode = 0..31 は C-@ C-a ... C-z C-[ C-\ C-] C-^ C-_ に変換されます。
##   ESC は次に来る文字を meta 修飾します。
##   ble_decode_IsolatedESC は meta にならずに ESC として渡されます。
##   @param[in] kcode
##     処理対象のキーコードを指定します。
function ble-decode-char/.send-modified-key {
  local kcode=$1
  if ((0<=kcode&&kcode<32)); then
    ((kcode|=(kcode==0||kcode>26?64:96)|ble_decode_Ctrl))
  fi

  if (($1==27)); then
    ble-decode-char/.process-modifier "$ble_decode_Meta" && return
  elif (($1==ble_decode_IsolatedESC)); then
    ((kcode=(ble_decode_Ctrl|91)))
    if ! ble-decode/uses-isolated-esc; then
      ble-decode-char/.process-modifier "$ble_decode_Meta" && return
    fi
  elif ((_ble_decode_KCODE_SHIFT<=$1&&$1<=_ble_decode_KCODE_HYPER)); then
    case "$1" in
    ($_ble_decode_KCODE_SHIFT)
      ble-decode-char/.process-modifier "$ble_decode_Shft" && return ;;
    ($_ble_decode_KCODE_CONTROL)
      ble-decode-char/.process-modifier "$ble_decode_Ctrl" && return ;;
    ($_ble_decode_KCODE_ALTER)
      ble-decode-char/.process-modifier "$ble_decode_Altr" && return ;;
    ($_ble_decode_KCODE_META)
      ble-decode-char/.process-modifier "$ble_decode_Meta" && return ;;
    ($_ble_decode_KCODE_SUPER)
      ble-decode-char/.process-modifier "$ble_decode_Supr" && return ;;
    ($_ble_decode_KCODE_HYPER)
      ble-decode-char/.process-modifier "$ble_decode_Hypr" && return ;;
    esac
  fi

  if [[ $_ble_decode_char2_modifier ]]; then
    local mflag=$_ble_decode_char2_modifier
    local mcode=$_ble_decode_char2_modkcode
    _ble_decode_char2_modifier=
    _ble_decode_char2_modkcode=
    if ((kcode&mflag)); then
      ble-decode-key "$mcode"
    else
      ((kcode|=mflag))
    fi
  fi

  ble-decode-key "$kcode"
}

function ble-decode-char/bind {
  local -a seq=($1)
  local kc=$2

  local i iN=${#seq[@]} char tseq=
  for ((i=0;i<iN;i++)); do
    local char=${seq[i]}

    builtin eval "local okc=\${_ble_decode_cmap_$tseq[char]-}"
    if ((i+1==iN)); then
      if [[ ${okc//[0-9]/} == _ ]]; then
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
  local -a seq=($1)

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

    unset "_ble_decode_cmap_$tseq[char]"
    builtin eval "((\${#_ble_decode_cmap_$tseq[@]}!=0))" && break

    [[ $tseq ]]
  do
    char=${tseq##*_}
    tseq=${tseq%_*}
  done
}
function ble-decode-char/dump {
  local IFS=$_ble_term_IFS
  local tseq=$1 nseq ccode
  nseq=("${@:2}")
  builtin eval "local -a ccodes; ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret; ble-decode-unkbd "$ccode"
    local cnames
    cnames=("${nseq[@]}" "$ret")

    builtin eval "local ent=\${_ble_decode_cmap_$tseq[ccode]}"
    if [[ ${ent%_} ]]; then
      local kcode=${ent%_} ret
      ble-decode-unkbd "$kcode"; local kspec=$ret
      builtin echo "ble-bind -k '${cnames[*]}' '$kspec'"
    fi

    if [[ ${ent//[0-9]/} == _ ]]; then
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
function ble-decode/keymap/register {
  local kmap=$1
  if [[ $kmap && $_ble_decode_kmaps != *":$kmap:"* ]]; then
    _ble_decode_kmaps=$_ble_decode_kmaps:$kmap:
  fi
}

function ble-decode/keymap/dump {
  if (($#)); then
    local kmap=$1 arrays
    builtin eval "arrays=(\"\${!_ble_decode_${kmap}_kmap_@}\")"
    builtin echo "ble-decode/keymap/register $kmap"
    ble/util/declare-print-definitions "${arrays[@]}"
  else
    local keymap_name
    for keymap_name in ${_ble_decode_kmaps//:/ }; do
      ble-decode/keymap/dump "$keymap_name"
    done
  fi
}

## 設定関数 ble-decode/DEFAULT_KEYMAP -v varname
##   既定の keymap を決定します。
##   ble-decode.sh 使用コードで上書きして使用します。
function ble-decode/DEFAULT_KEYMAP {
  [[ $1 == -v ]] || return 1
  builtin eval "$2=emacs"
}

## 設定関数 ble/widget/.SHELL_COMMAND command
##   ble-bind -cf で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND { local IFS=$_ble_term_IFS; builtin eval -- "$*"; }
## 設定関数 ble/widget/.EDIT_COMMAND command
##   ble-bind -xf で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND { local IFS=$_ble_term_IFS; builtin eval -- "$*"; }


## 関数 kmap ; ble-decode-key/bind keycodes command
function ble-decode-key/bind {
  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq=($1)
  local cmd=$2

  ble-decode/keymap/register "$kmap"

  local i iN=${#seq[@]} key tseq=
  for ((i=0;i<iN;i++)); do
    local key=${seq[i]}

    builtin eval "local ocmd=\${$dicthead$tseq[$key]}"
    if ((i+1==iN)); then
      if [[ ${ocmd::1} == _ ]]; then
        builtin eval "$dicthead$tseq[$key]=_:\$cmd"
      else
        builtin eval "$dicthead$tseq[$key]=1:\$cmd"
      fi
    else
      if [[ ! $ocmd ]]; then
        builtin eval "$dicthead$tseq[$key]=_"
      elif [[ ${ocmd::1} == 1 ]]; then
        builtin eval "$dicthead$tseq[$key]=_:\${ocmd#?:}"
      fi
      tseq=${tseq}_$key
    fi
  done
}

function ble-decode-key/unbind {
  local dicthead=_ble_decode_${kmap}_kmap_
  local -a seq=($1)

  local i iN=${#seq[@]}
  local key=${seq[iN-1]}
  local tseq=
  for ((i=0;i<iN-1;i++)); do
    tseq=${tseq}_${seq[i]}
  done

  local isfirst=1 ent=
  while
    builtin eval "ent=\${$dicthead$tseq[$key]}"

    if [[ $isfirst ]]; then
      # command を消す
      isfirst=
      if [[ ${ent::1} == _ ]]; then
        # ent = _ または _:command の時は、単に command を消して終わる。
        # (未だ bind が残っているので、登録は削除せず break)。
        builtin eval $dicthead$tseq[$key]=_
        break
      fi
    else
      # prefix の ent は _ か _:command のどちらかの筈。
      if [[ $ent != _ ]]; then
        # _:command の場合には 1:command に書き換える。
        # (1:command の bind が残っているので登録は削除せず break)。
        builtin eval "$dicthead$tseq[$key]=1:\${ent#?:}"
        break
      fi
    fi

    unset "$dicthead$tseq[$key]"
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
    for kmap in ${_ble_decode_kmaps//:/ }; do
      echo "# keymap $kmap"
      ble-decode-key/dump "$kmap"
    done
    return
  fi

  local kmap=$1 tseq=$2 nseq=$3
  local dicthead=_ble_decode_${kmap}_kmap_
  local kmapopt=
  [[ $kmap ]] && kmapopt=" -m '$kmap'"

  local kcode kcodes
  builtin eval "kcodes=(\${!$dicthead$tseq[@]})"
  for kcode in "${kcodes[@]}"; do
    local ret; ble-decode-unkbd "$kcode"
    local knames=$nseq${nseq:+ }$ret
    builtin eval "local ent=\${$dicthead$tseq[$kcode]}"
    if [[ ${ent:2} ]]; then
      local cmd=${ent:2} q=\' Q="'\''"
      case "$cmd" in
      # ('ble/widget/.insert-string '*)
      #   echo "ble-bind -sf '${knames//$q/$Q}' '${cmd#ble/widget/.insert-string }'" ;;
      ('ble/widget/.SHELL_COMMAND '*)
        echo "ble-bind$kmapopt -cf '${knames//$q/$Q}' '${cmd#ble/widget/.SHELL_COMMAND }'" ;;
      ('ble/widget/.EDIT_COMMAND '*)
        echo "ble-bind$kmapopt -xf '${knames//$q/$Q}' '${cmd#ble/widget/.EDIT_COMMAND }'" ;;
      ('ble/widget/'*)
        echo "ble-bind$kmapopt -f '${knames//$q/$Q}' '${cmd#ble/widget/}'" ;;
      (*)
        echo "ble-bind$kmapopt -xf '${knames//$q/$Q}' '${cmd}'" ;;
      esac
    fi

    if [[ ${ent::1} == _ ]]; then
      ble-decode-key/dump "$kmap" "${tseq}_$kcode" "$knames"
    fi
  done
}

## 変数 _ble_decode_key__kmap
##
##   現在選択されている keymap
##
## 配列 _ble_decode_keymap_stack
##
##   呼び出し元の keymap を記録するスタック
##
_ble_decode_key__kmap=emacs
_ble_decode_keymap_stack=()

_ble_decode_keymap_load=
function ble-decode/keymap/is-keymap {
  builtin eval -- "((\${#_ble_decode_${1}_kmap_[*]}))"
}
function ble-decode/keymap/load {
  ble-decode/keymap/is-keymap "$1" && return 0

  local init=ble-decode/keymap:$1/define
  if ble/util/isfunction "$init"; then
    "$init" && ble-decode/keymap/is-keymap "$1"
  elif [[ $_ble_decode_keymap_load != *s* ]]; then
    ble-import "keymap/$1.sh" &&
      local _ble_decode_keymap_load=s &&
      ble-decode/keymap/load "$1" # 再試行
  else
    return 1
  fi
}

## 関数 ble-decode/keymap/push kmap
function ble-decode/keymap/push {
  if ble-decode/keymap/is-keymap "$1"; then
    ble/array#push _ble_decode_keymap_stack "$_ble_decode_key__kmap"
    _ble_decode_key__kmap=$1
  elif ble-decode/keymap/load "$1" && ble-decode/keymap/is-keymap "$1"; then
    ble-decode/keymap/push "$1" # 再実行
  else
    echo "[ble: keymap '$1' not found]" >&2
    return 1
  fi
}
## 関数 ble-decode/keymap/pop
function ble-decode/keymap/pop {
  local count=${#_ble_decode_keymap_stack[@]}
  local last=$((count-1))
  ble-assert '((last>=0))' || return
  _ble_decode_key__kmap=${_ble_decode_keymap_stack[last]}
  unset '_ble_decode_keymap_stack[last]'
}


## 今迄に入力された未処理のキーの列を保持します
_ble_decode_key__seq= # /(_\d+)*/

_ble_decode_key__hook=

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
  for key; do
#%if debug_keylogger
    ((_ble_keylogger_enabled)) && ble/array#push _ble_keylogger_keys "$key"
#%end
    [[ $_ble_decode_keylog_enabled && $_ble_decode_keylog_depth == 0 ]] &&
      ble/array#push _ble_decode_keylog "$key"

    if [[ $_ble_decode_key__hook ]]; then
      local hook=$_ble_decode_key__hook
      _ble_decode_key__hook=
      ble-decode-key/.call-widget "$hook $key" "$key"
      continue
    fi

    local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_

    builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[key]-}"
    if [[ $ent == 1:* ]]; then
      # /1:command/    (続きのシーケンスはなく ent で確定である事を示す)
      local command=${ent:2}
      if [[ $command ]]; then
        ble-decode-key/.invoke-command
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
      local kcseq=${_ble_decode_key__seq}_$key ret
      ble-decode-unkbd "${kcseq//_/ }"
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
  local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_

  local next=$1
  if [[ $_ble_decode_key__seq ]]; then
    local last=${_ble_decode_key__seq##*_}
    _ble_decode_key__seq=${_ble_decode_key__seq%_*}

    builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[last]-}"
    if [[ $ent == '_:'* ]]; then
      local command=${ent:2}
      if [[ $command ]]; then
        ble-decode-key/.invoke-command
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
    local key=$1 seq_save=$_ble_decode_key__seq
    if ble-decode-key/ischar "$key"; then
      builtin eval "local command=\${${dicthead}[$_ble_decode_KCODE_DEFCHAR]-}"
      command=${command:2}
      if [[ $command ]]; then
        ble-decode-key/.invoke-command; local ext=$?
        ((ext!=125)) && return
        _ble_decode_key__seq=$seq_save # 125 の時はまた元に戻して次の試行を行う
      fi
    fi

    # 既定のキーハンドラ
    builtin eval "local command=\${${dicthead}[$_ble_decode_KCODE_DEFAULT]-}"
    command=${command:2}
    ble-decode-key/.invoke-command; local ext=$?
    ((ext!=125)) && return

    return 1
  fi
}

function ble-decode-key/ischar {
  local key=$1
  (((key&ble_decode_MaskFlag)==0&&32<=key&&key<ble_decode_function_key_base))
}
function ble-decode-key/.invoke-hook {
  local kcode=$1
  local dicthead=_ble_decode_${_ble_decode_key__kmap}_kmap_
  builtin eval "local hook=\${$dicthead[kcode]-}"
  hook=${hook:2}
  [[ $hook ]] && builtin eval -- "$hook"
}

## 関数 ble-decode-key/.invoke-command
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
function ble-decode-key/.invoke-command {
  [[ $command ]] || return 125

  # for keylog suppress
  local old_suppress=$_ble_decode_keylog_depth
  local _ble_decode_keylog_depth=$((old_suppress+1))

  # setup variables
  local WIDGET=$command KEYMAP=$_ble_decode_key__kmap
  local -a KEYS; ble/string#split-words KEYS "${_ble_decode_key__seq//_/ } $key"
  _ble_decode_key__seq=

  ble-decode-key/.invoke-hook "$_ble_decode_KCODE_BEFORE_COMMAND"
  builtin eval -- "$WIDGET"; local ext=$?
  ble-decode-key/.invoke-hook "$_ble_decode_KCODE_AFTER_COMMAND"
  return "$ext"
}
function ble-decode-key/.call-widget {
  # for keylog suppress
  local old_suppress=$_ble_decode_keylog_depth
  local _ble_decode_keylog_depth=$((old_suppress+1))

  # setup variables
  local WIDGET=$1 KEYMAP=$_ble_decode_key__kmap
  local -a KEYS; ble/string#split-words KEYS "$2"

  builtin eval -- "$WIDGET"
}
function ble-decode/invoke-widget {
  local WIDGET=ble/widget/$1 KEYMAP=$_ble_decode_key__kmap
  local -a KEYS; KEYS=("${@:2}")
  ble-decode-key/.invoke-hook "$_ble_decode_KCODE_BEFORE_COMMAND"
  builtin eval -- "$WIDGET"; local ext=$?
  ble-decode-key/.invoke-hook "$_ble_decode_KCODE_AFTER_COMMAND"
  return "$ext"
}

#%if debug_keylogger
_ble_keylogger_enabled=0
_ble_keylogger_bytes=()
_ble_keylogger_chars=()
_ble_keylogger_keys=()
function ble-decode/start-keylog {
  _ble_keylogger_enabled=1
}
function ble-decode/end-keylog {
  {
    local IFS=$_ble_term_IFS
    echo '===== bytes ====='
    printf '%s\n' "${_ble_keylogger_bytes[*]}"
    echo
    echo '===== chars ====='
    local ret; ble-decode-unkbd "${_ble_keylogger_chars[@]}"
    ble/string#split ret ' ' "$ret"
    printf '%s\n' "${ret[*]}"
    echo
    echo '===== keys ====='
    local ret; ble-decode-unkbd "${_ble_keylogger_keys[@]}"
    ble/string#split ret ' ' "$ret"
    printf '%s\n' "${ret[*]}"
    echo
  } | fold -w 40

  _ble_keylogger_enabled=0
  _ble_keylogger_bytes=()
  _ble_keylogger_chars=()
  _ble_keylogger_keys=()
}
#%end
_ble_decode_keylog_enabled=
_ble_decode_keylog_depth=0
_ble_decode_keylog=()
function ble-decode/keylog/start {
  _ble_decode_keylog_enabled=1
  _ble_decode_keylog=()
}
function ble-decode/keylog/end {
  ret=("${_ble_decode_keylog[@]}")
  _ble_decode_keylog_enabled=
  _ble_decode_keylog=()
}
## 関数 ble-decode/keylog/pop
##   現在の WIDGET 呼び出しに対応する KEYS が記録されているとき、これを削除します。
##   @var[in] _ble_decode_keylog_enabled
##   @var[in] _ble_decode_keylog_depth
##   @arr[in] KEYS
function ble-decode/keylog/pop {
  [[ $_ble_decode_keylog_enabled && $_ble_decode_keylog_depth == 1 ]] || return
  local new_size=$((${#_ble_decode_keylog[@]}-${#KEYS[@]}))
  _ble_decode_keylog=("${_ble_decode_keylog[@]::new_size}")
}


# **** ble-bind ****

function ble-bind/option:help {
  ble/util/cat <<EOF
ble-bind --help
ble-bind -k charspecs [keyspec]
ble-bind [-m kmapname] [-scx@] -f keyspecs [command]
ble-bind [-DdL]
ble-bind --list-functions

EOF
}

function ble-bind/check-argunment {
  if (($3<$2)); then
    if (($2==1)); then
      echo "ble-bind: the option \`$1' requires an argument." >&2
    else
      echo "ble-bind: the option \`$1' requires $2 arguments." >&2
    fi
    return 2
  fi
}
#
#
function ble-bind/option:csi {
  local ret kcode=
  if [[ $2 ]]; then
    ble-decode-kbd "$2"; kcode=($ret)
    if ((${#kcode[@]}!=1)); then
      echo "ble-bind --csi: the second argument is not a single key!" >&2
      return 1
    elif ((kcode&~ble_decode_MaskChar)); then
      echo "ble-bind --csi: the second argument should not have modifiers!" >&2
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
    _ble_decode_csimap_tilde[BASH_REMATCH[1]]="$kcode"

    # "CSI <num> $" は CSI sequence の形式に沿っていないので、
    # 個別に登録する必要がある。
    local -a cseq
    cseq=(27 91)
    local ret i iN num="${BASH_REMATCH[1]}\$"
    for ((i=0,iN=${#num};i<iN;i++)); do
      ble/util/s2c "$num" "$i"
      ble/array#push cseq "$ret"
    done
    if [[ $kcode ]]; then
      ble-decode-char/bind "${cseq[*]}" "$((kcode|ble_decode_Shft))"
    else
      ble-decode-char/unbind "${cseq[*]}"
    fi
  elif [[ $1 == [a-zA-Z] ]]; then
    # --csi '<Ft>' kname
    local ret; ble/util/s2c "$1"
    _ble_decode_csimap_alpha[ret]=$kcode
  else
    echo "ble-bind --csi: not supported type of csi sequences: CSI \`$1'." >&2
    return 1
  fi
}

function ble-bind/option:list-functions {
  declare -f | ble/bin/sed -n 's/^ble\/widget\/\([[:alpha:]][^.[:space:]();&|]\{1,\}\)[[:space:]]*()[[:space:]]*$/\1/p'
}

function ble-bind {
  local kmap=$ble_bind_keymap flags= ret
  ble-decode-initialize

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
      (list-functions)
        ble-bind/option:list-functions ;;
      (*)
        echo "ble-bind: unrecognized long option $arg" >&2
        return 2 ;;
      esac
    elif [[ $arg == -?* ]]; then
      arg=${arg:1}
      while ((${#arg})); do
        c=${arg::1} arg=${arg:1}
        case "$c" in
        (D)
          ble/util/declare-print-definitions "${!_ble_decode_kbd__@}" "${!_ble_decode_cmap_@}" "${!_ble_decode_csimap_@}"
          ble-decode/keymap/dump ;;
        (d)
          ble-decode-char/csi/print
          ble-decode-char/dump
          [[ $kmap ]] || ble-decode/DEFAULT_KEYMAP -v kmap
          ble-decode-key/dump ;;
        (k)
          if (($#<2)); then
            echo "ble-bind: the option \`-k' requires two arguments." >&2
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
            echo "ble-bind: the option \`-m' requires an argument." >&2
            return 2
          fi
          kmap=$1
          shift ;;
        (['@xcs']) flags=${flags}$c ;;
        (f)
          if (($#<2)); then
            echo "ble-bind: the option \`-f' requires two arguments." >&2
            return 2
          fi

          ble-decode-kbd "$1"
          if [[ $2 && $2 != - ]]; then
            local command=$2

            # コマンドの種類
            case "$flags" in
            ('')
              # ble/widget/ 関数
              command=ble/widget/$command

              # check if is function
              local arr; ble/string#split-words arr "$command"
              if ! ble/util/isfunction "${arr[0]}"; then
                if [[ $command == ble/widget/ble/widget/* ]]; then
                  echo "ble-bind: Unknown ble edit function \`${arr[0]#'ble/widget/'}'. Note: The prefix 'ble/widget/' is redundant" 1>&2
                else
                  echo "ble-bind: Unknown ble edit function \`${arr[0]#'ble/widget/'}'" 1>&2
                fi
                return 1
              fi ;;
            (x) # 編集用の関数
              local q=\' Q="''\'"
              command="ble/widget/.EDIT_COMMAND '${command//$q/$Q}'" ;;
            (c) # コマンド実行
              local q=\' Q="''\'"
              command="ble/widget/.SHELL_COMMAND '${command//$q/$Q}'" ;;
            ('@') ;; # 直接実行
            (*)
              echo "error: unknowon combination of flags \`-$flags'." 1>&2
              return 1 ;;
            esac

            [[ $kmap ]] || ble-decode/DEFAULT_KEYMAP -v kmap
            ble-decode-key/bind "$ret" "$command"
          else
            [[ $kmap ]] || ble-decode/DEFAULT_KEYMAP -v kmap
            ble-decode-key/unbind "$ret"
          fi
          flags=
          shift 2 ;;
        (L)
          ble-bind/option:list-functions ;;
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

# **** ESC ESC ****                                           @decode.bind.esc2

## 関数 ble/widget/.CHARS ...
##   - lib/init-bind.sh で設定する bind で使用する。
##   - bind '"keyseq":"macro"' の束縛に使用する。
function ble/widget/.CHARS {
  ble-decode-char "$@"
}


# **** ^U ^V ^W ^? 対策 ****                                   @decode.bind.uvw

_ble_decode_bind__uvwflag=
function ble-decode-bind/uvw {
  [[ $_ble_decode_bind__uvwflag ]] && return
  _ble_decode_bind__uvwflag=1

  # 何故か stty 設定直後には bind できない物たち
  builtin bind -x '"":ble-decode/.hook 21; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 22; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 23; builtin eval "$_ble_decode_bind_hook"'
  builtin bind -x '"":ble-decode/.hook 127; builtin eval "$_ble_decode_bind_hook"'
}

# **** ble-decode-bind ****                                   @decode.bind.main

_ble_decode_bind_hook=

## 関数 ble-decode-bind/c2dqs code; ret
##   bash builtin bind で用いる事のできるキー表記
function ble-decode-bind/c2dqs {
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
    else
      ble-decode-bind/c2dqs $((i+64))
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

## 関数 binder; ble-decode-bind/cmap/.generate-binder-template
##   3文字以上の bind -x を _ble_decode_cmap から自動的に行うソースを生成
##   binder には bind を行う関数を指定する。
#
# ※この関数は bash-3.1 では使えない。
#   bash-3.1 ではバグで呼出元と同名の配列を定義できないので
#   local -a ccodes が空になってしまう。
#   幸いこの関数は bash-3.1 では使っていないのでこのままにしてある。
#   追記: 公開されている patch を見たら bash-3.1.4 で修正されている様だ。
#
function ble-decode-bind/cmap/.generate-binder-template {
  local tseq=$1 qseq=$2 nseq=$3 depth=${4:-1} ccode
  local apos="'" escapos="'\\''"
  builtin eval "local -a ccodes; ccodes=(\${!_ble_decode_cmap_$tseq[@]})"
  for ccode in "${ccodes[@]}"; do
    local ret
    ble-decode-bind/c2dqs "$ccode"
    qseq1=$qseq$ret
    nseq1="$nseq $ccode"

    builtin eval "local ent=\${_ble_decode_cmap_$tseq[$ccode]}"
    if [[ ${ent%_} ]]; then
      if ((depth>=3)); then
        echo "\$binder \"$qseq1\" \"${nseq1# }\""
      fi
    fi

    if [[ ${ent//[0-9]/} == _ ]]; then
      ble-decode-bind/cmap/.generate-binder-template "${tseq}_$ccode" "$qseq1" "$nseq1" $((depth+1))
    fi
  done
}

function ble-decode-bind/cmap/.emit-bindx {
  local ap="'" eap="'\\''"
  echo "builtin bind -x '\"${1//$ap/$eap}\":ble-decode/.hook $2; builtin eval \"\$_ble_decode_bind_hook\"'"
}
function ble-decode-bind/cmap/.emit-bindr {
  echo "builtin bind -r \"$1\""
}

_ble_decode_cmap_initialized=
function ble-decode-bind/cmap/initialize {
  [[ $_ble_decode_cmap_initialized ]] && return
  _ble_decode_cmap_initialized=1

  [[ -d $_ble_base_cache ]] || ble/bin/mkdir -p "$_ble_base_cache"

  local init=$_ble_base/cmap/default.sh
  local dump=$_ble_base_cache/cmap+default.$_ble_decode_kbd_ver.$TERM.dump
  if [[ $dump -nt $init ]]; then
    source "$dump"
  else
    echo 'ble.sh: generating "'"$dump"'"...' 1>&2
    source "$init"
    ble-bind -D | ble/bin/awk '
      {
        sub(/^declare +(-[aAfFgiclrtux]+ +)?/, "");
        sub(/^-- +/, "");
      }
      /^_ble_decode_(cmap|csimap|kbd)/ {
        gsub(/["'\'']/, "");
        print
      }
    ' >| "$dump"
  fi

  if ((_ble_bash>=40300)); then
    # 3文字以上 bind/unbind ソースの生成
    local fbinder=$_ble_base_cache/cmap+default.binder-source
    _ble_decode_bind_fbinder=$fbinder
    if ! [[ $_ble_decode_bind_fbinder -nt $init ]]; then
      echo -n 'ble.sh: initializing multichar sequence binders... '
      ble-decode-bind/cmap/.generate-binder-template >| "$fbinder"
      binder=ble-decode-bind/cmap/.emit-bindx source "$fbinder" >| "$fbinder.bind"
      binder=ble-decode-bind/cmap/.emit-bindr source "$fbinder" >| "$fbinder.unbind"
      echo 'done'
    fi
  fi
}

## 関数 ble-decode-bind/.generate-source-to-unbind-default
##   既存の ESC で始まる binding を削除するコードを生成し標準出力に出力します。
##   更に、既存の binding を復元する為のコードを同時に生成し tmp/$$.bind.save に保存します。
function ble-decode-bind/.generate-source-to-unbind-default {
  # 1 ESC で始まる既存の binding を全て削除
  # 2 bind を全て記録 at $$.bind.save
  {
    if ((_ble_bash>=40300)); then
      echo '__BINDX__'
      builtin bind -X
    fi
    echo '__BINDP__'
    builtin bind -sp
  } | ble-decode-bind/.generate-source-to-unbind-default/.process

  # Note: 2>/dev/null は、(1) bind -X のエラーメッセージ、及び、
  # (2) LC_ALL 復元時のエラーメッセージ (外側の値が不正な時) を捨てる為に必要。
} 2>/dev/null
function ble-decode-bind/.generate-source-to-unbind-default/.process {
  local q=\' b=\\ Q="'\''"
  # Note: Solaris xpg4 awk では gsub の置換後のエスケープシーケンスも処理される
  [[ $_ble_bin_awk_solaris_xpg4 == yes ]] && Q="'$b$b''"
  local QUOT_Q=\"${Q//"$b"/$b$b}\"
  LC_ALL=C ble/bin/awk -v q="$q" '
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

#%      # ※bash-3.1 では bind -sp で \e ではなく \M- と表示されるが、
#%      #   bind -r では \M- ではなく \e と指定しなければ削除できない。
        gsub(/\\M-/, "\\e", _seq);

        print "builtin bind -r " quote(_seq);
      }
    }

    /^__BINDP__$/ { mode = 1; next; }
    /^__BINDX__$/ { mode = 2; next; }

    mode == 1 && $0 ~ /^"/ {
      # Workaround Bash-5.0 bug (cf #D1078)
      sub(/^"\\C-\\\\\\"/, "\"\\C-\\\\\"");
      sub(/^"\\C-\\"/, "\"\\C-\\\\\"");

      output_bindr($0);

      print "builtin bind " quote($0) > "/dev/stderr";
    }

    mode == 2 && $0 ~ /^"/ {
      output_bindr($0);

      line = $0;

#%    # ※bash-4.3 では bind -r しても bind -X に残る。
#%    #   再登録を防ぐ為 ble-decode-bind を明示的に避ける
      if (line ~ /(^|[^[:alnum:]])ble-decode\/.hook($|[^[:alnum:]])/) next;

#%    # ※bind -X で得られた物は直接 bind -x に用いる事はできない。
#%    #   コマンド部分の "" を外して中の escape を外す必要がある。
#%    #   escape には以下の種類がある: \C-a など \C-? \e \\ \"
#%    #     \n\r\f\t\v\b\a 等は使われない様だ。
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

function ble-decode/bind {
  local file=$_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.bind
  [[ $file -nt $_ble_base/bind.sh ]] || source "$_ble_base/bind.sh"

  # * 一時的に 'set convert-meta off' にする。
  #
  #   bash-3.0 - 5.0a 全てにおいて 'set convert-meta on' の時、
  #   128-255 を bind しようとすると 0-127 を bind してしまう。
  #   32 bit 環境で LC_CTYPE=C で起動すると 'set convert-meta on' になる様だ。
  #
  #   一応、以下の関数は ble/term/initialize で呼び出しているので、
  #   ble-decode/bind の呼び出しが ble/term/initialize より後なら大丈夫の筈だが、
  #   念の為にここでも呼び出しておく事にする。
  #
  ble/term/rl-convert-meta/enter

  source "$file"
  _ble_decode_bind__uvwflag=
}
function ble-decode/unbind {
  local encoding_clear=ble/encoding:$bleopt_input_encoding/clear
  ble/util/isfunction "$encoding_clear" && "$encoding_clear"
  source "$_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.unbind"
}

#------------------------------------------------------------------------------

function ble-decode-initialize {
  ble-decode-bind/cmap/initialize
}

_ble_decode_bind_state=none
function ble-decode/reset-default-keymap {
  # 現在の ble-decode/keymap の設定
  ble-decode/DEFAULT_KEYMAP -v _ble_decode_key__kmap # 0ms
  ble-decode-key/.invoke-hook "$_ble_decode_KCODE_ATTACH" # 7ms for vi-mode
}
function ble-decode-attach {
  [[ $_ble_decode_bind_state != none ]] && return
  ble/util/save-editing-mode _ble_decode_bind_state
  [[ $_ble_decode_bind_state == none ]] && return 1

  # bind/unbind 中に C-c で中断されると大変なので先に stty を設定する必要がある
  ble/term/initialize # 3ms

  # 元のキー割り当ての保存・unbind
  builtin eval -- "$(ble-decode-bind/.generate-source-to-unbind-default)" # 21ms

  # ble.sh bind の設置
  ble-decode/bind # 20ms

  # 失敗すると悲惨なことになるので抜ける。
  if ! ble/is-array "_ble_decode_${_ble_decode_key__kmap}_kmap_"; then
    echo "ble.sh: Failed to load the default keymap. keymap '$_ble_decode_key__kmap' is not defined." >&2
    ble-decode-detach
    return 1
  fi
}
function ble-decode-detach {
  [[ $_ble_decode_bind_state != none ]] || return

  local current_editing_mode=
  ble/util/save-editing-mode current_editing_mode
  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode _ble_decode_bind_state

  ble/term/finalize

  # ble.sh bind の削除
  ble-decode/unbind

  # 元のキー割り当ての復元
  if [[ -s "$_ble_base_run/$$.bind.save" ]]; then
    source "$_ble_base_run/$$.bind.save"
    : >| "$_ble_base_run/$$.bind.save"
  fi

  [[ $_ble_decode_bind_state == "$current_editing_mode" ]] || ble/util/restore-editing-mode current_editing_mode

  _ble_decode_bind_state=none
}

# function bind {
#   if ((_ble_decode_bind_state)); then
#     echo Error
#   else
#     builtin bind "$@"
#   fi
# }

#------------------------------------------------------------------------------
# **** encoding = UTF-8 ****

function ble/encoding:UTF-8/generate-binder { :; }

# # bind.sh の esc1B==3 の設定用
# # これは bind.sh の中にある物と等価なので殊更に設定しなくて良い。
# function ble/encoding:UTF-8/generate-binder {
#   ble/init:bind/bind-s '"\C-@":"\xC0\x80"'
#   ble/init:bind/bind-s '"\e":"\xDF\xBF"' # isolated ESC (U+07FF)
#   local i ret
#   for i in {0..255}; do
#     ble-decode-bind/c2dqs "$i"
#     ble/init:bind/bind-s "\"\e$ret\": \"\xC0\x9B$ret\""
#   done
# }

_ble_decode_byte__utf_8__mode=0
_ble_decode_byte__utf_8__code=0
function ble/encoding:UTF-8/clear {
  _ble_decode_byte__utf_8__mode=0
  _ble_decode_byte__utf_8__code=0
}
function ble-decode-byte+UTF-8 {
  local code=$_ble_decode_byte__utf_8__code
  local mode=$_ble_decode_byte__utf_8__mode
  local byte=$1
  local cha0= char=
  ((
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
  ))

  _ble_decode_byte__utf_8__code=$code
  _ble_decode_byte__utf_8__mode=$mode

  local -a CHARS=($cha0 $char)
  ((${#CHARS[*]})) && ble-decode-char "${CHARS[@]}"
}

## 関数 ble-text-c2bc+UTF-8 code
##   @param[in]  code
##   @var  [out] ret
function ble-text-c2bc+UTF-8 {
  local code=$1
  ((ret=code<0x80?1:
    (code<0x800?2:
    (code<0x10000?3:
    (code<0x200000?4:5)))))
}

# bind.sh の esc1B==3 の設定用
function ble/encoding:C/generate-binder {
  ble/init:bind/bind-s '"\C-@":"\x9B\x80"'
  ble/init:bind/bind-s '"\e":"\x9B\x8B"' # isolated ESC (U+07FF)
  local i ret
  for i in {0..255}; do
    ble-decode-bind/c2dqs "$i"
    ble/init:bind/bind-s "\"\e$ret\": \"\x9B\x9B$ret\""
  done
}

## 関数 ble-decode-byte+C byte
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
function ble-decode-byte+C {
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

## 関数 ble-text-c2bc+C charcode ; ret
function ble-text-c2bc+C {
  ret=1
}
