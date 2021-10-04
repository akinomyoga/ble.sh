#!/bin/bash

function mkd { [[ -d $1 ]] || mkdir -p "$1"; }

## @fn make/canvas.emoji/get-emoji-data [emoji_version]
##   @var[out] emoji_data
##   @var[out] emoji_cache_file
function make/canvas.emoji/get-emoji-data {
  #local unicode_version=$(wget https://unicode.org/Public/emoji/ -O - | grep -Eo 'href="[0-9]+\.[0-9]+/"' | sed 's,^href=",,;s,/"$,,' | tail -n 1)
  local unicode_version=${1:-14.0}
  emoji_cache_file=out/data/unicode-emoji-$unicode_version.txt
  if [[ ! -s $emoji_cache_file ]]; then
    mkd out/data
    wget "https://unicode.org/Public/emoji/$unicode_version/emoji-test.txt" -O "$emoji_cache_file.part" &&
      mv "$emoji_cache_file.part" "$emoji_cache_file"
  fi

  local gawk_script='
      /^[[:space:]]*#/ { next; }
      sub(/;.*$/, "") { print $0; }'
  ble/util/assign-array emoji_data 'gawk "$gawk_script" "$emoji_cache_file"'
}

function make/canvas.emoji/sub:help {
  ble/util/print "usage: source ${BASH_SOURCE##*/}${BASH_SOURCE:-canvas.emoji.sh} SUBCOMMAND ARGS..."
  ble/util/print
  ble/util/print "SUBCOMMAND"
  declare -F | sed -n 's/^declare -f make\/canvas.emoji\/sub:\([^[:space:]]*\)/  \1/p'
  ble/util/print
}

function make/canvas.emoji/sub:save-emoji-type {
  local emoji_data emoji_cache_file
  make/canvas.emoji/get-emoji-data
  gawk '
    /^[[:space:]]*#/ { next; }
    {
      if (/unqualified/) {
        type = "UQ";
      } else if (/fully-qualified/) {
        type = "FQ";
      } else if (/minimally-qualified/) {
        type = "MQ";
      } else {
        type = "XX";
      }
    }
    sub(/;.*$/, "") {
      s = "";
      for (i = 1; i <= NF; i++) {
        s = s sprintf("\\U%05X", strtonum("0x" $i));
      }
      print s ": " type;
    }
  ' "$emoji_cache_file" | sort -u > out/data/emoji.TYPE.txt
}

function make/canvas.emoji/sub:compare {
  grep '^\\' out/data/emoji.TYPE.txt |
    join - <(awk '/^\\/ { sub(/^w=/, "blesh=", $2); print; }' out/data/emoji.blesh.txt) |
    join - <(awk '/^\\/ { sub(/^w=/, "kitty=", $2); print; }' out/data/emoji.kitty.txt)
#    grep -E '^.{7}: UQ' | less
}

#------------------------------------------------------------------------------
# measure-emoji.impl1

