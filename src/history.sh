#!/bin/bash

## @bleopt history_limit_length
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
## @var _ble_history_index
##   現在の履歴項目の番号
##
_ble_history=()
_ble_history_edit=()
_ble_history_dirt=()
_ble_history_index=0

## @var _ble_history_count
##   現在の履歴項目の総数
##
## これらの変数はコマンド履歴を対象としているときにのみ用いる。
##
_ble_history_count=

function ble/builtin/history/is-empty {
  # Note #D1629: 以前の実装 (#D1120) では ! builtin history -p '!!' を使ってい
  #   たが、状況によって history -p で履歴項目が減少するのでサブシェルの中で評
  #   価する必要がある。サブシェルの中に既にいる時にはこの fork は省略できると
  #   考えていたが、サブシェルの中にいる場合でも後で履歴を使う為に履歴項目が変
  #   化すると困るので、結局この手法だと常にサブシェルを起動する必要がある。代
  #   わりに history 1 の出力を確認する実装に変更する事にした。
  ! ble/util/assign.has-output 'builtin history 1'
}

## @fn ble/builtin/history/.check-timestamp-sigsegv status
##   #D1831: Bash 4.4 以下では履歴ファイル (HISTFILE) に不正な timestamp
##   (0x7FFFFFFF+1900年より後を指す巨大な unix time) が含まれていると segfault
##   する。実際に SIGSEGV で終了した時に履歴ファイルを確認して問題の行番号を出
##   力する。
if ((_ble_bash>=50000)); then
  function ble/builtin/history/.check-timestamp-sigsegv { :; }
else
  function ble/builtin/history/.check-timestamp-sigsegv {
    local stat=$1
    ((stat)) || return 0

    local ret=11
    ble/builtin/trap/sig#resolve SIGSEGV
    ((stat==128+ret)) || return 0

    local msg="bash: SIGSEGV: suspicious timestamp in HISTFILE"

    local histfile=${HISTFILE-}
    if [[ -s $histfile ]]; then
      msg="$msg='$histfile'"
      local rex_broken_timestamp='^#[0-9]\{12\}'
      ble/util/assign line 'ble/bin/grep -an "$rex_broken_timestamp" "$histfile"'
      ble/string#split line : "$line"
      [[ $line =~ ^[0-9]+$ ]] && msg="$msg (line $line)"
    fi

    if [[ ${_ble_edit_io_fname2-} ]]; then
      ble/util/print $'\n'"$msg" >> "$_ble_edit_io_fname2"
    else
      ble/util/print "$msg" >&2
    fi
  }
fi

## @fn ble/builtin/history/.dump args...
##   #D1831: timestamp に不正な値が含まれていた時のメッセージを検出する為、一時
##   的に LC_MESSAGES を設定して builtin history を呼び出します。更にこの状況で、
##   bash-3.2 以下で無限ループになる問題を回避する為に、bash-3.2 以下では
##   conditional-sync 経由で呼び出します。
if ((_ble_bash<40000)); then
  # Note (#D1831): bash-3.2 以下では不正な timestamp が history に含まれている
  #   と無限ループになるので timeout=3000 で強制終了する。然し、実際に確認して
  #   みると、conditional-sync 経由で呼び出した時には無限ループにならずに
  #   timeout する前に SIGSEGV になる様である
  function ble/builtin/history/.dump.proc {
    local LC_ALL= LC_MESSAGES=C 2>/dev/null
    builtin history "${args[@]}"
    ble/util/unlocal LC_ALL LC_MESSAGES 2>/dev/null
  }
  function ble/builtin/history/.dump {
    local -a args; args=("$@")
    ble/util/conditional-sync \
      ble/builtin/history/.dump.proc \
      true 100 progressive-weight:timeout=3000:SIGKILL
    local ext=$?
    if ((ext==142)); then
      printf 'ble.sh: timeout: builtin history %s' "$*" >&"$_ble_util_fd_stderr"
      local ret=11
      ble/builtin/trap/sig#resolve SIGSEGV
      ((ext=128+ret))
    fi
    ble/builtin/history/.check-timestamp-sigsegv "$ext"
    return "$ext"
  }
else
  function ble/builtin/history/.dump {
    local LC_ALL= LC_MESSAGES=C 2>/dev/null
    builtin history "$@"
    ble/util/unlocal LC_ALL LC_MESSAGES 2>/dev/null
  }
fi

if ((_ble_bash<40000)); then
  function ble/builtin/history/.get-min {
    ble/util/assign-words min 'ble/builtin/history/.dump | head -1'
    min=${min/'*'}
  }
else
  function ble/builtin/history/.get-min {
    ble/util/assign-words min 'builtin history | head -1'
    min=${min/'*'}
  }
fi
function ble/builtin/history/.get-max {
  ble/util/assign-words max 'builtin history 1'
  max=${max/'*'}
}

#------------------------------------------------------------------------------
# initialize _ble_history                                    @history.bash.load

## @var _ble_history_load_done
_ble_history_load_done=

# @hook history_reset_background (defined in def.sh)
function ble/history:bash/clear-background-load {
  blehook/invoke history_reset_background
}

