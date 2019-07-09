#!/bin/bash

## @arr _ble_edit_history
##   コマンド履歴項目を保持する。
##
## @arr _ble_edit_history_edit
## @arr _ble_edit_history_dirt
##   _ble_edit_history_edit 編集されたコマンド履歴項目を保持する。
##   _ble_edit_history の各項目と対応し、必ず同じ数・添字の要素を持つ。
##   _ble_edit_history_dirt は編集されたかどうかを保持する。
##   _ble_edit_history の各項目と対応し、変更のあったい要素にのみ値 1 を持つ。
##
## @var _ble_edit_history_ind
##   現在の履歴項目の番号
##
## @arr _ble_edit_history_onleave
##   履歴移動の通知先を格納する配列
##
_ble_edit_history=()
_ble_edit_history_edit=()
_ble_edit_history_dirt=()
_ble_edit_history_ind=0
_ble_edit_history_onleave=()

## @var _ble_edit_history_loaded
## @var _ble_edit_history_count
##
##   これらの変数はコマンド履歴を対象としているときにのみ用いる。
##
_ble_edit_history_loaded=
_ble_edit_history_count=

function ble-edit/history/onleave.fire {
  local -a observers
  eval "observers=(\"\${${_ble_edit_history_prefix:-_ble_edit}_history_onleave[@]}\")"
  local obs; for obs in "${observers[@]}"; do "$obs" "$@"; done
}

