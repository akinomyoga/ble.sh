#!/bin/bash

## オプション history_limit_length
##   履歴に登録するコマンドの最大文字数を指定します。
##   この値を超える長さのコマンドは履歴に登録されません。
bleopt/declare -v history_limit_length 10000

#==============================================================================
# ble/history:bash                                                @history.bash

## @arr _ble_history
##   コマンド履歴項目を保持する。
##
## @arr _ble_history_edit
## @arr _ble_history_dirt
##   _ble_history_edit 編集されたコマンド履歴項目を保持する。
##   _ble_history の各項目と対応し、必ず同じ数・添字の要素を持つ。
##   _ble_history_dirt は編集されたかどうかを保持する。
##   _ble_history の各項目と対応し、変更のあったい要素にのみ値 1 を持つ。
##
## @var _ble_history_ind
##   現在の履歴項目の番号
##
_ble_history=()
_ble_history_edit=()
_ble_history_dirt=()
_ble_history_ind=0

## @var _ble_history_count
##   現在の履歴項目の総数
##
## これらの変数はコマンド履歴を対象としているときにのみ用いる。
##
_ble_history_count=

function ble/builtin/history/is-empty {
  # Note: 状況によって history -p で項目が減少するので
  #  サブシェルの中で評価する必要がある。
  #  但し、サブシェルの中に既にいる時にはこの fork は省略できる。
  #  Bash 3.2 以前ではサブシェルの中にいるかどうかの判定自体に
  #  fork&exec が必要になるので常にサブシェルで評価する。
  if ((_ble_base<40000)) || [[ $BASHPID == "$$" ]]; then
    (! builtin history -p '!!')
  else
    ! builtin history -p '!!'
  fi
} &>/dev/null
function ble/builtin/history/.get-min {
  ble/util/assign min 'builtin history | head -1'
  ble/string#split-words min "$min"
}
function ble/builtin/history/.get-max {
  ble/util/assign max 'builtin history 1'
  ble/string#split-words max "$max"
}