## @fn ble/history:bash/load
if ((_ble_bash>=40000)); then
  # _ble_bash>=40000 で利用できる以下の機能に依存する
  #   ble/util/is-stdin-ready (via ble/util/idle/IS_IDLE)
  #   ble/util/mapfile

  _ble_history_load_resume=0
  _ble_history_load_bgpid=

  # history > tmp
  ## @fn ble/history:bash/load/.background-initialize
  ##   @var[in] arg_count
  ##   @var[in] load_strategy
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

    local -x opt_source= opt_null=
    if [[ $load_strategy == source ]]; then
      opt_source=1
    elif [[ $load_strategy == mapfile ]]; then
      opt_null=1
    fi

    # from ble/util/writearray
    if [[ ! $_ble_util_writearray_rawbytes ]]; then
      local IFS=$_ble_term_IFS __ble_tmp; __ble_tmp=('\'{2,3}{0..7}{0..7})
      builtin eval "local _ble_util_writearray_rawbytes=\$'${__ble_tmp[*]}'"
    fi
    local -x __ble_rawbytes=$_ble_util_writearray_rawbytes # used by _ble_bin_awk_libES
    local -x fname_stderr=${_ble_edit_io_fname2:-}

    local apos=\'
    # 482ms for 37002 entries
    ble/builtin/history/.dump ${arg_count:+"$arg_count"} | ble/bin/awk -v apos="$apos" -v arg_offset="$arg_offset" -v _ble_bash="$_ble_bash" '
      '"$_ble_bin_awk_libES"'

      BEGIN {
        es_initialize();

        INDEX_FILE = ENVIRON["INDEX_FILE"];
        opt_null = ENVIRON["opt_null"];
        opt_source = ENVIRON["opt_source"];
        if (!opt_null && !opt_source)
          printf("") > INDEX_FILE; # create file

        fname_stderr = ENVIRON["fname_stderr"];
        fname_stderr_count = 0;

        n = 0;
        hindex = arg_offset;
      }

      function flush_line() {
        if (n < 1) return;

        if (opt_null) {
          if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
            t = es_unescape(substr(t, 11, length(t) - 11));
          printf("%s%c", t, 0);

        } else if (opt_source) {
          if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
            t = es_unescape(substr(t, 11, length(t) - 11));
          gsub(/'"$apos"'/, "'"$apos"'\\'"$apos$apos"'", t);
          print "_ble_history[" hindex "]=" apos t apos;

        } else {
          if (n == 1) {
            if (t ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
              print hindex > INDEX_FILE;
          } else {
            gsub(/['"$apos"'\\]/, "\\\\&", t);
            gsub(/\n/, "\\n", t);
            print hindex > INDEX_FILE;
            t = "eval -- $" apos t apos;
          }
          print t;
        }

        hindex++;
        n = 0;
        t = "";
      }

      function check_invalid_timestamp(line) {
        if (line ~ /^ *[0-9]+\*? +.+: invalid timestamp/ && fname_stderr != "") {
          sub(/^ *0*/, "bash: history !", line);
          sub(/: invalid timestamp.*$/, ": invalid timestamp", line);
          if (fname_stderr_count++ == 0)
            print "" >> fname_stderr;
          print line >> fname_stderr;
        }
      }

      {
        # Note: In Bash 5.0+, the error message of "invalid timestamp"
        # goes into "stdout" instead of "stderr".
        check_invalid_timestamp($0);
        if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/, "", $0))
          flush_line();
        t = ++n == 1 ? $0 : t "\n" $0;
      }

      END { flush_line(); }
    ' >| "$history_tmpfile.part"
    ble/builtin/history/.check-timestamp-sigsegv "${PIPESTATUS[0]}"
    ble/bin/mv -f "$history_tmpfile.part" "$history_tmpfile"
  }

  ## @fn ble/history:bash/load opts
  ##   @param[in] opts
  ##     async
  ##       非同期で読み取ります。
  ##     append
  ##       現在読み込み済みの履歴情報に追加します。
  ##     count=NUMBER
  ##       最近の NUMBER 項目だけ読み取ります。
  function ble/history:bash/load {
    local opts=$1
    local opt_async=; [[ :$opts: == *:async:* ]] && opt_async=1

    local load_strategy=mapfile
    if [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]]; then
      load_strategy=source
    elif ((_ble_bash<50200)); then
      load_strategy=nlfix
    fi

    local arg_count= arg_offset=0
    [[ :$opts: == *:append:* ]] &&
      arg_offset=${#_ble_history[@]}
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
            _ble_history_load_bgpid=$(ble/util/nohup 'ble/history:bash/load/.background-initialize' print-bgpid)

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
          ((arg_offset==0)) && _ble_history=()
          if [[ $load_strategy == source ]]; then
            # Cygwin #D0701 #D1605
            #   620ms 99000項目 @ #D0701
            source "$history_tmpfile"
          elif [[ $load_strategy == nlfix ]]; then
            builtin mapfile -O "$arg_offset" -t _ble_history < "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t -d '' _ble_history < "$history_tmpfile"
          fi
          ble/builtin/history/erasedups/update-base
          ((_ble_history_load_resume++)) ;;

      # 47ms _ble_history_edit 初期化 (37000項目)
      (4) ((arg_offset==0)) && _ble_history_edit=()
          if [[ $load_strategy == source ]]; then
            # 504ms Cygwin (99000項目)
            _ble_history_edit=("${_ble_history[@]}")
          elif [[ $load_strategy == nlfix ]]; then
            builtin mapfile -O "$arg_offset" -t _ble_history_edit < "$history_tmpfile"
          else
            builtin mapfile -O "$arg_offset" -t -d '' _ble_history_edit < "$history_tmpfile"
          fi
          : >| "$history_tmpfile"

          if [[ $load_strategy != nlfix ]]; then
            ((_ble_history_load_resume+=3))
            continue
          else
            ((_ble_history_load_resume++))
          fi ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (5) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_history[i]} =~ $rex ]] &&
              builtin eval "_ble_history[i]=${_ble_history[i]:8}"
          done
          ((_ble_history_load_resume++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (6) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          local i
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_history_edit[i]} =~ $rex ]] &&
              builtin eval "_ble_history_edit[i]=${_ble_history_edit[i]:8}"
          done
          ((_ble_history_load_resume++)) ;;

      (7) [[ $opt_async ]] || blehook/invoke history_message
          ((_ble_history_load_resume++))
          return 0 ;;

      (*) return 1 ;;
      esac

      [[ $opt_async ]] && ! ble/util/idle/IS_IDLE && return 148
    done
  }
  blehook history_reset_background!=_ble_history_load_resume=0
else
  function ble/history:bash/load/.generate-source {
    if ble/builtin/history/is-empty; then
      # rcfile として起動すると history が未だロードされていない。
      builtin history -n
    fi
    local HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    ble/builtin/history/.dump ${arg_count:+"$arg_count"} | ble/bin/awk -v apos="'" '
      BEGIN { n = ""; }

#%    # 何故かタイムスタンプがコマンドとして読み込まれてしまう
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)#[0-9]/ { next; }

#%    # ※rcfile として読み込むと HISTTIMEFORMAT が ?? に化ける。
      /^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/ {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        n = $1; t = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?|.+: invalid timestamp)/, "", $0);
      }
      {
        line = $0;
        if (line ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\.)*'"$apos"'$/)
          line = apos substr(line, 9) apos;
        else
          gsub(apos, apos "\\" apos apos, line);