_tool_emoji_width_code=()
_tool_emoji_width_gcb=()
_tool_emoji_width_w=()
function inspect1/proc {
  local -a DRAW_BUFF=() code=() gcb=()
  local ret c
  ble/canvas/put.draw $'\r'
  for c; do
    ((c=16#$c))
    ble/array#push code "$c"
    ble/unicode/GraphemeCluster/c2break "$c"
    ble/array#push gcb "$ret"
    ble/util/c2s "$c"
    ble/canvas/put.draw "$ret"
  done

  ble/array#push _tool_emoji_width_code "${code[*]}"
  ble/array#push _tool_emoji_width_gcb "${gcb[*]}"
  ble/term/CPR/request.draw inspect1/callback
  ble/canvas/bflush.draw
}
function inspect1/callback {
  local term_l=$1 term_c=$2
  local w=$((term_c-1))
  ble/array#push _tool_emoji_width_w "$w"
}
function inspect1/callback-final {
  echo ----------------------------------------
  date +'%F %T %Z'
  echo "request count: ${#_tool_emoji_width_code[@]}"
  echo "response count: ${#_tool_emoji_width_w[@]}"
  echo "remaining CPR hooks: ${#_ble_term_CPR_hook[@]}"
  for ((i=0;i<${#_tool_emoji_width_w[@]};i++)); do
    echo "${_tool_emoji_width_gcb[i]}: w=${_tool_emoji_width_w[i]}"
  done | sort -u
} >> emoji.txt

function make/canvas.emoji/sub:measure-emoji.impl1 {
  local emoji_data emoji_cache_file
  make/canvas.emoji/get-emoji-data
  ble/util/buffer.flush >&2
  local line
  for line in "${emoji_data[@]}"; do
    eval "inspect1/proc $line"
  done
  ble/term/CPR/request.buff inspect1/callback-final
  ble/util/buffer.flush >&2
}

#------------------------------------------------------------------------------
# measure-emoji

_term_emojiw_index_req=0
_term_emojiw_index_rcv=0
_term_emojiw_data=()
_term_emojiw_code=()
_term_emojiw_gcb=()
_term_emojiw_width=()
_term_emojiw_output=emoji.txt

function inspect2/start {
  _term_emojiw_index_req=0
  _term_emojiw_index_rcv=0
  _term_emojiw_data=("${emoji_data[@]}")
  _term_emojiw_output=emoji.txt
  : > "$_term_emojiw_output"
  inspect2/next
}

function inspect2/next {
  if ((_term_emojiw_index_rcv>=${#_term_emojiw_data[@]})); then
    inspect2/final
    return
  fi

  local ndata=${#_term_emojiw_data[@]}

  local i
  for ((i=0;i<10&&_term_emojiw_index_req<ndata;i++,_term_emojiw_index_req++)); do
    local words
    ble/string#split-words words "${_term_emojiw_data[_term_emojiw_index_req]}"

    local -a gcb=() code=()
    local c s=
    for c in "${words[@]}"; do
      ((c=16#$c))
      ble/array#push code "$c"
      ble/unicode/GraphemeCluster/c2break "$c"
      ble/array#push gcb "$ret"
      ble/util/c2s "$c"
      s=$s$ret
    done
    ble/util/sprintf ret '\\U%05X' "${code[@]}"
    ble/array#push _term_emojiw_code "$ret"
    ble/array#push _term_emojiw_gcb "${gcb[*]}"

    ble/util/buffer $'\r'"$s"
    ble/term/CPR/request.buff inspect2/wait
    ble/util/buffer.flush >&2
  done
  ble/edit/info/show text "Measuring #$_term_emojiw_index_rcv..$_term_emojiw_index_req"
}
function inspect2/wait {
  local col=$2
  ((_term_emojiw_width[_term_emojiw_index_rcv]=col-1))
  ((++_term_emojiw_index_rcv==_term_emojiw_index_req)) &&
    inspect2/next
  return 0
}
function inspect2/final {
  {
    echo ----------------------------------------
    date +'%F %T %Z'
    echo "request count: ${#_term_emojiw_gcb[@]}"
    echo "response count: ${#_term_emojiw_width[@]}"
    local i
    for ((i=0;i<_term_emojiw_index_rcv;i++)); do
      echo "${_term_emojiw_gcb[i]}: w=${_term_emojiw_width[i]}"
    done | sort -u
    for ((i=0;i<_term_emojiw_index_rcv;i++)); do
      echo "${_term_emojiw_code[i]}: w=${_term_emojiw_width[i]}"
    done | sort -u
  } >> "$_term_emojiw_output"
  echo Done
}

function make/canvas.emoji/sub:measure-emoji {
  local emoji_data emoji_cache_file
  make/canvas.emoji/get-emoji-data 14.0
  inspect2/start
}

#------------------------------------------------------------------------------
# measure-emoji-sequences

## @fn ble/unicode/measure-emoji-sequences
##   @var[in] emoji_data
function ble/unicode/measure-emoji-sequences {
  local line words ret count=0
  local -a codes=() gcbs=() widths=()
  for line in "${emoji_data[@]}"; do
    ble/string#split-words words "$line"

    local s= word c
    local -a code=() gcb=()
    for word in "${words[@]}"; do
      ((c=16#$word))
      ble/array#push code "$c"
      ble/unicode/GraphemeCluster/c2break "$c"; ble/array#push gcb "$ret"
      ble/util/c2s "$c"; s=$s$ret
    done
    ble/util/sprintf ret '\\U%05X' "${code[@]}"
    ble/array#push codes "$ret"
    ble/array#push gcbs "${gcb[*]}"
    ble/util/s2w "$s"
    ble/array#push widths "$ret"
  done

  local i n=${#codes[@]}
  for ((i=0;i<n;i++)); do
    echo "${gcbs[i]}: w=${widths[i]}"
  done | sort -u
  for ((i=0;i<n;i++)); do
    echo "${codes[i]}: w=${widths[i]}"
  done | sort -u
}
function ble/unicode/test-emoji-sequence-width {
  local term=$1 scheme=$2
  ble/unicode/measure-emoji-sequences > out/data/emoji."blesh-$scheme".txt
  diff -bwu <(grep '^\\U' out/data/emoji."blesh-$scheme".txt) <(grep '^\\U' out/data/emoji."$term".txt)
}

## @fn make/canvas.emoji/sub:measure-blesh term [scheme]
function make/canvas.emoji/sub:measure-blesh {
  local emoji_data emoji_cache_file
  make/canvas.emoji/get-emoji-data 14.0

  local term=$1 scheme=${2:-$1}
  case $scheme in
  (blesh)
    (
      echo blesh...
      bleopt char_width_mode=east
      bleopt emoji_width=2
      bleopt emoji_opts=ri:tpvs:epvs:zwj
      ble/unicode/measure-emoji-sequences > out/data/emoji.blesh.txt
    ) ;;

  (kitty)
    (
      echo kitty...
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=13.1
      bleopt emoji_opts=ri:tpvs:epvs
      _ble_util_c2w=(
        # これらは絵文字になる可能性のある全角であり半角にはならない筈
        [0x3030]=1 [0x303D]=1 [0x3297]=1 [0x3299]=1
        # これらは肌の色を変える拡張文字だが単体で使われた時の幅は多くの端末で2
        [0x1F3FB]=0 [0x1F3FC]=0 [0x1F3FD]=0 [0x1F3FE]=0 [0x1F3FF]=0
      )
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (rlogin)
    (
      echo RLogin
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=12.1
      bleopt grapheme_cluster=extended
      bleopt emoji_opts=ri:zwj
      _ble_util_c2w=(
        # これらは unqualified だが多くの端末で特別に幅2の様だ
        [0x1F202]=2 [0x1F237]=2

        # これらは肌の色を変える拡張文字だが単体で使われた時の幅は多くの端末で2
        [0x1F3FB]=0 [0x1F3FC]=0 [0x1F3FD]=0 [0x1F3FE]=0 [0x1F3FF]=0
      )
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (alacritty)
    (
      echo Alacritty
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=13.1
      bleopt emoji_opts=ri
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_util_c2w=([0x1F202]=2 [0x1F237]=2)
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (vte|urxvt)
    (
      echo 'vte (GNOME terminal, terminator) / urxvt...'
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=12.1
      bleopt emoji_opts=ri
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      # ↓これらは unqualified だが vte では特別に幅2の様だ
      _ble_util_c2w=([0x1F202]=2 [0x1F237]=2)
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (mintty)
    (
      echo mintty...
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=11.0
      bleopt emoji_opts=ri
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_util_c2w=([0x1F202]=2 [0x1F237]=2)
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (konsole|st)
    (
      echo "$scheme..."
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=11.0
      bleopt emoji_opts=
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_util_c2w=(
        # これらは unqualified だが vte では特別に幅2の様だ
        [0x1F202]=2 [0x1F237]=2
      )
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (mlterm)
    (
      echo mlterm... # (全然合わない。unqualified も emoji に入っている気がする)
      bleopt char_width_mode=east
      bleopt emoji_width=2
      bleopt emoji_version=11.0
      bleopt grapheme_cluster=extended
      bleopt emoji_opts=ri
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x0200D]=$_ble_unicode_GraphemeClusterBreak_Other
      # Unicode tags
      for ((code=0xE0020;code<=0xE007F;code++)); do
        _ble_unicode_GraphemeClusterBreak[code]=$_ble_unicode_GraphemeClusterBreak_Other
      done
      _ble_util_c2w=(
        # ZWJ が幅1になる
        [0x0200D]=1
        # これらは unqualified だが多くの端末で特別に幅2の様だ
        [0x1F202]=2 [0x1F237]=2
        # mlterm は一部の unqualified だけを幅2にしている。
        [0x26F0]=2 [0x26F1]=2 [0x26F4]=2 [0x26F7]=2 [0x26F8]=2 [0x26F9]=2
        [0x26C8]=2 [0x26CF]=2 [0x26D1]=2 [0x26D3]=2 [0x26E9]=2
        [0x1F170]=2 [0x1F171]=2 [0x1F17E]=2 [0x1F17F]=2
      )
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (terminology)
    (
      echo terminology...
      bleopt char_width_mode=west
      bleopt emoji_width=2
      bleopt emoji_version=2.0
      bleopt emoji_opts=unqualified:min=U+3000
      bleopt grapheme_cluster=legacy
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x0200D]=$_ble_unicode_GraphemeClusterBreak_Other
      _ble_unicode_GraphemeClusterBreak[0x020E3]=$_ble_unicode_GraphemeClusterBreak_Other
      # Unicode tags
      for ((code=0xE0020;code<=0xE007F;code++)); do
        _ble_unicode_GraphemeClusterBreak[code]=$_ble_unicode_GraphemeClusterBreak_Other
      done
      _ble_util_c2w=(
        # これらは unqualified だが vte では特別に幅2の様だ
        [0x1F202]=2 [0x1F237]=2
      )
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (xterm)
    (
      echo xterm...
      bleopt char_width_mode=west
      bleopt emoji_width=
      #bleopt emoji_version=11.0
      bleopt emoji_opts=
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_util_c2w=(
        [0x1F202]=2 [0x1F237]=2

        #[0x1F3FB]=2 [0x1F3FC]=2 [0x1F3FD]=2 [0x1F3FE]=2 [0x1F3FF]=2
        [0x1F3FB]=1 [0x1F3FC]=1 [0x1F3FD]=1 [0x1F3FE]=1 [0x1F3FF]=1

        [0x1F9AF]=2
        [0x1F9B0]=2
        [0x1F9B1]=2
        [0x1F9B2]=2
        [0x1F9B3]=2
        [0x1F9BC]=2
        [0x1F9BD]=2
      )
      # Unicode tags
      for ((code=0xE0020;code<=0xE007F;code++)); do
        _ble_unicode_GraphemeClusterBreak[code]=$_ble_unicode_GraphemeClusterBreak_Other
      done
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (screen)
    (
      echo screen...
      bleopt char_width_mode=emacs
      bleopt emoji_width=
      bleopt emoji_opts=
      _ble_unicode_GraphemeClusterBreak[0x1F3FB]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FC]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FD]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FE]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      _ble_unicode_GraphemeClusterBreak[0x1F3FF]=$_ble_unicode_GraphemeClusterBreak_Pictographic
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  (contra)
    (
      echo contra
      bleopt char_width_mode=emacs
      bleopt emoji_width=
      bleopt grapheme_cluster=
      ble/unicode/test-emoji-sequence-width "$term" "$scheme"
    ) ;;

  esac
}

#------------------------------------------------------------------------------

function make/canvas.emoji/sub:dump-EmojiStatus {
  local emoji_data emoji_cache_file
  make/canvas.emoji/get-emoji-data

  local line words code
  for line in "${emoji_data[@]}"; do
    ble/string#split-words words "$line"

    ((${#words[@]}==1)) || continue
    ((code=16#${words[0]}))
    ble/unicode/EmojiStatus "$code"
    printf 'U+%05X %d\n' "$code" "$ret"
  done
}


if declare -F "make/canvas.emoji/sub:$1" &>/dev/null; then
  "make/canvas.emoji/sub:$@"
else
  make/canvas.emoji/sub:help
fi