function ble/history:bash/update-count {
  [[ $_ble_history_count ]] && return 0
  if [[ $_ble_history_load_done ]]; then
    _ble_history_count=${#_ble_history[@]}
  else
    local min max
    ble/builtin/history/.get-min
    ble/builtin/history/.get-max
    ((_ble_history_count=max-min+1))
  fi
}

#------------------------------------------------------------------------------
# initialize _ble_history                                    @history.bash.load

## @var _ble_history_load_done
_ble_history_load_done=

# @hook history_reset_background (defined in def.sh)
function ble/history:bash/clear-background-load {
  blehook/invoke history_reset_background
}

## 関数 ble/history:bash/load
if ((_ble_bash>=40000)); then
  # _ble_bash>=40000 で利用できる以下の機能に依存する
  #   ble/util/is-stdin-ready (via ble/util/idle/IS_IDLE)
  #   ble/util/mapfile

  _ble_history_load_resume=0
  _ble_history_load_bgpid=

  # history > tmp
  ## 関数 ble/history:bash/load/.background-initialize
  ##   @var[in] arg_count
  function ble/history:bash/load/.background-initialize {
    if ble/builtin/history/is-empty; then
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
    local HISTTIMEFORMAT=__ble_ext__
    local -x INDEX_FILE=$history_indfile
    local opt_cygwin=; [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && opt_cygwin=1

    local apos=\'
    # 482ms for 37002 entries
    builtin history $arg_count | ble/bin/awk -v apos="$apos" -v opt_cygwin="$opt_cygwin" '
      BEGIN {
        n = 0;
        hindex = 0;
        INDEX_FILE = ENVIRON["INDEX_FILE"];
        printf("") > INDEX_FILE; # create file
        if (opt_cygwin) print "_ble_history=(";
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

  ## 関数 ble/history:bash/load opts
  ##   @param[in] opts
  ##     async
  ##       非同期で読み取ります。
  ##     append
  ##       現在読み込み済みの履歴情報に追加します。
  ##     offset=NUMBER
  ##       _ble_history 配列の途中から書き込みます。
  ##     count=NUMBER
  ##       最近の NUMBER 項目だけ読み取ります。
  function ble/history:bash/load {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1
    local opt_cygwin=; [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && opt_cygwin=1

    local arg_count= arg_offset=0
    if [[ :$opts: == *:append:* ]]; then
      arg_offset=${#_ble_history[@]}
    elif local rex=':offset=([0-9]+):'; [[ :$opts: =~ $rex ]]; then
      arg_offset=${BASH_REMATCH[1]}
    fi
    local rex=':count=([0-9]+):'; [[ :$opts: =~ $rex ]] && arg_count=${BASH_REMATCH[1]}

    local history_tmpfile=$_ble_base_run/$$.history.load
    local history_indfile=$_ble_base_run/$$.history.multiline-index
    [[ $opt_async || :$opts: == *:init:* ]] || _ble_history_load_resume=0

    [[ ! $opt_async ]] && ((_ble_history_load_resume<6)) &&
      blehook/invoke history_message "loading history ..."
    while :; do
      case $_ble_history_load_resume in

      # 42ms 履歴の読み込み
      (0) # 履歴ファイル生成を Background で開始
          if [[ $_ble_history_load_bgpid ]]; then
            builtin kill -9 "$_ble_history_load_bgpid" &>/dev/null
            _ble_history_load_bgpid=
          fi

          : >| "$history_tmpfile"
          if [[ $opt_async ]]; then
            _ble_history_load_bgpid=$(
              shopt -u huponexit; ble/history:bash/load/.background-initialize </dev/null &>/dev/null & ble/util/print $!)

            function ble/history:bash/load/.background-initialize-completed {
              local history_tmpfile=$_ble_base_run/$$.history.load
              [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_history_load_bgpid"
            } &>/dev/null

            ((_ble_history_load_resume++))
          else
            ble/history:bash/load/.background-initialize
            ((_ble_history_load_resume+=3))
          fi ;;

      # 515ms ble/history:bash/load/.background-initialize 待機
      (1) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble/history:bash/load/.background-initialize-completed
            ((_ble_history_load_resume++))
            return 147
          fi
          ((_ble_history_load_resume++)) ;;

      # Note: async でバックグラウンドプロセスを起動した後に、直接 (sync で)
      #   呼び出された時、未だ処理が完了していなくても次のステップに進んでしまうので、
      #   此処で条件が満たされるのを待つ (#D0745)
      (2) while ! ble/history:bash/load/.background-initialize-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
          done
          ((_ble_history_load_resume++)) ;;

      # 47ms _ble_history 初期化 (37000項目)
      (3) _ble_history_load_bgpid=
          if [[ $opt_cygwin ]]; then
            # 620ms Cygwin (99000項目) cf #D0701
            source "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t _ble_history < "$history_tmpfile"
          fi
          ((_ble_history_load_resume++)) ;;

      # 47ms _ble_history_edit 初期化 (37000項目)
      (4) if [[ $opt_cygwin ]]; then
            # 504ms Cygwin (99000項目)
            _ble_history_edit=("${_ble_history[@]}")
          else
            builtin mapfile -O "$arg_offset" -t _ble_history_edit < "$history_tmpfile"
          fi
          : >| "$history_tmpfile"
          ((_ble_history_load_resume++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (5) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            ((i+=arg_offset))
            [[ ${_ble_history[i]} =~ $rex ]] &&
              builtin eval "_ble_history[i]=${_ble_history[i]:8}"
          done
          ((_ble_history_load_resume++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (6) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          for i in "${indices_to_fix[@]}"; do
            ((i+=arg_offset))
            [[ ${_ble_history_edit[i]} =~ $rex ]] &&
              builtin eval "_ble_history_edit[i]=${_ble_history_edit[i]:8}"
          done

          [[ $opt_async ]] || blehook/invoke history_message

          ((_ble_history_load_resume++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
    done
  }
  blehook history_reset_background+=_ble_history_load_resume=0
else
  function ble/history:bash/load/.generate-source {
    if ble/builtin/history/is-empty; then
      # rcfile として起動すると history が未だロードされていない。
      builtin history -n
    fi
    local HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    builtin history $arg_count | ble/bin/awk -v apos="'" '
      BEGIN { n = ""; }

      # 何故かタイムスタンプがコマンドとして読み込まれてしまう
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)#[0-9]/ { next; }

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

        # 対策 #D1239: bash-3.2 以前では ^A, ^? が ^A^A, ^A^? に化ける
        gsub(/\001/, "'$apos'${_ble_term_SOH}'$apos'", line);
        gsub(/\177/, "'$apos'${_ble_term_DEL}'$apos'", line);

        # 対策 #D1270: MSYS2 で ^M を代入すると消える
        gsub(/\015/, "'$apos'${_ble_term_CR}'$apos'", line);

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

  function ble/history:bash/load {
    local opts=$1
    local opt_append=
    [[ :$opts: == *:append:* ]] && opt_append=1

    local arg_count= rex=':count=([0-9]+):'
    [[ :$opts: =~ $rex ]] && arg_count=${BASH_REMATCH[1]}

    blehook/invoke history_message "loading history..."

    # * プロセス置換にしてもファイルに書き出しても大した違いはない。
    #   270ms for 16437 entries (generate-source の時間は除く)
    # * プロセス置換×source は bash-3 で動かない。eval に変更する。
    local result=$(ble/history:bash/load/.generate-source)
    if [[ $opt_append ]]; then
      if ((_ble_bash>=30100)); then
        builtin eval -- "_ble_history+=($result)"
        builtin eval -- "_ble_history_edit+=($result)"
      else
        local -a A; builtin eval -- "A=($result)"
        _ble_history=("${_ble_history[@]}" "${A[@]}")
        _ble_history_edit=("${_ble_history[@]}" "${A[@]}")
      fi
    else
      builtin eval -- "_ble_history=($result)"
      _ble_history_edit=("${_ble_history[@]}")
    fi

    blehook/invoke history_message
  }
fi

function ble/history:bash/initialize {
  [[ $_ble_history_load_done ]] && return 0
  ble/history:bash/load "init:$@"; local ext=$?
  ((ext)) && return "$ext"

  local old_count=$_ble_history_count new_count=${#_ble_history[@]}
  _ble_history_load_done=1
  _ble_history_count=$new_count
  _ble_history_ind=$_ble_history_count

  # Note: 追加読み込みをした際に対応するデータを shift (history_share)
  local delta=$((new_count-old_count))
  ((delta>0)) && blehook/invoke history_insert "$old_count" "$delta"
}

#------------------------------------------------------------------------------
# Bash history resolve-multiline                            @history.bash.mlfix

if ((_ble_bash>=30100)); then
  # Note: Bash 3.0 では history -s がまともに動かないので
  # 複数行の履歴項目を builtin history に追加する方法が今の所不明である。

  _ble_history_mlfix_done=
  _ble_history_mlfix_resume=0
  _ble_history_mlfix_bgpid=

  ## 関数 ble/history:bash/resolve-multiline/.awk reason
  ##
  ##   @param[in] reason
  ##     呼び出しの用途を指定する文字列です。
  ##
  ##     resolve ... 初期化時の history 再構築
  ##       history コマンドの出力形式で標準入力を解析します。
  ##       各行は '番号 HISTTIMEFORMATコマンド' の形式をしている。
  ##
  ##     read    ... history -r によるファイルからの読み出し
  ##       履歴ファイルの形式で標準入力を解析します。
  ##       各行は '#%s' または 'コマンド' の形式をしている。
  ##       ble.sh では先頭行が '#%s' の時の複数行モードには対応しない。
  ##
  ##   @var[in] TMPBASE
  function ble/history:bash/resolve-multiline/.awk {
    if ((_ble_bash>=50000)); then
      local -x epoch=$EPOCHSECONDS
    elif ((_ble_bash>=40400)); then
      local -x epoch
      ble/util/strftime -v epoch %s
    fi

    local -x reason=$1
    local apos=\'
    ble/bin/awk -v apos="$apos" -v _ble_bash="$_ble_bash" '
      BEGIN {
        q = apos;
        Q = apos "\\" apos apos;
        reason = ENVIRON["reason"];
        is_resolve = reason == "resolve";

        TMPBASE = ENVIRON["TMPBASE"];
        filename_source = TMPBASE ".part";
        if (is_resolve)
          print "builtin history -c" > filename_source

        entry_nline = 0;
        entry_text = "";
        entry_time = "";
        if (_ble_bash >= 40400)
          entry_time = ENVIRON["epoch"];

        command_count = 0;

        multiline_count = 0;
        modification_count = 0;
        read_section_count = 0;
      }
  
      function write_flush(_, i, filename_section, t, c) {
        if (command_count == 0) return;
        if (command_count >= 2 || entry_time) {
          filename_section = TMPBASE "." read_section_count++ ".part";
          for (i = 0; i < command_count; i++) {
            t = command_time[i];
            c = command_text[i];
            if (t) print "#" t > filename_section;
            print c > filename_section;
          }
          # Note: HISTTIMEFORMAT を指定するのは bash-4.4 で複数行読み取りを有効にする為。
          print "HISTTIMEFORMAT=%s builtin history -r " filename_section > filename_source;
        } else {
          for (i = 0; i < command_count; i++) {
            c = command_text[i];
            gsub(/'$apos'/, Q, c);
            print "builtin history -s -- " q c q > filename_source;
          }
        }
        command_count = 0;
      }
      function write_complex(value) {
        write_flush();
        print "builtin history -s -- " value > filename_source;
      }

      function register_command(cmd) {
        command_time[command_count] = entry_time;
        command_text[command_count] = cmd;
        command_count++;
      }

      function is_escaped_command(cmd) {
        return cmd ~ /^eval -- \$'$apos'([^'$apos'\\]|\\[\\'$apos'nt])*'$apos'$/;
      }
      function unescape_command(cmd) {
        cmd = substr(cmd, 11, length(cmd) - 11);
        gsub(/\\\\/, "\\q", cmd);
        gsub(/\\n/, "\n", cmd);
        gsub(/\\t/, "\t", cmd);
        gsub(/\\'$apos'/, "'$apos'", cmd);
        gsub(/\\q/, "\\", cmd);
        return cmd;
      }
      function register_escaped_command(cmd) {
        multiline_count++;
        modification_count++;
        if (_ble_bash >= 40400) {
          register_command(unescape_command(cmd));
        } else {
          write_complex(substr(cmd, 9));
        }
      }

      function register_multiline_command(cmd) {
        multiline_count++;
        if (_ble_bash >= 40040) {
          register_command(cmd);
        } else {
          gsub(/'$apos'/, Q, cmd);
          write_complex(q cmd q);
        }
      }
  
      function flush_entry() {
        if (entry_nline < 1) return;

        if (is_escaped_command(entry_text)) {
          register_escaped_command(entry_text)
        } else if (entry_nline > 1) {
          register_multiline_command(entry_text);
        } else {
          register_command(entry_text);
        }
  
        entry_nline = 0;
        entry_text = "";
      }

      function save_timestamp(line) {
        if (is_resolve) {
          # "history" format
          if (line ~ /^ *[0-9]+\*? +__ble_time_[0-9]+__/) {
            sub(/^ *[0-9]+\*? +__ble_time_/, "", line);
            sub(/__.*$/, "", line);
            entry_time = line;
          }
        } else {
          # "history -w" format
          if (line ~ /^#[0-9]/) {
            sub(/^#/, "", line);
            sub(/[^0-9].*$/, "", line);
            entry_time = line;
          }
        }
      }
  
      {
        if (is_resolve) {
          save_timestamp($0);
          if (sub(/^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?)/, "", $0))
            flush_entry();
          entry_text = ++entry_nline == 1 ? $0 : entry_text "\n" $0;
        } else {
          if ($0 ~ /^#[0-9]/) {
            save_timestamp($0);
            next;
          } else {
            flush_entry();
            entry_text = $0;
            entry_nline = 1;
          }
        }
      }
  
      END {
        flush_entry();
        write_flush();
        if (is_resolve)
          print "builtin history -a /dev/null" > filename_source
        print "multiline_count=" multiline_count;
        print "modification_count=" modification_count;
      }
    '
  }
  ## 関数 ble/history:bash/resolve-multiline/.cleanup
  ##   @var[in] TMPBASE
  function ble/history:bash/resolve-multiline/.cleanup {
    local file
    for file in "$TMPBASE".*; do : >| "$file"; done
  }
  function ble/history:bash/resolve-multiline/.worker {
    local HISTTIMEFORMAT=__ble_time_%s__
    local -x TMPBASE=$_ble_base_run/$$.history.mlfix
    local multiline_count=0 modification_count=0
    builtin eval -- "$(builtin history | ble/history:bash/resolve-multiline/.awk resolve 2>/dev/null)"
    if ((modification_count)); then
      ble/bin/mv -f "$TMPBASE.part" "$TMPBASE.sh"
    else
      ble/util/print : >| "$TMPBASE.sh"
    fi
  }
  function ble/history:bash/resolve-multiline/.load {
    local TMPBASE=$_ble_base_run/$$.history.mlfix
    local HISTCONTROL= HISTSIZE= HISTIGNORE=
    source "$TMPBASE.sh"
    ble/history:bash/resolve-multiline/.cleanup
  }

  ## 関数 ble/history:bash/resolve-multiline opts
  ##   @param[in] opts
  ##     async
  ##       非同期で読み取ります。
  function ble/history:bash/resolve-multiline.impl {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1

    local history_tmpfile=$_ble_base_run/$$.history.mlfix.sh
    [[ $opt_async || :$opts: == *:init:* ]] || _ble_history_mlfix_resume=0

    [[ ! $opt_async ]] && ((_ble_history_mlfix_resume<=4)) &&
      blehook/invoke history_message "resolving multiline history ..."
    while :; do
      case $_ble_history_mlfix_resume in

      (0) if [[ $opt_async ]] && ble/builtin/history/is-empty; then
            # Note: bashrc の中では resolve-multiline はしない。
            #   一旦 bash が履歴を読み込んだ後に再度試す。
            ble/util/idle.wait-user-input
            ((_ble_history_mlfix_resume++))
            return 147
          fi
          ((_ble_history_mlfix_resume++)) ;;

      (1) # 履歴ファイル生成を Background で開始
        if [[ $_ble_history_mlfix_bgpid ]]; then
          builtin kill -9 "$_ble_history_mlfix_bgpid" &>/dev/null
          _ble_history_mlfix_bgpid=
        fi

        : >| "$history_tmpfile"
        if [[ $opt_async ]]; then
          _ble_history_mlfix_bgpid=$(
            shopt -u huponexit; ble/history:bash/resolve-multiline/.worker </dev/null &>/dev/null & ble/util/print $!)

          function ble/history:bash/resolve-multiline/.worker-completed {
            local history_tmpfile=$_ble_base_run/$$.history.mlfix.sh
            [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_history_mlfix_bgpid"
          } &>/dev/null

          ((_ble_history_mlfix_resume++))
        else
          ble/history:bash/resolve-multiline/.worker
          ((_ble_history_mlfix_resume+=3))
        fi ;;

      (2) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble/history:bash/resolve-multiline/.worker-completed
            ((_ble_history_mlfix_resume++))
            return 147
          fi
          ((_ble_history_mlfix_resume++)) ;;

      # Note: async でバックグラウンドプロセスを起動した後に、直接 (sync で)
      #   呼び出された時、未だ処理が完了していなくても次のステップに進んでしまうので、
      #   此処で条件が満たされるのを待つ (#D0745)
      (3) while ! ble/history:bash/resolve-multiline/.worker-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
          done
          ((_ble_history_mlfix_resume++)) ;;

      # 80ms history 再構築 (47000項目)
      (4) _ble_history_mlfix_bgpid=
          ble/history:bash/resolve-multiline/.load
          [[ $opt_async ]] || blehook/invoke history_message
          ((_ble_history_mlfix_resume++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
    done
  }

  function ble/history:bash/resolve-multiline {
    [[ $_ble_history_mlfix_done ]] && return 0
    if [[ $1 == sync ]]; then
      ((_ble_bash>=40000)) && [[ $BASHPID != $$ ]] && return 0
      ble/builtin/history/is-empty && return 0
    fi

    ble/history:bash/resolve-multiline.impl "$@"; local ext=$?
    ((ext)) && return "$ext"
    _ble_history_mlfix_done=1
    return 0
  }
  ((_ble_bash>=40000)) &&
    ble/util/idle.push 'ble/history:bash/resolve-multiline async'

  blehook history_reset_background+=_ble_history_mlfix_resume=0

  function ble/history:bash/resolve-multiline/readfile {
    local filename=$1
    local -x TMPBASE=$_ble_base_run/$$.history.read
    ble/history:bash/resolve-multiline/.awk read < "$filename" &>/dev/null
    source "$TMPBASE.part"
    ble/history:bash/resolve-multiline/.cleanup
  }
fi

# Note: 複数行コマンドは eval -- $'' の形に変換して
#   書き込みたいので自前で処理する。
function ble/history:bash/TRAPEXIT {
  ble/util/is-running-in-subshell && return 0
  if shopt -q histappend &>/dev/null; then
    ble/builtin/history -a
  else
    ble/builtin/history -w
  fi
}
blehook EXIT+=ble/history:bash/TRAPEXIT

function ble/history:bash/reset {
  if ((_ble_bash>=40000)); then
    _ble_history_load_done=
    ble/history:bash/clear-background-load
    ble/util/idle.push 'ble/history:bash/initialize async'
  elif ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
    _ble_history_load_done=
  else
    # * history-load は initialize ではなく attach で行う。
    #   detach してから attach する間に
    #   追加されたエントリがあるかもしれないので。
    # * bash-3.0 では history -s は最近の履歴項目を置換するだけなので、
    #   履歴項目は全て自分で処理する必要がある。
    #   つまり、初めから load しておかなければならない。
    ble/history:bash/initialize
  fi
}


#------------------------------------------------------------------------------
# ble/builtin/history                                     @history.bash.builtin

function ble/builtin/history/.touch-histfile {
  local touch=$_ble_base_run/$$.history.touch
  : >| "$touch"
}

# in def.sh
# @hook history_delete
# @hook history_clear
# @hook history_message

# Note: #D1126 一度置き換えたら戻せない。二回は初期化しない。
if [[ ! ${_ble_builtin_history_initialized+set} ]]; then
  _ble_builtin_history_initialized=
  _ble_builtin_history_histnew_count=0
  _ble_builtin_history_histapp_count=0
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
      # Note: 当初 ((dict[\$file]+=$2)) の形式を使っていたが、これは
      #   shopt -s assoc_expand_once の場合に動作しない事が判明したので、
      #   一旦、別の変数で計算してから代入する事にする。
      local value=${_ble_builtin_history_rskip_dict[$file]}
      ((value+=$2))
      _ble_builtin_history_rskip_dict[$file]=$value
    }
  else
    _ble_builtin_history_rskip_path=()
    _ble_builtin_history_rskip_skip=()
    function ble/builtin/history/.find-rskip-index {
      local file=$1
      local n=${#_ble_builtin_history_rskip_path[@]}
      for ((index=0;index<n;index++)); do
        [[ $file == ${_ble_builtin_history_rskip_path[index]} ]] && return 0
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
fi

## 関数 ble/builtin/history/.initialize opts
##   @param[in] opts
##     skip0 ... 履歴が一件も読み込まれていない時はスキップします。
function ble/builtin/history/.initialize {
  [[ $_ble_builtin_history_initialized ]] && return 0
  local line; ble/util/assign line 'builtin history 1'
  [[ ! $line && :$1: == *:skip0:* ]] && return 1
  _ble_builtin_history_initialized=1

  local histnew=$_ble_base_run/$$.history.new
  : >| "$histnew"

  if [[ $line ]]; then
    # Note: #D1126 ble.sh ロード前に追加された履歴項目があれば保存する。
    local histini=$_ble_base_run/$$.history.ini
    local histapp=$_ble_base_run/$$.history.app
    HISTTIMEFORMAT=1 builtin history -a "$histini"
    if [[ -s $histini ]]; then
      ble/bin/sed '/^#\([0-9].*\)/{s//    0  __ble_time_\1__/;N;s/\n//;}' "$histini" >> "$histapp"
      : >| "$histini"
    fi
  else
    # 履歴が読み込まれていなければ強制的に読み込む
    ble/builtin/history/option:r
  fi

  local histfile=${HISTFILE:-$HOME/.bash_history}
  local rskip=$(ble/bin/wc -l "$histfile" 2>/dev/null)
  ble/string#split-words rskip "$rskip"
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((max&&max-min+1<rskip&&(rskip=max-min+1)))
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
  ble/builtin/history/.set-rskip "$histfile" "$rskip"
  return 0
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
## 関数 ble/builtin/history/.load-recent-entries count
##   history の最新 count 件を配列 _ble_history に読み込みます。
function ble/builtin/history/.load-recent-entries {
  [[ $_ble_decode_bind_state == none ]] && return 0

  local delta=$1
  ((delta>0)) || return 0

  if [[ ! $_ble_history_load_done ]]; then
    # history load が完了していなければ読み途中のデータを破棄して戻る
    ble/history:bash/clear-background-load
    _ble_history_count=
    return 0
  fi

  # 追加項目が大量にある場合には background で完全再初期化する
  if ((_ble_bash>=40000&&delta>=10000)); then
    ble/history:bash/reset
    return 0
  fi

  ble/history:bash/load append:count=$delta

  local ocount=$_ble_history_count ncount=${#_ble_history[@]}
  ((_ble_history_ind==_ble_history_count)) && _ble_history_ind=$ncount
  _ble_history_count=$ncount
  blehook/invoke history_insert "$ocount" "$delta"
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
    builtin eval -- "$script"
  else
    ble/builtin/history/.set-rskip "$file" 0
  fi
  if [[ ! $fetch && -s $histnew ]]; then
    local nline=$_ble_builtin_history_histnew_count
    ble/history:bash/resolve-multiline/readfile "$histnew"
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
  declare -p HISTTIMEFORMAT &>/dev/null
  local -x flag_timestamp=$(($?==0))

  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((skip<min-1&&(skip=min-1)))
  local delta=$((max-skip))
  if ((delta>0)); then
    local HISTTIMEFORMAT=__ble_time_%s__
    if [[ :$opts: == *:append:* ]]; then
      builtin history "$delta" >> "$histapp"
      ((_ble_builtin_history_histapp_count+=delta))
    else
      builtin history "$delta" >| "$histapp"
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
      BEGIN {
        file = ENVIRON["file"];
        flag_timestamp = ENVIRON["flag_timestamp"];
        timestamp = "";
        mode = 0;
      }
      function flush_line() {
        if (!mode) return;
        mode = 0;
        if (text ~ /\n/) {
          gsub(/['$apos'\\]/, "\\\\&", text);
          gsub(/\n/, "\\n", text);
          gsub(/\t/, "\\t", text);
          text = "eval -- $'$apos'" text "'$apos'"
        }

        if (timestamp != "")
          print timestamp >> file;
        print text >> file;
      }

      function extract_timestamp(line) {
        if (!sub(/^ *[0-9]+\*? +__ble_time_/, "", line)) return "";
        if (!sub(/__.*$/, "", line)) return "";
        if (!(line ~ /^[0-9]+$/)) return "";
        return "#" line;
      }

      /^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?)?/ {
        flush_line();

        mode = 1;
        text = "";
        if (flag_timestamp)
          timestamp = extract_timestamp($0);

        sub(/^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?)?/, "", $0);
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
  builtin eval -- "${script//ARRAY/$array_name}"
}
## 関数 ble/builtin/history/array#insert-range array_name beg len
function ble/builtin/history/array#insert-range {
  local array_name=$1 beg=$2 len=$3
  local script='
    local -a out=()
    local i
    for i in "${!ARRAY[@]}"; do
      out[i<beg?beg:i+len]=${ARRAY[i]}
    done
    ARRAY=()
    for i in "${!out[@]}"; do ARRAY[i]=${out[i]}; done'
  builtin eval -- "${script//ARRAY/$array_name}"
}
blehook history_delete+=ble/builtin/history/delete.hook
blehook history_clear+=ble/builtin/history/clear.hook
blehook history_insert+=ble/builtin/history/insert.hook
function ble/builtin/history/delete.hook {
  ble/builtin/history/array#delete-hindex _ble_history_dirt "$@"
}
function ble/builtin/history/clear.hook {
  _ble_history_dirt=()
}
function ble/builtin/history/insert.hook {
  # Note: _ble_history, _ble_history_edit は別に更新される
  ble/builtin/history/array#insert-range _ble_history_dirt "$@"
}
## 関数 ble/builtin/history/option:c
function ble/builtin/history/option:c {
  ble/builtin/history/.initialize skip0 || return "$?"
  builtin history -c
  _ble_builtin_history_wskip=0
  _ble_builtin_history_prevmax=0
  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_history_load_done ]]; then
      _ble_history=()
      _ble_history_edit=()
      _ble_history_count=0
      _ble_history_ind=0
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
    blehook/invoke history_clear
  fi
}
## 関数 ble/builtin/history/option:d index
function ble/builtin/history/option:d {
  ble/builtin/history/.initialize skip0 || return "$?"
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
    if [[ $_ble_history_load_done ]]; then
      local N=${#_ble_history[@]}
      local b=$((beg-1+N-max)) e=$((end+N-max))
      blehook/invoke history_delete "$b-$e"
      if ((_ble_history_ind>=e)); then
        ((_ble_history_ind-=e-b))
      elif ((_ble_history_ind>=b)); then
        _ble_history_ind=$b
      fi
      _ble_history=("${_ble_history[@]::b}" "${_ble_history[@]:e}")
      _ble_history_edit=("${_ble_history_edit[@]::b}" "${_ble_history_edit[@]:e}")
      _ble_history_count=${#_ble_history[@]}
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
## 関数 ble/builtin/history/option:a [filename]
function ble/builtin/history/option:a {
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
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
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile=${HISTFILE:-$HOME/.bash_history}
  local filename=${1:-$histfile}
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
  # Note: auto-complete .search-history-light や
  #   magic-space 等経由で history -p が呼び出されて、
  #   その時に resolve-multiline が sync されると引っ掛かる。
  #   従って history -p では sync しない事に決めた (#D1121)
  # Note: bash-3 では background load ができないので
  #   最初に history -p が呼び出されるタイミングで初期化する事にする (#D1122)
  ((_ble_bash>=40000)) || ble/builtin/history/is-empty ||
    ble/history:bash/resolve-multiline sync

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
  ble/builtin/history/.initialize
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin history -s -- "$@"
    return 0
  fi

  local cmd=$1
  if [[ $HISTIGNORE ]]; then
    local pats pat
    ble/string#split pats : "$HISTIGNORE"
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return 0
    done
  fi

  local histfile=
  if [[ $_ble_history_load_done ]]; then
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
        [[ $cmd == [' 	']* ]] && return 0
      fi
      if [[ $ignoredups ]]; then
        local lastIndex=$((${#_ble_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_history[lastIndex]}" ]] && return 0
      fi
      if [[ $erasedups ]]; then
        local -a delete_indices=()
        local shift_histindex_next=0
        local shift_wskip=0
        local i N=${#_ble_history[@]}
        for ((i=0;i<N-1;i++)); do
          if [[ ${_ble_history[i]} == "$cmd" ]]; then
            builtin unset -v '_ble_history[i]'
            builtin unset -v '_ble_history_edit[i]'
            ble/array#push delete_indices "$i"
            ((i<_ble_builtin_history_wskip&&shift_wskip++))
            ((i<HISTINDEX_NEXT&&shift_histindex_next++))
          fi
        done
        if ((${#delete_indices[@]})); then
          _ble_history=("${_ble_history[@]}")
          _ble_history_edit=("${_ble_history_edit[@]}")
          blehook/invoke history_delete "${delete_indices[@]}"
          ((_ble_builtin_history_wskip-=shift_wskip))
          [[ ${HISTINDEX_NEXT+set} ]] && ((HISTINDEX_NEXT-=shift_histindex_next))
        fi
        ((N)) && [[ ${_ble_history[N-1]} == "$cmd" ]] && return 0
      fi
    fi
    local topIndex=${#_ble_history[@]}
    _ble_history[topIndex]=$cmd
    _ble_history_edit[topIndex]=$cmd
    _ble_history_count=$((topIndex+1))
    _ble_history_ind=$_ble_history_count

    # _ble_bash<30100 の時は必ずここを通る。
    # 初期化時に _ble_history_load_done=1 になるので。
    ((_ble_bash<30100)) && histfile=${HISTFILE:-$HOME/.bash_history}
  else
    if [[ $HISTCONTROL ]]; then
      # 未だ履歴が初期化されていない場合は取り敢えず history -s に渡す。
      # history -s でも HISTCONTROL に対するフィルタはされる。
      # history -s で項目が追加されたかどうかはスクリプトからは分からないので
      # _ble_history_count は一旦クリアする。
      _ble_history_count=
    else
      # HISTCONTROL がなければ多分 history -s で必ず追加される。
      # _ble_history_count 取得済ならば更新。
      [[ $_ble_history_count ]] &&
        ((_ble_history_count++))
    fi
  fi

  if [[ $histfile ]]; then
    # bash < 3.1 workaround
    if [[ $cmd == *$'\n'* ]]; then
      # Note: 改行を含む場合は %q は常に $'' の形式になる。
      ble/util/sprintf cmd 'eval -- %q' "$cmd"
    fi
    local tmp=$_ble_base_run/$$.history.tmp
    [[ $bleopt_history_share ]] ||
      builtin printf '%s\n' "$cmd" >> "$histfile"
    builtin printf '%s\n' "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble/history:bash/clear-background-load
    builtin history -s -- "$cmd"
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history {
  local opt_d= flag_error=
  local opt_c= opt_p= opt_s=
  local opt_a= flags=
  while [[ $1 == -* ]]; do
    local arg=$1; shift
    [[ $arg == -- ]] && break

    if [[ $arg == --help ]]; then
      flags=h$flags
      continue
    fi

    local i n=${#arg}
    for ((i=1;i<n;i++)); do
      local c=${arg:i:1}
      case $c in
      (c) opt_c=1 ;;
      (s) opt_s=1 ;;
      (p) opt_p=1 ;;
      (d)
        if ((!$#)); then
          ble/util/print 'ble/builtin/history: missing option argument for "-d".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_d=${arg:i+1}; i=$n
        else
          opt_d=$1; shift
        fi ;;
      ([anwr])
        if [[ $opt_a && $c != $opt_a ]]; then
          ble/util/print 'ble/builtin/history: cannot use more than one of "-anrw".' >&2
          flag_error=1
        elif ((i+1<n)); then
          opt_a=$c
          set -- "${arg:i+1}" "$@"
        else
          opt_a=$c
        fi ;;
      (*)
        ble/util/print "ble/builtin/history: unknown option \"-$c\"." >&2
        flag_error=1 ;;
      esac
    done
  done
  [[ $flag_error ]] && return 2

  if [[ $flags == *h* ]]; then
    builtin history --help
    return "$?"
  fi

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

#==============================================================================
# ble/history                                                          @history

## @var _ble_history_prefix
##
##   現在どの履歴を対象としているかを保持する。
##   空文字列の時、コマンド履歴を対象とする。以下の変数を用いる。
##
##     _ble_history
##     _ble_history_ind
##     _ble_history_edit
##     _ble_history_dirt
##
##   空でない文字列 prefix のとき、以下の変数を操作対象とする。
##
##     ${prefix}_history
##     ${prefix}_history_ind
##     ${prefix}_history_edit
##     ${prefix}_history_dirt
##
##   何れの関数も _ble_history_prefix を適切に処理する必要がある。
##
##   実装のために配列 _ble_history_edit などを
##   ローカルに定義して処理するときは、以下の注意点を守る必要がある。
##
##   - その関数自身またはそこから呼び出される関数が、
##     履歴項目に対して副作用を持ってはならない。
##
##   この要請の下で、各関数は呼び出し元のすり替えを意識せずに動作できる。
##
_ble_history_prefix=

## @hook history_onleave (defined in def.sh)

function ble/history/onleave.fire {
  blehook/invoke history_onleave "$@"
}

## called by ble-edit/initialize in Bash 3
function ble/history/initialize {
  [[ ! $_ble_history_prefix ]] &&
    ble/history:bash/initialize
}
function ble/history/get-count {
  local _var=count _ret
  [[ $1 == -v ]] && { _var=$2; shift 2; }

  if [[ $_ble_history_prefix ]]; then
    builtin eval "_ret=\${#${_ble_history_prefix}_history[@]}"
  else
    ble/history:bash/update-count
    _ret=$_ble_history_count
  fi

  (($_var=_ret))
}
function ble/history/get-index {
  local _var=index
  [[ $1 == -v ]] && { _var=$2; shift 2; }
  if [[ $_ble_history_prefix ]]; then
    (($_var=${_ble_history_prefix}_history_ind))
  elif [[ $_ble_history_load_done ]]; then
    (($_var=_ble_history_ind))
  else
    ble/history/get-count -v "$_var"
  fi
}
function ble/history/set-index {
  local index=$1
  ((${_ble_history_prefix:-_ble}_history_ind=index))
}
function ble/history/get-entry {
  ble/history/initialize
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  builtin eval "$__var=\${${_ble_history_prefix:-_ble}_history[\$1]}"
}
function ble/history/get-editted-entry {
  ble/history/initialize
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  builtin eval "$__var=\${${_ble_history_prefix:-_ble}_history_edit[\$1]}"
}
## 関数 ble/history/set-editted-entry index str
function ble/history/set-editted-entry {
  ble/history/initialize
  local index=$1 str=$2
  local code='
    # store
    if [[ ${PREFIX_history_edit[index]} != "$str" ]]; then
      PREFIX_history_edit[index]=$str
      PREFIX_history_dirt[index]=1
    fi'
  builtin eval -- "${code//PREFIX/${_ble_history_prefix:-_ble}}"
}

# @var[in,out] HISTINDEX_NEXT
#   used by ble/widget/accept-and-next to get modified next-entry positions
function ble/history/.add-command-history {
  # 注意: bash-3.2 未満では何故か bind -x の中では常に history off になっている。
  [[ -o history ]] || ((_ble_bash<30200)) || return 1

  if [[ $_ble_history_load_done ]]; then
    # 登録・不登録に拘わらず取り敢えず初期化
    _ble_history_ind=${#_ble_history[@]}

    # _ble_history_edit を未編集状態に戻す
    local index
    for index in "${!_ble_history_dirt[@]}"; do
      _ble_history_edit[index]=${_ble_history[index]}
    done
    _ble_history_dirt=()

    # 同時に _ble_edit_undo も初期化する。
    ble-edit/undo/clear-all
  fi

  if [[ $bleopt_history_share ]]; then
    ble/builtin/history/option:n
    ble/builtin/history/option:s "$1"
    ble/builtin/history/option:a
    ble/builtin/history/.touch-histfile
  else
    ble/builtin/history/option:s "$1"
  fi
}

function ble/history/add {
  local command=$1
  ((bleopt_history_limit_length>0&&${#command}>bleopt_history_limit_length)) && return 1

  if [[ $_ble_history_prefix ]]; then
    local code='
      # PREFIX_history_edit を未編集状態に戻す
      local index
      for index in "${!PREFIX_history_dirt[@]}"; do
        PREFIX_history_edit[index]=${PREFIX_history[index]}
      done
      PREFIX_history_dirt=()

      local topIndex=${#PREFIX_history[@]}
      PREFIX_history[topIndex]=$command
      PREFIX_history_edit[topIndex]=$command
      PREFIX_history_ind=$((topIndex+1))'
    builtin eval -- "${code//PREFIX/$_ble_history_prefix}"
  else
    blehook/invoke ADDHISTORY "$command" &&
      ble/history/.add-command-history "$command"
  fi
}

#------------------------------------------------------------------------------
# ble/history/search                                            @history.search

## 関数 ble/history/isearch-forward opts
## 関数 ble/history/isearch-backward opts
## 関数 ble/history/isearch-backward-blockwise opts
##
##   backward-search-history-blockwise does blockwise search
##   as a workaround for bash slow array access
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     regex     正規表現による検索を行います。
##     glob      グロブパターンによる一致を試みます。
##     head      固定文字列に依る先頭一致を試みます。
##     tail      固定文字列に依る終端一致を試みます。
##     condition 述語コマンドを評価 (eval) して一致を試みます。
##     predicate 述語関数を呼び出して一致を試みます。
##       これらの内の何れか一つを指定します。
##       何も指定しない場合は固定文字列の部分一致を試みます。
##
##     stop_check
##       ユーザの入力があった時に終了ステータス 148 で中断します。
##
##     progress
##       検索の途中経過を表示します。
##       後述の isearch_progress_callback 変数に指定された関数を呼び出します。
##
##     backward
##       内部使用のオプションです。
##       forward-search-history に対して指定して、後方検索を行う事を指定します。
##
##     cyclic
##       履歴の端まで達した時、履歴の反対側の端から検索を続行します。
##       一致が見つからずに start の直前の要素まで達した時に失敗します。
##
##   @var[in] _ble_history_edit
##     検索対象の配列と全体の検索開始位置を指定します。
##   @var[in] start
##     全体の検索開始位置を指定します。
##
##   @var[in] needle
##     検索文字列を指定します。
##
##     opts に regex または glob を指定した場合は、
##     それぞれ正規表現またはグロブパターンを指定します。
##
##     opts に condition を指定した場合は needle を述語コマンドと解釈します。
##     変数 LINE 及び INDEX にそれぞれ行の内容と履歴番号を設定して eval されます。
##
##     opts に predicate を指定した場合は needle を述語関数の関数名と解釈します。
##     指定する述語関数は検索が一致した時に成功し、それ以外の時に失敗する関数です。
##     第1引数と第2引数に行の内容と履歴番号を指定して関数が呼び出されます。
##
##   @var[in,out] index
##     今回の呼び出しの検索開始位置を指定します。
##     一致が成功したとき見つかった位置を返します。
##     一致が中断されたとき次の位置 (再開時に最初に検査する位置) を返します。
##
##   @var[in,out] isearch_time
##
##   @var[in] isearch_progress_callback
##     progress の表示時に呼び出す関数名を指定します。
##     第一引数には現在の検索位置 (history index) を指定します。
##
##   @exit
##     見つかったときに 0 を返します。
##     見つからなかったときに 1 を返します。
##     中断された時に 148 を返します。
##
function ble/history/.read-isearch-options {
  local opts=$1

  search_type=fixed
  case :$opts: in
  (*:regex:*)     search_type=regex ;;
  (*:glob:*)      search_type=glob  ;;
  (*:head:*)      search_type=head ;;
  (*:tail:*)      search_type=tail ;;
  (*:condition:*) search_type=condition ;;
  (*:predicate:*) search_type=predicate ;;
  esac

  [[ :$opts: != *:stop_check:* ]]; has_stop_check=$?
  [[ :$opts: != *:progress:* ]]; has_progress=$?
  [[ :$opts: != *:backward:* ]]; has_backward=$?
}
function ble/history/isearch-backward-blockwise {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble/history/.read-isearch-options "$opts"

  ble/history/initialize
  if [[ $_ble_history_prefix ]]; then
    local -a _ble_history_edit
    builtin eval "_ble_history_edit=(\"\${${_ble_history_prefix}_history_edit[@]}\")"
  fi

  local NSTPCHK=1000 # 十分高速なのでこれぐらい大きくてOK
  local NPROGRESS=$((NSTPCHK*2)) # 倍数である必要有り
  local irest block j i=$index
  index=

  local flag_cycled= range_min range_max
  while :; do
    if ((i<=start)); then
      range_min=0 range_max=$start
    else
      flag_cycled=1
      range_min=$((start+1)) range_max=$i
    fi

    while ((i>=range_min)); do
      ((block=range_max-i,
        block<5&&(block=5),
        block>i+1-range_min&&(block=i+1-range_min),
        irest=NSTPCHK-isearch_time%NSTPCHK,
        block>irest&&(block=irest)))

      case $search_type in
      (regex)     for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} =~ $needle ]] && index=$j
                  done ;;
      (glob)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == $needle ]] && index=$j
                  done ;;
      (head)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == "$needle"* ]] && index=$j
                  done ;;
      (tail)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == *"$needle" ]] && index=$j
                  done ;;
      (condition) builtin eval "function ble-edit/isearch/.search-block.proc {
                    local LINE INDEX
                    for ((j=i-block;++j<=i;)); do
                      LINE=\${_ble_history_edit[j]} INDEX=\$j
                      { $needle; } && index=\$j
                    done
                  }"
                  ble-edit/isearch/.search-block.proc ;;
      (predicate) for ((j=i-block;++j<=i;)); do
                    "$needle" "${_ble_history_edit[j]}" "$j" && index=$j
                  done ;;
      (*)         for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_history_edit[j]} == *"$needle"* ]] && index=$j
                  done ;;
      esac

      ((isearch_time+=block))
      [[ $index ]] && return 0

      ((i-=block))
      if ((has_stop_check&&isearch_time%NSTPCHK==0)) && ble/decode/has-input; then
        index=$i
        return 148
      elif ((has_progress&&isearch_time%NPROGRESS==0)); then
        "$isearch_progress_callback" "$i"
      fi
    done

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      ((i=${#_ble_history_edit[@]}-1))
      ((start<i)) || return 1
    else
      return 1
    fi
  done
}
function ble/history/forward-isearch.impl {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble/history/.read-isearch-options "$opts"

  ble/history/initialize
  if [[ $_ble_history_prefix ]]; then
    local -a _ble_history_edit
    builtin eval "_ble_history_edit=(\"\${${_ble_history_prefix}_history_edit[@]}\")"
  fi

  while :; do
    local flag_cycled= expr_cond expr_incr
    if ((has_backward)); then
      if ((index<=start)); then
        expr_cond='index>=0' expr_incr='index--'
      else
        expr_cond='index>start' expr_incr='index--' flag_cycled=1
      fi
    else
      if ((index>=start)); then
        expr_cond="index<${#_ble_history_edit[@]}" expr_incr='index++'
      else
        expr_cond="index<start" expr_incr='index++' flag_cycled=1
      fi
    fi

    case $search_type in
    (regex)
#%define search_loop
      for ((;expr_cond;expr_incr)); do
        ((isearch_time++,has_stop_check&&isearch_time%100==0)) &&
          ble/decode/has-input && return 148
        @ && return 0
        ((has_progress&&isearch_time%1000==0)) &&
          "$isearch_progress_callback" "$index"
      done ;;
#%end
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} =~ $needle ]]/
    (glob)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == $needle ]]/
    (head)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == "$needle"* ]]/
    (tail)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == *"$needle" ]]/
    (condition)
#%expand search_loop.r/@/LINE=${_ble_history_edit[index]} INDEX=$index builtin eval -- "$needle"/
    (predicate)
#%expand search_loop.r/@/"$needle" "${_ble_history_edit[index]}" "$index"/
    (*)
#%expand search_loop.r/@/[[ ${_ble_history_edit[index]} == *"$needle"* ]]/
    esac

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      if ((has_backward)); then
        ((index=${#_ble_history_edit[@]}-1))
        ((index>start)) || return 1
      else
        ((index=0))
        ((index<start)) || return 1
      fi
    else
      return 1
    fi
  done
}
function ble/history/isearch-forward {
  ble/history/forward-isearch.impl "$1"
}
function ble/history/isearch-backward {
  ble/history/forward-isearch.impl "$1:backward"
}