#%      # 対策 #D1241: bash-3.2 以前では ^A, ^? が ^A^A, ^A^? に化ける
        gsub(/\001/, "'"$apos"'${_ble_term_SOH}'"$apos"'", line);
        gsub(/\177/, "'"$apos"'${_ble_term_DEL}'"$apos"'", line);

#%      # 対策 #D1270: MSYS2 で ^M を代入すると消える
        gsub(/\015/, "'"$apos"'${_ble_term_CR}'"$apos"'", line);

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
    local IFS=$_ble_term_IFS
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
    ble/builtin/history/erasedups/update-base
    ble/util/unlocal IFS

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
  _ble_history_index=$_ble_history_count
  ble/history/.update-position

  # Note: 追加読み込みをした際に対応するデータを shift (history_share)
  local delta=$((new_count-old_count))
  ((delta>0)) && blehook/invoke history_change insert "$old_count" "$delta"
}

#------------------------------------------------------------------------------
# Bash history resolve-multiline                            @history.bash.mlfix

if ((_ble_bash>=30100)); then
  # Note: Bash 3.0 では history -s がまともに動かないので
  # 複数行の履歴項目を builtin history に追加する方法が今の所不明である。

  _ble_history_mlfix_done=
  _ble_history_mlfix_resume=0
  _ble_history_mlfix_bgpid=

  ## @fn ble/history:bash/resolve-multiline/.awk reason
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
  ##   @var[in] tmpfile_base
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

        TMPBASE = ENVIRON["tmpfile_base"];
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
#%        # Note: HISTTIMEFORMAT を指定するのは bash-4.4 で複数行読み取りを有効にする為。
          print "HISTTIMEFORMAT=%s builtin history -r " filename_section > filename_source;
        } else {
          for (i = 0; i < command_count; i++) {
            c = command_text[i];
            gsub(/'"$apos"'/, Q, c);
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
        return cmd ~ /^eval -- \$'"$apos"'([^'"$apos"'\\]|\\[\\'"$apos"'nt])*'"$apos"'$/;
      }
      function unescape_command(cmd) {
        cmd = substr(cmd, 11, length(cmd) - 11);
        gsub(/\\\\/, "\\q", cmd);
        gsub(/\\n/, "\n", cmd);
        gsub(/\\t/, "\t", cmd);
        gsub(/\\'"$apos"'/, "'"$apos"'", cmd);
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
          gsub(/'"$apos"'/, Q, cmd);
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
          if (sub(/^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?|.+: invalid timestamp)/, "", $0))
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
  ## @fn ble/history:bash/resolve-multiline/.cleanup
  ##   @var[in] tmpfile_base
  function ble/history:bash/resolve-multiline/.cleanup {
    local file
    for file in "$tmpfile_base".*; do : >| "$file"; done
  }
  function ble/history:bash/resolve-multiline/.worker {
    local HISTTIMEFORMAT=__ble_time_%s__
    local -x tmpfile_base=$_ble_base_run/$$.history.mlfix
    local multiline_count=0 modification_count=0
    builtin eval -- "$(ble/builtin/history/.dump | ble/history:bash/resolve-multiline/.awk resolve 2>/dev/null)"
    if ((modification_count)); then
      ble/bin/mv -f "$tmpfile_base.part" "$tmpfile_base.sh"
    else
      ble/util/print : >| "$tmpfile_base.sh"
    fi
  }
  function ble/history:bash/resolve-multiline/.load {
    local tmpfile_base=$_ble_base_run/$$.history.mlfix
    local HISTCONTROL= HISTSIZE= HISTIGNORE=
    source "$tmpfile_base.sh"
    ble/history:bash/resolve-multiline/.cleanup
  }

  ## @fn ble/history:bash/resolve-multiline opts
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
          _ble_history_mlfix_bgpid=$(ble/util/nohup 'ble/history:bash/resolve-multiline/.worker' print-bgpid)

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

  blehook history_reset_background!=_ble_history_mlfix_resume=0

  function ble/history:bash/resolve-multiline/readfile {
    local filename=$1
    local -x tmpfile_base=$_ble_base_run/$$.history.read
    ble/history:bash/resolve-multiline/.awk read < "$filename" &>/dev/null
    source "$tmpfile_base.part"
    ble/history:bash/resolve-multiline/.cleanup
  }
else
  function ble/history:bash/resolve-multiline/readfile { builtin history -r "$filename"; }
  function ble/history:bash/resolve-multiline { ((1)); }
fi

# Note: 複数行コマンドは eval -- $'' の形に変換して
#   書き込みたいので自前で処理する。
function ble/history:bash/unload.hook {
  ble/util/is-running-in-subshell && return 0
  if shopt -q histappend &>/dev/null; then
    ble/builtin/history -a
  else
    ble/builtin/history -w
  fi
}
blehook unload!=ble/history:bash/unload.hook

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
# @hook history_change

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
  ## @fn ble/builtin/history/.get-rskip file
  ##   @param[in] file
  ##   @var[out] rskip
  ## @fn ble/builtin/history/.set-rskip file value
  ##   @param[in] file
  ## @fn ble/builtin/history/.add-rskip file delta
  ##   @param[in] file
  ##
  builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_history_rskip_dict}"
  function ble/builtin/history/.get-rskip {
    local file=$1 ret
    ble/gdict#get _ble_builtin_history_rskip_dict "$file"
    rskip=$ret
  }
  function ble/builtin/history/.set-rskip {
    local file=$1
    ble/gdict#set _ble_builtin_history_rskip_dict "$file" "$2"
  }
  function ble/builtin/history/.add-rskip {
    local file=$1 ret
    # Note: 当初 ((dict[\$file]+=$2)) の形式を使っていたが、これは
    #   shopt -s assoc_expand_once の場合に動作しない事が判明したので、
    #   一旦、別の変数で計算してから代入する事にする。
    ble/gdict#get _ble_builtin_history_rskip_dict "$file"
    ((ret+=$2))
    ble/gdict#set _ble_builtin_history_rskip_dict "$file" "$ret"
  }
fi