## 関数 ble-edit/history/initialize
if ((_ble_bash>=40000)); then
  # _ble_bash>=40000 で利用できる以下の機能に依存する
  #   ble/util/is-stdin-ready (via ble-decode/has-input)
  #   ble/util/mapfile

  _ble_edit_history_loading=0
  _ble_edit_history_loading_bgpid=

  # history > tmp
  ## 関数 ble-edit/history/load/.background-initialize
  ##   @var[in] arg_count
  function ble-edit/history/load/.background-initialize {
    if ! builtin history -p '!!' &>/dev/null; then
      # Note: rcfile から呼び出すと history が未ロードなのでロードする。
      #
      # Note: 当初は親プロセスで history -n にした方が二度手間にならず効率的と考えたが
      #   以下の様な問題が生じたので、やはりサブシェルの中で history -n する事にした。
      #
      #   問題1: bashrc の謎の遅延 (memo.txt#D0702)
      #     shopt -s histappend の状態で親シェルで history -n を呼び出すと、
      #     bashrc を抜けてから Bash 本体によるプロンプトが表示されて、
      #     入力を受け付けられる様になる迄に、謎の遅延が発生する。
      #     特に履歴項目の数が HISTSIZE の丁度半分より多い時に起こる様である。
      #
      #     history -n を呼び出す瞬間だけ shopt -u histappend して
      #     直後に shopt -s histappend とすると、遅延は解消するが、
      #     実際の動作を観察すると histappend が無効になってしまっている。
      #
      #     対策として、一時的に HISTSIZE を大きくして bashrc を抜けて、
      #     最初のユーザからの入力の時に HISTSIZE を復元する事にした。
      #     これで遅延は解消できる様である。
      #
      #   問題2: 履歴の数が倍加する問題 (memo.txt#D0732)
      #     親シェルで history -n を実行すると、
      #     shopt -s histappend の状態だと履歴項目の数が2倍になってしまう。
      #     bashrc を抜ける直前から最初にユーザの入力を受けるまでに倍加する。
      #     bashrc から抜けた後に Readline が独自に履歴を読み取るのだろう。
      #     一方で shopt -u histappend の状態だとシェルが動作している内は問題ないが、
      #     シェルを終了した時に2倍に .bash_history の内容が倍になってしまう。
      #
      #     これの解決方法は不明。(HISTFILE 等を弄ったりすれば可能かもれないが試していない)
      #
      builtin history -n
    fi
    local -x HISTTIMEFORMAT=__ble_ext__
    local -x INDEX_FILE=$history_indfile
    local opt_cygwin=; [[ $OSTYPE == cygwin* ]] && opt_cygwin=1

    local apos=\'
    # 482ms for 37002 entries
    builtin history $arg_count | ble/bin/awk -v apos="$apos" -v opt_cygwin="$opt_cygwin" '
      BEGIN {
        n = 0;
        hindex = 0;
        INDEX_FILE = ENVIRON["INDEX_FILE"];
        printf("") > INDEX_FILE; # create file
        if (opt_cygwin) print "_ble_edit_history=(";
      }

      function flush_line() {
        if (n < 1) return;

        if (n == 1) {
          if (t ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
            print hindex > INDEX_FILE;
          hindex++;
        } else {
          gsub(/['$apos'\\]/, "\\\\&", t);
          gsub(/\n/, "\\n", t);
          print hindex > INDEX_FILE;
          t = "eval -- $" apos t apos;
          hindex++;
        }

        if (opt_cygwin) {
          gsub(/'$apos'/, "'$apos'\\'$apos$apos'", t);
          t = apos t apos;
        }

        print t;
        n = 0;
        t = "";
      }

      {
        if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0))
          flush_line();
        t = ++n == 1 ? $0 : t "\n" $0;
      }

      END {
        flush_line();
        if (opt_cygwin) print ")";
      }
    ' >| "$history_tmpfile.part"
    ble/bin/mv -f "$history_tmpfile.part" "$history_tmpfile"
  }

  ## 関数 ble-edit/history/load opts
  ##   @param[in] opts
  ##     async
  ##       非同期で読み取ります。
  ##     append
  ##       現在読み込み済みの履歴情報に追加します。
  ##     offset=NUMBER
  ##       _ble_edit_history 配列の途中から書き込みます。
  ##     count=NUMBER
  ##       最近の NUMBER 項目だけ読み取ります。
  function ble-edit/history/load {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1
    local opt_info=; ((_ble_edit_attached)) && [[ ! $opt_async ]] && opt_info=1
    local opt_cygwin=; [[ $OSTYPE == cygwin* ]] && opt_cygwin=1

    local arg_count= arg_offset=0
    if [[ :$opts: == *:append:* ]]; then
      arg_offset=${#_ble_edit_history[@]}
    elif local rex=':offset=([0-9]+):'; [[ :$opts: =~ $rex ]]; then
      arg_offset=${BASH_REMATCH[1]}
    fi
    local rex=':count=([0-9]+):'; [[ :$opts: =~ $rex ]] && arg_count=${BASH_REMATCH[1]}

    local history_tmpfile=$_ble_base_run/$$.history.load
    local history_indfile=$_ble_base_run/$$.history.multiline-index
    [[ $opt_async || :$opts: == *:init:* ]] || _ble_edit_history_loading=0
    while :; do
      case $_ble_edit_history_loading in

      # 42ms 履歴の読み込み
      (0) [[ $opt_info ]] && ble-edit/info/immediate-show text "loading history..."

          # 履歴ファイル生成を Background で開始
          : >| "$history_tmpfile"

          if [[ $opt_async ]]; then
            _ble_edit_history_loading_bgpid=$(
              shopt -u huponexit; ble-edit/history/load/.background-initialize </dev/null &>/dev/null & ble/bin/echo $!)

            function ble-edit/history/load/.background-initialize-completed {
              local history_tmpfile=$_ble_base_run/$$.history.load
              [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_edit_history_loading_bgpid"
            } &>/dev/null

            ((_ble_edit_history_loading++))
          else
            ble-edit/history/load/.background-initialize
            ((_ble_edit_history_loading+=3))
          fi ;;

      # 515ms ble-edit/history/load/.background-initialize 待機
      (1) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble-edit/history/load/.background-initialize-completed
            ((_ble_edit_history_loading++))
            return 148
          fi
          ((_ble_edit_history_loading++)) ;;

      # Note: async でバックグラウンドプロセスを起動した後に、直接 (sync で)
      #   呼び出された時、未だ処理が完了していなくても次のステップに進んでしまうので、
      #   此処で条件が満たされるのを待つ (#D0745)
      (2) while ! ble-edit/history/load/.background-initialize-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ble-decode/has-input && return 148
          done
          ((_ble_edit_history_loading++)) ;;

      # 47ms _ble_edit_history 初期化 (37000項目)
      (3) if [[ $opt_cygwin ]]; then
            # 620ms Cygwin (99000項目)
            source "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t _ble_edit_history < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;

      # 47ms _ble_edit_history_edit 初期化 (37000項目)
      (4) if [[ $opt_cygwin ]]; then
            # 504ms Cygwin (99000項目)
            _ble_edit_history_edit=("${_ble_edit_history[@]}")
          else
            builtin mapfile -O "$arg_offset" -t _ble_edit_history_edit < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (5) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            ((i+=arg_offset))
            [[ ${_ble_edit_history[i]} =~ $rex ]] &&
              eval "_ble_edit_history[i]=${_ble_edit_history[i]:8}"
          done
          ((_ble_edit_history_loading++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (6) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          for i in "${indices_to_fix[@]}"; do
            ((i+=arg_offset))
            [[ ${_ble_edit_history_edit[i]} =~ $rex ]] &&
              eval "_ble_edit_history_edit[i]=${_ble_edit_history_edit[i]:8}"
          done

          [[ $opt_info ]] && ble-edit/info/immediate-clear
          ((_ble_edit_history_loading++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ble-decode/has-input && return 148
    done
  }
  function ble-edit/history/clear-background-load {
    _ble_edit_history_loading=0
  }
else
  function ble-edit/history/.generate-source-to-load-history {
    if ! builtin history -p '!!' &>/dev/null; then
      # rcfile として起動すると history が未だロードされていない。
      builtin history -n
    fi
    HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    builtin history $arg_count | ble/bin/awk -v apos="'" '
      BEGIN { n = ""; }

      # ※rcfile として読み込むと HISTTIMEFORMAT が ?? に化ける。
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)/ {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        n = $1; t = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0);
      }
      {
        line = $0;
        if (line ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
          line = apos substr(line, 9) apos;
        else
          gsub(apos, apos "\\" apos apos, line);

        t = t != "" ? t "\n" line : line;
      }
      END {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }
      }
    '
  }

  function ble-edit/history/load {
    local opts=$1
    local opt_append=
    [[ :$opts: == *:append:* ]] && opt_append=1

    local arg_count= rex=':count=([0-9]+):'
    [[ :$opts: =~ $rex ]] && arg_count=${BASH_REMATCH[1]}

    ((_ble_edit_attached)) &&
      ble-edit/info/immediate-show text "loading history..."

    # * プロセス置換にしてもファイルに書き出しても大した違いはない。
    #   270ms for 16437 entries (generate-source の時間は除く)
    # * プロセス置換×source は bash-3 で動かない。eval に変更する。
    local result=$(ble-edit/history/.generate-source-to-load-history)
    if [[ $opt_append ]]; then
      if ((_ble_bash>=30100)); then
        builtin eval -- "_ble_edit_history+=($result)"
        builtin eval -- "_ble_edit_history_edit+=($result)"
      else
        local -a A; builtin eval -- "A=($result)"
        _ble_edit_history=("${_ble_edit_history[@]}" "${A[@]}")
        _ble_edit_history_edit=("${_ble_edit_history[@]}" "${A[@]}")
      fi
    else
      builtin eval -- "_ble_edit_history=($result)"
      _ble_edit_history_edit=("${_ble_edit_history[@]}")
    fi
    if ((_ble_edit_attached)); then
      ble-edit/info/clear
    fi
  }
  function ble-edit/history/clear-background-load { :; }
fi

## called by ble-edit/initialize in Bash 3
function ble-edit/history/initialize {
  [[ $_ble_edit_history_prefix ]] && return
  [[ $_ble_edit_history_loaded ]] && return
  ble-edit/history/load "init:$@"; local ext=$?
  ((ext)) && return "$ext"
  _ble_edit_history_loaded=1
  _ble_edit_history_count=${#_ble_edit_history[@]}
  _ble_edit_history_ind=$_ble_edit_history_count
}

function ble/builtin/history/.touch-histfile {
  local touch=$_ble_base_run/$$.history.touch
  : >| "$touch"
}
function ble/builtin/history/.get-min {
  ble/util/assign min 'builtin history | head -1'
  ble/string#split-words min "$min"
}
function ble/builtin/history/.get-max {
  ble/util/assign max 'builtin history 1'
  ble/string#split-words max "$max"
}

_ble_builtin_history_initialized=
_ble_builtin_history_histnew_count=0
_ble_builtin_history_histapp_count=0
_ble_builtin_history_delete_hook=()
_ble_builtin_history_clear_hook=()
ble/array#push _ble_builtin_history_delete_hook ble-edit/undo/history-delete.hook
ble/array#push _ble_builtin_history_clear_hook ble-edit/undo/history-clear.hook
## @var _ble_builtin_history_wskip
##   履歴のどの行までがファイルに書き込み済みの行かを管理する変数です。
## @var _ble_builtin_history_prevmax
##   最後の ble/builtin/history における builtin history の項目番号
_ble_builtin_history_wskip=0
_ble_builtin_history_prevmax=0
##
## 以下の関数は各ファイルに関して何処まで読み取ったかを記録します。
##
## 関数 ble/builtin/history/.get-rskip file
##   @param[in] file
##   @var[out] rskip
## 関数 ble/builtin/history/.set-rskip file value
##   @param[in] file
## 関数 ble/builtin/history/.add-rskip file delta
##   @param[in] file
##
if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  if ((_ble_bash>=40200)); then
    declare -gA _ble_builtin_history_rskip_dict=()
  else
    declare -A _ble_builtin_history_rskip_dict=()
  fi
  function ble/builtin/history/.get-rskip {
    local file=$1
    rskip=${_ble_builtin_history_rskip_dict[$file]}
  }
  function ble/builtin/history/.set-rskip {
    local file=$1
    _ble_builtin_history_rskip_dict[$file]=$2
  }
  function ble/builtin/history/.add-rskip {
    local file=$1
    ((_ble_builtin_history_rskip_dict[\$file]+=$2))
  }
else
  _ble_builtin_history_rskip_path=()
  _ble_builtin_history_rskip_skip=()
  function ble/builtin/history/.find-rskip-index {
    local file=$1
    local n=${#_ble_builtin_history_rskip_path[@]}
    for ((index=0;index<n;index++)); do
      [[ $file == ${_ble_builtin_history_rskip_path[index]} ]] && return
    done
    _ble_builtin_history_rskip_path[index]=$file
  }
  function ble/builtin/history/.get-rskip {
    local index; ble/builtin/history/.find-rskip-index "$1"
    rskip=${_ble_builtin_history_rskip_skip[index]}
  }
  function ble/builtin/history/.set-rskip {
    local index; ble/builtin/history/.find-rskip-index "$1"
    _ble_builtin_history_rskip_skip[index]=$2
  }
  function ble/builtin/history/.add-rskip {
    local index; ble/builtin/history/.find-rskip-index "$1"
    ((_ble_builtin_history_rskip_skip[index]+=$2))
  }
fi

function ble/builtin/history/.initialize {
  [[ $_ble_builtin_history_initialized ]] && return
  _ble_builtin_history_initialized=1

  local histnew=$_ble_base_run/$$.history.new
  : >| "$histnew"

  local histfile=${HISTFILE:-$HOME/.bash_history}
  local rskip=$(ble/bin/wc -l "$histfile" 2>/dev/null)
  ble/string#split-words rskip "$rskip"
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((max&&max-min+1<rskip&&(rskip=max-min+1)))
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
  ble/builtin/history/.set-rskip "$histfile" "$rskip"
}
## 関数 ble/builtin/history/.check-uncontrolled-change
##   ble/builtin/history の管理外で履歴が読み込まれた時、
##   それを history -a の対象から除外する為に wskip を更新する。
function ble/builtin/history/.check-uncontrolled-change {
  local max; ble/builtin/history/.get-max
  if ((max!=_ble_builtin_history_prevmax)); then
    _ble_builtin_history_wskip=$max
    _ble_builtin_history_prevmax=$max
  fi
}
## 関数 ble/builtin/history/.load-recent-entries delta
##   history の最新 count 件を配列 _ble_edit_history に読み込みます。
function ble/builtin/history/.load-recent-entries {
  [[ $_ble_decode_bind_state == none ]] && return

  local delta=$1
  ((delta>0)) || return 0

  if [[ ! $_ble_edit_history_loaded ]]; then
    # history load が完了していなければ読み途中のデータを破棄して戻る
    ble-edit/history/clear-background-load
    _ble_edit_history_count=
    return
  fi

  # 追加項目が大量にある場合には background で完全再初期化する
  if ((_ble_bash>=40000&&delta>=10000)); then
    ble-edit/reset-history
    return
  fi

  ble-edit/history/load append:count=$delta

  local count=${#_ble_edit_history[@]}
  ((_ble_edit_history_ind==_ble_edit_history_count)) && _ble_edit_history_ind=$count
  _ble_edit_history_count=$count
}
## 関数 ble/builtin/history/.read file [skip [fetch]]
function ble/builtin/history/.read {
  local file=$1 skip=${2:-0} fetch=$3
  local -x histnew=$_ble_base_run/$$.history.new
  if [[ -s $file ]]; then
    local script=$(ble/bin/awk -v skip=$skip '
      BEGIN { histnew = ENVIRON["histnew"]; count = 0; }
      NR <= skip { next; }
      { print $0 >> histnew; count++; }
      END {
        print "ble/builtin/history/.set-rskip \"$file\" " NR;
        print "((_ble_builtin_history_histnew_count+=" count "))";
      }
    ' "$file")
    eval -- "$script"
  else
    ble/builtin/history/.set-rskip "$file" 0
  fi
  if [[ ! $fetch && -s $histnew ]]; then
    local nline=$_ble_builtin_history_histnew_count
    builtin history -r "$histnew"
    : >| "$histnew"
    _ble_builtin_history_histnew_count=0
    ble/builtin/history/.load-recent-entries "$nline"
    local max; ble/builtin/history/.get-max
    _ble_builtin_history_wskip=$max
    _ble_builtin_history_prevmax=$max
  fi
}
## 関数 ble/builtin/history/.write file [skip [opts]]
function ble/builtin/history/.write {
  local -x file=$1 skip=${2:-0} opts=$3
  local -x histapp=$_ble_base_run/$$.history.app

  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((skip<min-1&&(skip=min-1)))
  local delta=$((max-skip))
  if ((delta>0)); then
    local HISTTIMEFORMAT=__ble_ext__
    if [[ :$opts: == *:append:* ]]; then
      builtin history "$delta" >> "$histapp"
      ((_ble_builtin_history_histapp_count+=delta))
    else
      builtin history "$delta" > "$histapp"
      _ble_builtin_history_histapp_count=$delta
    fi
  fi

  if [[ :$opts: != *:fetch:* && -s $histapp ]]; then
    if [[ ! -e $file ]]; then
      (umask 077; : >| "$file")
    elif [[ :$opts: != *:append:* ]]; then
      : >| "$file"
    fi

    local apos=\'
    < "$histapp" ble/bin/awk '
      BEGIN { file = ENVIRON["file"]; mode = 0; }
      function flush_line() {
        if (!mode) return;
        mode = 0;
        if (text ~ /\n/) {
          gsub(/\\/, "\\\\");
          gsub(/\n/, "\\n");
          gsub(/\t/, "\\t");
          gsub(/\'$apos'/, "\\'$apos'");
          print "eval -- $'$apos'" text "'$apos'" >> file;
        } else {
          print text >> file;
        }
      }

      /^ *[0-9]+\*? +(__ble_ext__|\?\?)?/ {
        flush_line();
        mode = 1; text = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)?/, "", $0);
      }
      { text = text != "" ? text "\n" $0 : $0; }
      END { flush_line(); }
    '
    ble/builtin/history/.add-rskip "$file" "$_ble_builtin_history_histapp_count"
    : >| "$histapp"
    _ble_builtin_history_histapp_count=0
  fi
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
}

## 関数 ble/builtin/history/array#delete-hindex array_name index...
##   @param[in] index
##     昇順に並んでいる事と重複がない事を仮定する。
function ble/builtin/history/array#delete-hindex {
  local array_name=$1; shift
  local script='
    local -a out=()
    local i shift=0
    for i in "${!ARRAY[@]}"; do
      local delete=
      while (($#)); do
        if [[ $1 == *-* ]]; then
          local b=${1%-*} e=${1#*-}
          ((i<b)) && break
          if ((i<e)); then
            delete=1 # delete
            break
          else
            ((shift+=e-b))
            shift
          fi
        else
          ((i<$1)) && break
          ((i==$1)) && delete=1
          ((shift++))
          shift
        fi
      done
      [[ ! $delete ]] &&
        out[i-shift]=${ARRAY[i]}
    done
    ARRAY=()
    for i in "${!out[@]}"; do ARRAY[i]=${out[i]}; done'
  eval -- "${script//ARRAY/$array_name}"
}
ble/array#push _ble_builtin_history_delete_hook ble/builtin/history/delete.hook
ble/array#push _ble_builtin_history_clear_hook ble/builtin/history/clear.hook
function ble/builtin/history/delete.hook {
  ble/builtin/history/array#delete-hindex _ble_edit_history_dirt "$@"
}
function ble/builtin/history/clear.hook {
  _ble_edit_history_dirt=()
}
## 関数 ble/builtin/history/option:c
function ble/builtin/history/option:c {
  ble/builtin/history/.initialize
  builtin history -c
  _ble_builtin_history_wskip=0
  _ble_builtin_history_prevmax=0
  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_edit_history_loaded ]]; then
      _ble_edit_history=()
      _ble_edit_history_edit=()
      _ble_edit_history_count=0
      _ble_edit_history_ind=0
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble-edit/history/clear-background-load
      _ble_edit_history_count=
    fi
    ble/util/invoke-hook _ble_builtin_history_clear_hook
  fi
}
## 関数 ble/builtin/history/option:d index
function ble/builtin/history/option:d {
  ble/builtin/history/.initialize
  local rex='^(-?[0-9]+)-(-?[0-9]+)$'
  if [[ $1 =~ $rex ]]; then
    local beg=${BASH_REMATCH[1]} end=${BASH_REMATCH[2]}
  else
    local beg=$(($1))
    local end=$beg
  fi
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((beg<0)) && ((beg+=max+1)); ((beg<min?(beg=min):(beg>max&&(beg=max))))
  ((end<0)) && ((end+=max+1)); ((end<min?(end=min):(end>max&&(end=max))))
  ((beg<=end)) || return 0

  if ((_ble_bash>=50000&&beg<end)); then
    builtin history -d "$beg-$end"
  else
    local i
    for ((i=end;i>=beg;i--)); do
      builtin history -d "$i"
    done
  fi
  if ((_ble_builtin_history_wskip>=end)); then
    ((_ble_builtin_history_wskip-=end-beg+1))
  elif ((_ble_builtin_history_wskip>beg-1)); then
    ((_ble_builtin_history_wskip=beg-1))
  fi

  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_edit_history_loaded ]]; then
      local N=${#_ble_edit_history[@]}
      local b=$((beg-1+N-max)) e=$((end+N-max))
      ble/util/invoke-hook _ble_builtin_history_delete_hook "$b-$e"
      if ((_ble_edit_history_ind>=e)); then
        ((_ble_edit_history_ind-=e-b))
      elif ((_ble_edit_history_ind>=b)); then
        [[ ! $_ble_edit_history_prefix ]] && ble-edit/history/goto "$e"
        _ble_edit_history_ind=$b
      fi
      _ble_edit_history=("${_ble_edit_history[@]::b}" "${_ble_edit_history[@]:e}")
      _ble_edit_history_edit=("${_ble_edit_history_edit[@]::b}" "${_ble_edit_history_edit[@]:e}")
      _ble_edit_history_count=${#_ble_edit_history[@]}
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble-edit/history/clear-background-load
      _ble_edit_history_count=
    fi
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
## 関数 ble/builtin/history/option:a [filename]
function ble/builtin/history/option:a {
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
  ble/builtin/history/.initialize
  ble/builtin/history/.check-uncontrolled-change
  local rskip; ble/builtin/history/.get-rskip "$filename"
  ble/builtin/history/.write "$filename" "$_ble_builtin_history_wskip" append:fetch
  [[ -r $filename ]] && ble/builtin/history/.read "$filename" "$rskip" fetch
  ble/builtin/history/.write "$filename" "$_ble_builtin_history_wskip" append
  builtin history -a /dev/null # Bash 終了時に書き込まない
}
## 関数 ble/builtin/history/option:n [filename]
function ble/builtin/history/option:n {
  # HISTFILE が更新されていなければスキップ
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
  if [[ $filename == $histfile ]]; then
    local touch=$_ble_base_run/$$.history.touch
    [[ $touch -nt $histfile ]] && return 0
    : >| "$touch"
  fi

  ble/builtin/history/.initialize
  local rskip; ble/builtin/history/.get-rskip "$filename"
  ble/builtin/history/.read "$filename" "$rskip"
}
## 関数 ble/builtin/history/option:w [filename]
function ble/builtin/history/option:w {
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
  ble/builtin/history/.initialize
  local rskip; ble/builtin/history/.get-rskip "$filename"
  [[ -r $filename ]] && ble/builtin/history/.read "$filename" "$rskip" fetch
  ble/builtin/history/.write "$filename" 0
  builtin history -a /dev/null # Bash 終了時に書き込まない
}
## 関数 ble/builtin/history/option:r [filename]
function ble/builtin/history/option:r {
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
  ble/builtin/history/.initialize
  ble/builtin/history/.read "$filename" 0
}
## 関数 ble/builtin/history/option:p
##   Workaround for bash-3.0 -- 5.0 bug
##   (See memo.txt #D0233, #D0801, #D1091)
function ble/builtin/history/option:p {
  # Note: history -p '' によって 履歴項目が減少するかどうかをチェックし、
  #   もし履歴項目が減る状態になっている場合は履歴項目を増やしてから history -p を実行する。
  #   嘗てはサブシェルで評価していたが、そうすると置換指示子が記録されず
  #   :& が正しく実行されないことになるのでこちらの実装に切り替える。
  local line1= line2=
  ble/util/assign line1 'HISTTIMEFORMAT= builtin history 1'
  builtin history -p -- '' &>/dev/null
  ble/util/assign line2 'HISTTIMEFORMAT= builtin history 1'
  if [[ $line1 != "$line2" ]]; then
    local rex_head='^[[:space:]]*[0-9]+[[:space:]]*'
    [[ $line1 =~ $rex_head ]] &&
      line1=${line1:${#BASH_REMATCH}}

    if ((_ble_bash<30100)); then
      # Note: history -r するとそれまでの履歴項目が終了時に
      #   .bash_history に反映されなくなるが、
      #   Bash 3.0 では明示的に書き込んでいるので問題ない。
      local tmp=$_ble_base_run/$$.history.tmp
      printf '%s\n' "$line1" "$line1" >| "$tmp"
      builtin history -r "$tmp"
    else
      builtin history -s -- "$line1"
      builtin history -s -- "$line1"
    fi
  fi

  builtin history -p -- "$@"
}
## 関数 ble/builtin/history/option:s
function ble/builtin/history/option:s {
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin history -s -- "$@"
    return
  fi

  local cmd=$1
  if [[ $HISTIGNORE ]]; then
    local pats pat
    ble/string#split pats : "$HISTIGNORE"
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return
    done
  fi

  ble/builtin/history/.initialize
  local histfile=
  if [[ $_ble_edit_history_loaded ]]; then
    if [[ $HISTCONTROL ]]; then
      local ignorespace ignoredups erasedups spec
      for spec in ${HISTCONTROL//:/ }; do
        case "$spec" in
        (ignorespace) ignorespace=1 ;;
        (ignoredups)  ignoredups=1 ;;
        (ignoreboth)  ignorespace=1 ignoredups=1 ;;
        (erasedups)   erasedups=1 ;;
        esac
      done

      if [[ $ignorespace ]]; then
        [[ $cmd == [' 	']* ]] && return
      fi
      if [[ $ignoredups ]]; then
        local lastIndex=$((${#_ble_edit_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_edit_history[lastIndex]}" ]] && return
      fi
      if [[ $erasedups ]]; then
        local -a delete_indices=()
        local shift_histindex_next=0
        local shift_wskip=0
        local i N=${#_ble_edit_history[@]}
        for ((i=0;i<N-1;i++)); do
          if [[ ${_ble_edit_history[i]} == "$cmd" ]]; then
            unset -v '_ble_edit_history[i]'
            unset -v '_ble_edit_history_edit[i]'
            ble/array#push delete_indices "$i"
            ((i<_ble_builtin_history_wskip&&shift_wskip++))
            ((i<HISTINDEX_NEXT&&shift_histindex_next++))
          fi
        done
        if ((${#delete_indices[@]})); then
          _ble_edit_history=("${_ble_edit_history[@]}")
          _ble_edit_history_edit=("${_ble_edit_history_edit[@]}")
          ble/util/invoke-hook _ble_builtin_history_delete_hook "${delete_indices[@]}"
          ((_ble_builtin_history_wskip-=shift_wskip))
          [[ ${HISTINDEX_NEXT+set} ]] && ((HISTINDEX_NEXT-=shift_histindex_next))
        fi
        ((N)) && [[ ${_ble_edit_history[N-1]} == "$cmd" ]] && return
      fi
    fi
    local topIndex=${#_ble_edit_history[@]}
    _ble_edit_history[topIndex]=$cmd
    _ble_edit_history_edit[topIndex]=$cmd
    _ble_edit_history_count=$((topIndex+1))
    _ble_edit_history_ind=$_ble_edit_history_count

    # _ble_bash<30100 の時は必ずここを通る。
    # 初期化時に _ble_edit_history_loaded=1 になるので。
    ((_ble_bash<30100)) && histfile=${HISTFILE:-$HOME/.bash_history}
  else
    if [[ $HISTCONTROL ]]; then
      # 未だ履歴が初期化されていない場合は取り敢えず history -s に渡す。
      # history -s でも HISTCONTROL に対するフィルタはされる。
      # history -s で項目が追加されたかどうかはスクリプトからは分からないので
      # _ble_edit_history_count は一旦クリアする。
      _ble_edit_history_count=
    else
      # HISTCONTROL がなければ多分 history -s で必ず追加される。
      # _ble_edit_history_count 取得済ならば更新。
      [[ $_ble_edit_history_count ]] &&
        ((_ble_edit_history_count++))
    fi
  fi

  if [[ $cmd == *$'\n'* ]]; then
    # Note: 改行を含む場合は %q は常に $'' の形式になる。
    ble/util/sprintf cmd 'eval -- %q' "$cmd"
  fi

  if [[ $histfile ]]; then
    # bash < 3.1 workaround
    local tmp=$_ble_base_run/$$.history.tmp
    [[ $bleopt_history_share ]] ||
      builtin printf '%s\n' "$cmd" >> "$histfile"
    builtin printf '%s\n' "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble-edit/history/clear-background-load
    builtin history -s -- "$cmd"
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history {
  while [[ $1 == -* ]]; do
    local arg=$1; shift
    [[ $arg == -- ]] && break

    local opt_d= flag_error=
    local opt_c= opt_p= opt_s=
    local opt_a=
    local i n=${#arg}
    for ((i=1;i<n;i++)); do
      local c=${arg:i:1}
      case $c in
      (c) opt_c=1 ;;
      (s) opt_s=1 ;;
      (p) opt_p=1 ;;
      (d)
        if ((!$#)); then
          echo 'ble/builtin/history: missing option argument for "-d".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_d=${arg:i+1}; i=$n
        else
          opt_d=$1; shift
        fi ;;
      ([anwr])
        if [[ $opt_a && $c != $opt_a ]]; then
          echo 'ble/builtin/history: cannot use more than one of "-anrw".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_a=$c
          set -- "${arg:i+1}" "$@"
        else
          opt_a=$c
        fi ;;
      (*)
        echo 'ble/builtin/history: unknown option "-$c".' >&2
        flag_error=1 ;;
      esac
    done
  done
  [[ $flag_error ]] && return 1

  # -cdanwr
  local flag_processed=
  if [[ $opt_c ]]; then
    ble/builtin/history/option:c
    flag_processed=1
  fi
  if [[ $opt_s ]]; then
    ble/builtin/history/option:s "$*"
    flag_processed=1
  elif [[ $opt_d ]]; then
    ble/builtin/history/option:d "$opt_d"
    flag_processed=1
  elif [[ $opt_a ]]; then
    ble/builtin/history/option:"$opt_a" "$1"
    flag_processed=1
  fi
  [[ $flag_processed ]] && return 0

  # -p
  if [[ $opt_p ]]; then
    ble/builtin/history/option:p "$@"
  else
    builtin history "$@"
  fi
}
function history { ble/builtin/history "$@"; }

function ble-edit/reset-history {
  if ((_ble_bash>=40000)); then
    _ble_edit_history_loaded=
    ble-edit/history/clear-background-load
    ble/util/idle.push 'ble-edit/history/initialize async'
  elif ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
    _ble_edit_history_loaded=
  else
    # * history-load は initialize ではなく attach で行う。
    #   detach してから attach する間に
    #   追加されたエントリがあるかもしれないので。
    # * bash-3.0 では history -s は最近の履歴項目を置換するだけなので、
    #   履歴項目は全て自分で処理する必要がある。
    #   つまり、初めから load しておかなければならない。
    ble-edit/history/initialize
  fi
}