## @fn ble/builtin/history/.initialize opts
##   @param[in] opts
##     skip0 ... Bash 初期化処理 (bashrc) を抜け出ていると判定できない状態で、
##               履歴が一件も読み込まれていない時はスキップします。
function ble/builtin/history/.initialize {
  [[ $_ble_builtin_history_initialized ]] && return 0
  local line; ble/util/assign line 'builtin history 1'
  [[ ! $_ble_decode_hook_count && ! $line && :$1: == *:skip0:* ]] && return 1
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

  local histfile=${HISTFILE-} rskip=0
  [[ -e $histfile ]] && rskip=$(ble/bin/wc -l "$histfile" 2>/dev/null)
  ble/string#split-words rskip "$rskip"
  local min; ble/builtin/history/.get-min
  local max; ble/builtin/history/.get-max
  ((max&&max-min+1<rskip&&(rskip=max-min+1)))
  _ble_builtin_history_wskip=$max
  _ble_builtin_history_prevmax=$max
  ble/builtin/history/.set-rskip "$histfile" "$rskip"
  return 0
}
## @fn ble/builtin/history/.delete-range beg end
function ble/builtin/history/.delete-range {
  local beg=$1 end=${2:-$1}
  if ((_ble_bash>=50000&&beg<end)); then
    builtin history -d "$beg-$end"
  else
    local i
    for ((i=end;i>=beg;i--)); do
      builtin history -d "$i"
    done
  fi
}
## @fn ble/builtin/history/.check-uncontrolled-change [filename opts]
##   ble/builtin/history の管理外で履歴が読み込まれた時、
##   それを history -a の対象から除外する為に wskip を更新する。
function ble/builtin/history/.check-uncontrolled-change {
  [[ $_ble_decode_bind_state == none ]] && return 0
  local filename=${1-} opts=${2-} prevmax=$_ble_builtin_history_prevmax
  local max; ble/builtin/history/.get-max
  if ((max!=prevmax)); then
    if [[ $filename && :$opts: == *:append:* ]] && ((_ble_builtin_history_wskip<prevmax&&prevmax<max)); then
      # 最後に管理下で追加された事を確認した範囲 wskip..prevmax を書き込む。
      (
        ble/builtin/history/.delete-range "$((prevmax+1))" "$max"
        ble/builtin/history/.write "$filename" "$_ble_builtin_history_wskip" append:fetch
      )
    fi
    _ble_builtin_history_wskip=$max
    _ble_builtin_history_prevmax=$max
  fi
}
## @fn ble/builtin/history/.load-recent-entries count
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
  ((_ble_history_index==_ble_history_count)) && _ble_history_index=$ncount
  _ble_history_count=$ncount
  ble/history/.update-position
  blehook/invoke history_change insert "$ocount" "$delta"
}
## @fn ble/builtin/history/.read file [skip [fetch]]
function ble/builtin/history/.read {
  local file=$1 skip=${2:-0} fetch=$3
  local -x histnew=$_ble_base_run/$$.history.new
  if [[ -s $file ]]; then
    local script=$(ble/bin/awk -v skip="$skip" '
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
## @fn ble/builtin/history/.write file [skip [opts]]
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
      ble/builtin/history/.dump "$delta" >> "$histapp"
      ((_ble_builtin_history_histapp_count+=delta))
    else
      ble/builtin/history/.dump "$delta" >| "$histapp"
      _ble_builtin_history_histapp_count=$delta
    fi
  fi

  if [[ ! -e $file ]]; then
    (umask 077; : >| "$file")
  elif [[ :$opts: != *:append:* ]]; then
    : >| "$file"
  fi

  if [[ :$opts: != *:fetch:* && -s $histapp ]]; then
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
          gsub(/['"$apos"'\\]/, "\\\\&", text);
          gsub(/\n/, "\\n", text);
          gsub(/\t/, "\\t", text);
          text = "eval -- $'"$apos"'" text "'"$apos"'"
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

      /^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?|.+: invalid timestamp)?/ {
        flush_line();

        mode = 1;
        text = "";
        if (flag_timestamp)
          timestamp = extract_timestamp($0);

        sub(/^ *[0-9]+\*? +(__ble_time_[0-9]+__|\?\?|.+: invalid timestamp)?/, "", $0);
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

## @fn ble/builtin/history/array#delete-hindex array_name index...
##   @param[in] index
##     昇順に並んでいる事と重複がない事を仮定する。
function ble/builtin/history/array#delete-hindex {
  local array_name=$1; shift
  local script='
    local -a out=()
    local i shift=0
    for i in "${!ARR[@]}"; do
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
        out[i-shift]=${ARR[i]}
    done
    ARR=()
    for i in "${!out[@]}"; do ARR[i]=${out[i]}; done'
  builtin eval -- "${script//ARR/$array_name}"
}
## @fn ble/builtin/history/array#insert-range array_name beg len
function ble/builtin/history/array#insert-range {
  local array_name=$1 beg=$2 len=$3
  local script='
    local -a out=()
    local i
    for i in "${!ARR[@]}"; do
      out[i<beg?beg:i+len]=${ARR[i]}
    done
    ARR=()
    for i in "${!out[@]}"; do ARR[i]=${out[i]}; done'
  builtin eval -- "${script//ARR/$array_name}"
}
blehook history_change!=ble/builtin/history/change.hook
function ble/builtin/history/change.hook {
  local kind=$1; shift
  case $kind in
  (delete)
    ble/builtin/history/array#delete-hindex _ble_history_dirt "$@" ;;
  (clear)
    _ble_history_dirt=() ;;
  (insert)
    # Note: _ble_history, _ble_history_edit は別に更新される
    ble/builtin/history/array#insert-range _ble_history_dirt "$@" ;;
  esac
}
## @fn ble/builtin/history/option:c
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
      _ble_history_index=0
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
    ble/history/.update-position
    blehook/invoke history_change clear
  fi
}
## @fn ble/builtin/history/option:d index
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

  ble/builtin/history/.delete-range "$beg" "$end"
  if ((_ble_builtin_history_wskip>=end)); then
    ((_ble_builtin_history_wskip-=end-beg+1))
  elif ((_ble_builtin_history_wskip>beg-1)); then
    ((_ble_builtin_history_wskip=beg-1))
  fi

  if [[ $_ble_decode_bind_state != none ]]; then
    if [[ $_ble_history_load_done ]]; then
      local N=${#_ble_history[@]}
      local b=$((beg-1+N-max)) e=$((end+N-max))
      blehook/invoke history_change delete "$b-$e"
      if ((_ble_history_index>=e)); then
        ((_ble_history_index-=e-b))
      elif ((_ble_history_index>=b)); then
        _ble_history_index=$b
      fi
      _ble_history=("${_ble_history[@]::b}" "${_ble_history[@]:e}")
      _ble_history_edit=("${_ble_history_edit[@]::b}" "${_ble_history_edit[@]:e}")
      _ble_history_count=${#_ble_history[@]}
    else
      # history load が完了していなければ読み途中のデータを破棄して戻る
      ble/history:bash/clear-background-load
      _ble_history_count=
    fi
    ble/history/.update-position
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history/.get-histfile {
  histfile=${1:-${HISTFILE-}}
  if [[ ! $histfile ]]; then
    local opt=-a
    [[ ${FUNCNAME[1]} == *:[!:] ]] && opt=-${FUNCNAME[1]##*:}
    if [[ ${1+set} ]]; then
      ble/util/print "ble/builtin/history $opt: the history filename is empty." >&2
    else
      ble/util/print "ble/builtin/history $opt: the history file is not specified." >&2
    fi
    return 1
  fi
}
## @fn ble/builtin/history/option:a [filename]
function ble/builtin/history/option:a {
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  ble/builtin/history/.check-uncontrolled-change "$histfile" append
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  ble/builtin/history/.write "$histfile" "$_ble_builtin_history_wskip" append:fetch
  [[ -r $histfile ]] && ble/builtin/history/.read "$histfile" "$rskip" fetch
  ble/builtin/history/.write "$histfile" "$_ble_builtin_history_wskip" append
  builtin history -a /dev/null # Bash 終了時に書き込まない
}
## @fn ble/builtin/history/option:n [filename]
function ble/builtin/history/option:n {
  # HISTFILE が更新されていなければスキップ
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  if [[ $histfile == ${HISTFILE-} ]]; then
    local touch=$_ble_base_run/$$.history.touch
    [[ $touch -nt ${HISTFILE-} ]] && return 0
    : >| "$touch"
  fi

  ble/builtin/history/.initialize
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  ble/builtin/history/.read "$histfile" "$rskip"
}
## @fn ble/builtin/history/option:w [filename]
function ble/builtin/history/option:w {
  ble/builtin/history/.initialize skip0 || return "$?"
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  local rskip; ble/builtin/history/.get-rskip "$histfile"
  [[ -r $histfile ]] && ble/builtin/history/.read "$histfile" "$rskip" fetch
  ble/builtin/history/.write "$histfile" 0
  builtin history -a /dev/null # Bash 終了時に書き込まない
}
## @fn ble/builtin/history/option:r [histfile]
function ble/builtin/history/option:r {
  local histfile; ble/builtin/history/.get-histfile "$@" || return "$?"
  ble/builtin/history/.initialize
  ble/builtin/history/.read "$histfile" 0
}
## @fn ble/builtin/history/option:p
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
    local rex_head='^[[:space:]]*[0-9]+\*?[[:space:]]*'
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

bleopt/declare -v history_erasedups_limit 0
: "${_ble_history_erasedups_base=}"

function ble/builtin/history/erasedups/update-base {
  if [[ ! ${_ble_history_erasedups_base:-} ]]; then
    _ble_history_erasedups_base=${#_ble_history[@]}
  else
    local value=${#_ble_history[@]}
    ((value<_ble_history_erasedups_base&&(_ble_history_erasedups_base=value)))
  fi
}
## @fn ble/builtin/history/erasedups/.impl-for cmd
## @fn ble/builtin/history/erasedups/.impl-awk cmd
## @fn ble/builtin/history/erasedups/.impl-ranged cmd beg
##   @param[in] cmd
##   @var[in] N
##   @var[in] HISTINDEX_NEXT
##   @var[in] _ble_builtin_history_wskip
##   @arr[out] delete_indices
##   @var[out] shift_histindex_next
##   @var[out] shift_wskip
function ble/builtin/history/erasedups/.impl-for {
  local cmd=$1
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0

  local i
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
  fi
}
function ble/builtin/history/erasedups/.impl-awk {
  local cmd=$1
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0
  ((N)) || return 0

  # select the fastest awk implementation
  local -x erasedups_nlfix_read=
  local awk writearray_options
  if ble/bin/awk0.available; then
    erasedups_nlfix_read=
    writearray_options=(-d '')
    awk=ble/bin/awk0
  else
    erasedups_nlfix_read=1
    writearray_options=(--nlfix)
    if ble/is-function ble/bin/mawk; then
      awk=ble/bin/mawk
    elif ble/is-function ble/bin/gawk; then
      awk=ble/bin/gawk
    else
      ble/builtin/history/erasedups/.impl-for "$@"
      return "$?"
    fi
  fi

  local _ble_local_tmpfile
  ble/util/assign/mktmp; local otmp1=$_ble_local_tmpfile
  ble/util/assign/mktmp; local otmp2=$_ble_local_tmpfile
  ble/util/assign/mktmp; local itmp1=$_ble_local_tmpfile
  ble/util/assign/mktmp; local itmp2=$_ble_local_tmpfile

  # Note: ジョブを無効にする為 subshell で実行
  ( ble/util/writearray "${writearray_options[@]}" _ble_history      >| "$itmp1" & local pid1=$!
    ble/util/writearray "${writearray_options[@]}" _ble_history_edit >| "$itmp2"
    wait "$pid1" )

  local -x erasedups_cmd=$cmd
  local -x erasedups_out1=$otmp1
  local -x erasedups_out2=$otmp2
  local -x erasedups_histindex_next=$HISTINDEX_NEXT
  local -x erasedups_wskip=$_ble_builtin_history_wskip
  local awk_script='
    '"$_ble_bin_awk_libES"'
    '"$_ble_bin_awk_libNLFIX"'

    BEGIN {
      NLFIX_READ     = ENVIRON["erasedups_nlfix_read"] != "";
      cmd            = ENVIRON["erasedups_cmd"];
      out1           = ENVIRON["erasedups_out1"];
      out2           = ENVIRON["erasedups_out2"];
      histindex_next = ENVIRON["erasedups_histindex_next"];
      wskip          = ENVIRON["erasedups_wskip"];

      if (NLFIX_READ)
        es_initialize();
      else
        RS = "\0";

      NLFIX_WRITE = _ble_bash < 50200;
      if (NLFIX_WRITE) nlfix_begin();

      hist_index = 0;
      edit_index = 0;
      delete_count = 0;
      shift_histindex_next = 0;
      shift_wskip = 0;
    }

    function process_hist(elem) {
      if (hist_index < N - 1 && elem == cmd) {
        delete_indices[delete_count++] = hist_index;
        delete_table[hist_index] = 1;
        if (hist_index < wskip         ) shift_wskip++;
        if (hist_index < histindex_next) shift_histindex_next++;
      } else {
        if (NLFIX_WRITE)
          nlfix_push(elem, out1);
        else
          printf("%s%c", elem, 0) > out1;
      }
      hist_index++;
    }

    function process_edit(elem) {
      if (delete_count == 0) exit;
      if (NLFIX_WRITE) {
        if (edit_index == 0) {
          nlfix_end(out1);
          nlfix_begin();
        }
        if (!delete_table[edit_index++])
          nlfix_push(elem, out2);
      } else {
        if (!delete_table[edit_index++])
          printf("%s%c", elem, 0) > out2;
      }
    }

    mode == "edit" {
      if (NLFIX_READ) {
        edit[edit_index++] = $0;
      } else {
        process_edit($0);
      }
      next;
    }
    {
      if (NLFIX_READ)
        hist[hist_index++] = $0;
      else
        process_hist($0);
    }

    END {
      if (NLFIX_READ) {
        n = split(hist[hist_index - 1], indices)
        for (i = 1; i <= n; i++) {
          elem = hist[indices[i]];
          if (elem ~ /^\$'\''.*'\''/)
            hist[indices[i]] = es_unescape(substr(elem, 3, length(elem) - 3));
        }
        n = hist_index - 1;
        hist_index = 0;
        for (i = 0; i < n; i++)
          process_hist(hist[i]);

        n = split(edit[edit_index - 1], indices)
        for (i = 1; i <= n; i++) {
          elem = edit[indices[i]];
          if (elem ~ /^\$'\''.*'\''/)
            edit[indices[i]] = es_unescape(substr(elem, 3, length(elem) - 3));
        }
        n = edit_index - 1;
        edit_index = 0;
        for (i = 0; i < n; i++)
          process_edit(edit[i]);
      }

      if (NLFIX_WRITE) nlfix_end(out2);

      line = "delete_indices=("
      for (i = 0; i < delete_count; i++) {
        if (i != 0) line = line " ";
        line = line delete_indices[i];
      }
      line = line ")";
      print line;
      print "shift_wskip=" shift_wskip;
      print "shift_histindex_next=" shift_histindex_next;
    }
  '
  local awk_result
  ble/util/assign awk_result '"$awk" -v _ble_bash="$_ble_bash" -v N="$N" "$awk_script" "$itmp1" mode=edit "$itmp2"'
  builtin eval -- "$awk_result"
  if ((${#delete_indices[@]})); then
    if ((_ble_bash<50200)); then
      ble/util/readarray --nlfix _ble_history      < "$otmp1"
      ble/util/readarray --nlfix _ble_history_edit < "$otmp2"
    else
      mapfile -d '' -t _ble_history      < "$otmp1"
      mapfile -d '' -t _ble_history_edit < "$otmp2"
    fi
  fi
  _ble_local_tmpfile=$itmp2 ble/util/assign/rmtmp
  _ble_local_tmpfile=$itmp1 ble/util/assign/rmtmp
  _ble_local_tmpfile=$otmp2 ble/util/assign/rmtmp
  _ble_local_tmpfile=$otmp1 ble/util/assign/rmtmp
}
function ble/builtin/history/erasedups/.impl-ranged {
  local cmd=$1 beg=$2
  delete_indices=()
  shift_histindex_next=0
  shift_wskip=0

  # Note: 自前で history -d を行って重複を削除するので erasedups は除去しておく。
  # 但し、一番最後の一致する要素だけは自分では削除しないので、後のhistory -s で
  # 余分な履歴項目が追加されない様に ignoredups を付加する。
  ble/path#remove HISTCONTROL erasedups
  HISTCONTROL=$HISTCONTROL:ignoredups

  local i j=$beg
  for ((i=beg;i<N;i++)); do
    if ((i<N-1)) && [[ ${_ble_history[i]} == "$cmd" ]]; then
      ble/array#push delete_indices "$i"
      ((i<_ble_builtin_history_wskip&&shift_wskip++))
      ((i<HISTINDEX_NEXT&&shift_histindex_next++))
    else
      if ((i!=j)); then
        _ble_history[j]=${_ble_history[i]}
        _ble_history_edit[j]=${_ble_history_edit[i]}
      fi
      ((j++))
    fi
  done
  for ((;j<N;j++)); do
    builtin unset -v '_ble_history[j]'
    builtin unset -v '_ble_history_edit[j]'
  done

  if ((${#delete_indices[@]})); then
    local max; ble/builtin/history/.get-max
    local max_index=$((N-1))
    for ((i=${#delete_indices[@]}-1;i>=0;i--)); do
      builtin history -d "$((delete_indices[i]-max_index+max))"
    done
  fi
}
## @fn ble/builtin/history/erasedups cmd
##   指定したコマンドに一致する履歴項目を削除します。この呼出の後に history -s
##   を呼び出す事を想定しています。但し、一番最後の一致する要素は削除しません。
##
##   @var[in,out] HISTCONTROL
##   @exit 9
##     重複する要素が一番最後の要素のみの時に終了ステータス 9 を返します。この
##     時、履歴追加を行っても履歴に変化は発生しないので、後続の history -s の呼
##     び出しを省略してそのまま処理を終えても問題ありません。
function ble/builtin/history/erasedups {
  local cmd=$1

  local beg=0 N=${#_ble_history[@]}
  if [[ $bleopt_history_erasedups_limit ]]; then
    local limit=$((bleopt_history_erasedups_limit))
    if ((limit<=0)); then
      ((beg=_ble_history_erasedups_base+limit))
    else
      ((beg=N-1-limit))
    fi
    ((beg<0)) && beg=0
  fi

  local delete_indices shift_histindex_next shift_wskip
  if ((beg>=N)); then
    ble/path#remove HISTCONTROL erasedups
    return 0
  elif ((beg>0)); then
    ble/builtin/history/erasedups/.impl-ranged "$cmd" "$beg"
  else
    if ((_ble_bash>=40000&&N>=20000)); then
      ble/builtin/history/erasedups/.impl-awk "$cmd"
    else
      ble/builtin/history/erasedups/.impl-for "$cmd"
    fi
  fi

  if ((${#delete_indices[@]})); then
    blehook/invoke history_change delete "${delete_indices[@]}"
    ((_ble_builtin_history_wskip-=shift_wskip))
    [[ ${HISTINDEX_NEXT+set} ]] && ((HISTINDEX_NEXT-=shift_histindex_next))
  else
    # 単に今回の history/option:s を無視すれば良いだけの時
    ((N)) && [[ ${_ble_history[N-1]} == "$cmd" ]] && return 9
  fi
}

## @fn ble/builtin/history/option:s
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
    # Note: 以降の処理では HISTIGNORE は無視する。trim した後のコマンドに対して
    # 改めて作用するのを防ぐ為。
    local HISTIGNORE=
  fi

  # Note: ble/builtin/history/erasedups によって後の builtin history -s の為に
  # 時的に erasedups を除去する場合がある為ローカル変数に変えておく。また、
  # ignoreboth の処理の便宜の為にも内部的に書き換える。
  local HISTCONTROL=$HISTCONTROL

  # Note: HISTIGNORE 及び ignorespace は trim 前に処理する。何故なら行頭の空白
  # などに意味を持たせたいから。ignoredups 及び erasedups は trim 後に作用させ
  # る。何故なら実際に履歴に登録されたコマンドと比較したいから。
  if [[ $HISTCONTROL ]]; then
    [[ :$HISTCONTROL: == *:ignoreboth:* ]] &&
      HISTCONTROL=$HISTCONTROL:ignorespace:ignoredups
    if [[ :$HISTCONTROL: == *:ignorespace:* ]]; then
      [[ $cmd == [' 	']* ]] && return 0
    fi

    if [[ :$HISTCONTROL: == *:strip:* ]]; then
      local ret
      ble/string#rtrim "$cmd"
      ble/string#match "$ret" $'^[ \t]*(\n([ \t]*\n)*)?'
      cmd=${ret:${#BASH_REMATCH}}
      [[ $BASH_REMATCH == *$'\n'* && $cmd == *$'\n'* ]] && cmd=$'\n'$cmd
    fi
  fi

  local use_bash300wa=
  if [[ $_ble_history_load_done ]]; then
    if [[ $HISTCONTROL ]]; then
      if [[ :$HISTCONTROL: == *:ignoredups:* ]]; then
        # Note: plain Bash では ignoredups を検出した時には erasedups は発生し
        # ない様なのでそれに倣う。
        local lastIndex=$((${#_ble_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_history[lastIndex]}" ]] && return 0
      fi
      if [[ :$HISTCONTROL: == *:erasedups:* ]]; then
        ble/builtin/history/erasedups "$cmd"
        (($?==9)) && return 0
      fi
    fi
    local topIndex=${#_ble_history[@]}
    _ble_history[topIndex]=$cmd
    _ble_history_edit[topIndex]=$cmd
    _ble_history_count=$((topIndex+1))
    _ble_history_index=$_ble_history_count

    # _ble_bash<30100 の時は必ずここを通る。
    # 初期化時に _ble_history_load_done=1 になるので。
    ((_ble_bash<30100)) && use_bash300wa=1
  else
    if [[ $HISTCONTROL ]]; then
      # 未だ履歴が初期化されていない場合は取り敢えず history -s に渡す。
      # history -s でも HISTCONTROL に対するフィルタはされる。
      # history -s で項目が追加されたかどうかはスクリプトからは分からないので
      # _ble_history_count をクリアして再計算する
      _ble_history_count=
    else
      # HISTCONTROL がなければ多分 history -s で必ず追加される。
      # _ble_history_count 取得済ならば更新。
      [[ $_ble_history_count ]] &&
        ((_ble_history_count++))
    fi
  fi
  ble/history/.update-position

  if [[ $use_bash300wa ]]; then
    # bash < 3.1 workaround
    if [[ $cmd == *$'\n'* ]]; then
      # Note: 改行を含む場合は %q は常に $'' の形式になる。
      ble/util/sprintf cmd 'eval -- %q' "$cmd"
    fi
    local tmp=$_ble_base_run/$$.history.tmp
    [[ ${HISTFILE-} && ! $bleopt_history_share ]] &&
      ble/util/print "$cmd" >> "${HISTFILE-}"
    ble/util/print "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble/history:bash/clear-background-load
    builtin history -s -- "$cmd"
  fi
  local max; ble/builtin/history/.get-max
  _ble_builtin_history_prevmax=$max
}
function ble/builtin/history {
  local set shopt; ble/base/.adjust-bash-options set shopt
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
  if [[ $flag_error ]]; then
    builtin history --usage 2>&1 1>/dev/null | ble/bin/grep ^history >&2
    ble/base/.restore-bash-options set shopt
    return 2
  fi

  if [[ $flags == *h* ]]; then
    builtin history --help
    local ext=$?
    ble/base/.restore-bash-options set shopt
    return "$ext"
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH

  # -cdanwr
  local flag_processed=
  if [[ $opt_c ]]; then
    ble/builtin/history/option:c
    flag_processed=1
  fi
  if [[ $opt_s ]]; then
    local IFS=$_ble_term_IFS
    ble/builtin/history/option:s "$*"
    flag_processed=1
  elif [[ $opt_d ]]; then
    ble/builtin/history/option:d "$opt_d"
    flag_processed=1
  elif [[ $opt_a ]]; then
    ble/builtin/history/option:"$opt_a" "$@"
    flag_processed=1
  fi
  if [[ $flag_processed ]]; then
    ble/base/.restore-bash-options set shopt
    return 0
  fi

  # -p
  if [[ $opt_p ]]; then
    ble/builtin/history/option:p "$@"
  else
    builtin history "$@"
  fi; local ext=$?

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
  ble/base/.restore-bash-options set shopt
  return "$ext"
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
##     _ble_history_index
##     _ble_history_edit
##     _ble_history_dirt
##
##   空でない文字列 prefix のとき、以下の変数を操作対象とする。
##
##     ${prefix}_history
##     ${prefix}_history_index
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

function ble/history/set-prefix {
  _ble_history_prefix=$1
  ble/history/.update-position
}

_ble_history_COUNT=
_ble_history_INDEX=
function ble/history/.update-position {
  if [[ $_ble_history_prefix ]]; then
    builtin eval -- "_ble_history_COUNT=\${#${_ble_history_prefix}_history[@]}"
    ((_ble_history_INDEX=${_ble_history_prefix}_history_index))
  else
    # 履歴読込完了前の時
    if [[ ! $_ble_history_load_done ]]; then
      if [[ ! $_ble_history_count ]]; then
        local min max
        ble/builtin/history/.get-min
        ble/builtin/history/.get-max
        ((_ble_history_count=max-min+1))
      fi
      _ble_history_index=$_ble_history_count
    fi

    _ble_history_COUNT=$_ble_history_count
    _ble_history_INDEX=$_ble_history_index
  fi
}
function ble/history/update-position {
  [[ $_ble_history_prefix$_ble_history_load_done ]] ||
    ble/history/.update-position
}

## @hook history_leave (defined in def.sh)

function ble/history/onleave.fire {
  blehook/invoke history_leave "$@"
}

## called by ble-edit/initialize in Bash 3
function ble/history/initialize {
  [[ ! $_ble_history_prefix ]] &&
    ble/history:bash/initialize
}
function ble/history/get-count {
  local _ble_local_var=count
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  ble/history/.update-position
  (($_ble_local_var=_ble_history_COUNT))
}
function ble/history/get-index {
  local _ble_local_var=index
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  ble/history/.update-position
  (($_ble_local_var=_ble_history_INDEX))
}
function ble/history/set-index {
  _ble_history_INDEX=$1
  ((${_ble_history_prefix:-_ble}_history_index=_ble_history_INDEX))
}
function ble/history/get-entry {
  local _ble_local_var=entry
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  if [[ $_ble_history_prefix$_ble_history_load_done ]]; then
    builtin eval -- "$_ble_local_var=\${${_ble_history_prefix:-_ble}_history[\$1]}"
  else
    builtin eval -- "$_ble_local_var="
  fi
}
function ble/history/get-edited-entry {
  local _ble_local_var=entry
  [[ $1 == -v ]] && { _ble_local_var=$2; shift 2; }
  if [[ $_ble_history_prefix$_ble_history_load_done ]]; then
    builtin eval -- "$_ble_local_var=\${${_ble_history_prefix:-_ble}_history_edit[\$1]}"
  else
    builtin eval -- "$_ble_local_var=\$_ble_edit_str"
  fi
}
## @fn ble/history/set-edited-entry index str
function ble/history/set-edited-entry {
  ble/history/initialize
  local index=$1 str=$2
  local code='
    # store
    if [[ ! ${PREFIX_history_edit[index]+set} || ${PREFIX_history_edit[index]} != "$str" ]]; then
      PREFIX_history_edit[index]=$str
      PREFIX_history_dirt[index]=1
    fi'
  builtin eval -- "${code//PREFIX/${_ble_history_prefix:-_ble}}"
}

## @fn ble/history/.add-command-history command
## @var[in,out] HISTINDEX_NEXT
##   used by ble/widget/accept-and-next to get modified next-entry positions
function ble/history/.add-command-history {
  # 注意: bash-3.2 未満では何故か bind -x の中では常に history off になっている。
  [[ -o history ]] || ((_ble_bash<30200)) || return 1

  # Note: mc (midnight commander) が初期化スクリプトを送ってくる #D1392
  [[ $MC_SID == $$ && $_ble_edit_LINENO -le 2 && ( $1 == *PROMPT_COMMAND=* || $1 == *PS1=* ) ]] && return 1

  if [[ $_ble_history_load_done ]]; then
    # 登録・不登録に拘わらず取り敢えず初期化
    _ble_history_index=${#_ble_history[@]}
    ble/history/.update-position

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
      PREFIX_history_index=$((++topIndex))
      _ble_history_COUNT=$topIndex
      _ble_history_INDEX=$topIndex'
    builtin eval -- "${code//PREFIX/$_ble_history_prefix}"
  else
    blehook/invoke ADDHISTORY "$command" &&
      ble/history/.add-command-history "$command"
  fi
}

#------------------------------------------------------------------------------
# ble/history/search                                            @history.search

## @fn ble/history/isearch-forward opts
## @fn ble/history/isearch-backward opts
## @fn ble/history/isearch-backward-blockwise opts
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

  local isearch_block=1000 # 十分高速なのでこれぐらい大きくてOK
  local isearch_quantum=$((isearch_block*2)) # 倍数である必要有り
  local irest block j i=$index
  index=

  local flag_icase=; [[ :$opts: == *:ignore-case:* ]] && flag_icase=1

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
        irest=isearch_block-isearch_time%isearch_block,
        block>irest&&(block=irest)))

      [[ $flag_icase ]] && shopt -s nocasematch
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
      [[ $flag_icase ]] && shopt -u nocasematch

      ((isearch_time+=block))
      [[ $index ]] && return 0

      ((i-=block))
      if ((has_stop_check&&isearch_time%isearch_block==0)) && ble/decode/has-input; then
        index=$i
        return 148
      elif ((has_progress&&isearch_time%isearch_quantum==0)); then
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
function ble/history/isearch-forward.impl {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble/history/.read-isearch-options "$opts"

  ble/history/initialize
  if [[ $_ble_history_prefix ]]; then
    local -a _ble_history_edit
    builtin eval "_ble_history_edit=(\"\${${_ble_history_prefix}_history_edit[@]}\")"
  fi

  local flag_icase=; [[ :$opts: == *:ignore-case:* ]] && flag_icase=1

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

    [[ $flag_icase ]] && shopt -s nocasematch
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
    [[ $flag_icase ]] && shopt -u nocasematch

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
  ble/history/isearch-forward.impl "$1"
}
function ble/history/isearch-backward {
  ble/history/isearch-forward.impl "$1:backward"
}
