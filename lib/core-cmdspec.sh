# -*- mode: sh; mode: sh-bash -*-

function ble/cmdspec/initialize { return 0; }

function ble/complete/opts/initialize {

  ble/cmdspec/opts mandb-disable-man:no-options : false true

  ble/cmdspec/opts mandb-disable-man times
  ble/cmdspec/opts mandb-disable-man:mandb-help=%'help "$command"':stop-options-postarg pwd suspend
  local help_opt_help=
  if ((_ble_bash>=40400)); then
    # Note: 既に説明がある時に優先順位を下げる為にインデントは 8 文字にしている
    help_opt_help='          --help    Show help.'
    ble/cmdspec/opts +mandb-help=@"$help_opt_help" times pwd suspend
  fi

  local help_opt_basic=$help_opt_help'
        --    (indicate the end of options)'
  ble/cmdspec/opts mandb-disable-man:mandb-help=%'help "$command"':mandb-help=@"$help_opt_basic":stop-options-postarg \
    alias bind cd command compgen complete compopt declare dirs disown enable \
    exec export fc getopts hash help history jobs kill mapfile popd printf \
    pushd read readonly set shopt trap type ulimit umask unalias unset wait
  ble/cmdspec/opts mandb-disable-man:mandb-help=@"$help_opt_basic":stop-options-postarg . source fg bg builtin caller eval let
  ble/cmdspec/opts mandb-disable-man:mandb-help=@"$help_opt_basic":stop-options-postarg break continue exit logout return shift

  # [[
  local conditional_operators='
    -eq (NUM1 -eq NUM2)      Arithmetic comparison ==.
    -ne (NUM1 -ne NUM2)      Arithmetic comparison !=.
    -lt (NUM1 -lt NUM2)      Arithmetic comparison < .
    -le (NUM1 -le NUM2)      Arithmetic comparison <=.
    -gt (NUM1 -gt NUM2)      Arithmetic comparison > .
    -ge (NUM1 -ge NUM2)      Arithmetic comparison >=.
    -nt (FILE1 -nt FILE2)    True if file1 is newer than file2 (according to modification date).
    -ot (FILE1 -ot FILE2)    True if file1 is older than file2.
    -ef (FILE1 -ef FILE2)    True if file1 is a hard link to file2.'
  ble/cmdspec/opts disable-double-hyphen:mandb-help=%'help test':mandb-help=@"$conditional_operators" '[['

  # [, test
  local test_operators=$conditional_operators'
    -a (EXPR1 -a EXPR2)      True if both expr1 AND expr2 are true.
    -a (EXPR1 -o EXPR2)      True if either expr1 OR expr2 is true.'
  ble/cmdspec/opts disable-double-hyphen:mandb-help=%'help test':mandb-help=@"$test_operators":mandb-exclude='^--' 'test' '['

  # cd, dirs, popd, pushd (別に実装)
  ble/cmdspec/opts +plus-options:mandb-exclude='^[-+]N$' dirs popd pushd


  # complete, compgen
  local complete_flags='
    -A action       The action may be one of the following to generate a list
                    of possible completions---alias, arrayvar, binding,
                    builtin, command, directory, disabled, enabled, export,
                    file, function, group, helptopic, hostname, job, keyword,
                    running, service, setopt, shopt, signal, stopped, user,
                    variable.
    -o option       Set completion option OPTION for each NAME
    -a              Alias names.  May also be specified as `-A alias'\''.
    -b              Names of shell builtin commands.  May also be specified as
                    `-A builtin'\''.
    -c              Command names.  May also be specified as `-A command'\''.
    -d              Directory names.  May also be specified as `-A
                    directory'\''.
    -e              Names of exported shell variables.  May also be specified
                    as `-A export'\''.
    -f              File names.  May also be specified as `-A file'\''.
    -g              Group names.  May also be specified as `-A group'\''.
    -j              Job names, if job control is active.  May also be specified
                    as `-A job'\''.
    -k              Shell reserved words.  May also be specified as `-A
                    keyword'\''.
    -s              Service names.  May also be specified as `-A service'\''.
    -u              User names.  May also be specified as `-A user'\''.
    -v              Names of all shell variables.  May also be specified as `-A
                    variable'\''.
    -C command      command is executed in a subshell environment, and its
                    output is used as the possible completions.  Arguments are
                    passed as with the -F option.
    -F function     The shell function function is executed in the current
                    shell environment.  When the function is executed, the
                    first argument ($1) is the name of the command whose
                    arguments are being completed, the second argu- ment ($2)
                    is the word being completed, and the third argument ($3) is
                    the word preceding the word being completed on the current
                    command line.  When it finishes, the possible completions
                    are retrieved from the value of the COMPREPLY array
                    variable.
    -G globpat      The pathname expansion pattern globpat is expanded to
                    generate the possible completions.
    -P prefix       prefix is added at the beginning of each possible
                    completion after all other options have been applied.
    -S suffix       suffix is appended to each possible completion after all
                    other options have been applied.
    -W wordlist     The wordlist is split using the characters in the IFS
                    special variable as delimiters, and each resultant word is
                    expanded.  Shell quoting is honored within wordlist, in
                    order to provide a mechanism for the words to contain shell
                    metacharacters or characters in the value of IFS.  The
                    possible completions are the members of the resultant list
                    which match the word being completed.
    -X filterpat    filterpat is a pattern as used for pathname expansion.  It
                    is applied to the list of possible completions generated by
                    the preceding options and arguments, and each completion
                    matching filterpat is removed from the list.  A leading !
                    in filterpat negates the pattern; in this case, any
                    completion not matching filterpat is removed.'
  ble/cmdspec/opts +mandb-help-usage:mandb-help=@"$complete_flags" complete compgen

  # compopt
  ble/cmdspec/opts +plus-options=o compopt

  # declare, typeset, local
  ble/cmdspec/opts mandb-disable-man:mandb-help=%'help declare':mandb-help=@"$help_opt_basic":stop-options-postarg typeset local
  ble/cmdspec/opts +plus-options=aAilnrtux declare typeset local

  # echo
  ble/cmdspec/opts mandb-disable-man:mandb-help=%'help echo':stop-options-unless='^-[neE]+$' echo

  # fc
  ble/cmdspec/opts +mandb-help=@'
        -s          With the `fc -s [pat=rep ...] [command]'\'' format, COMMAND
                    is re-executed after the substitution OLD=NEW is performed.' fc

  # jobs
  ble/cmdspec/opts +mandb-help=@'
        -x          If -x is supplied, COMMAND is run after all job
                    specifications that appear in ARGS have been replaced with
                    the process ID of that job'\''s process group leader.' jobs

  # readarray -> mapfile
  ble/cmdspec/opts mandb-disable-man:mandb-help=%'help mapfile':mandb-help=@"$help_opt_basic":stop-options-postarg readarray

  # set
  ble/cmdspec/opts +plus-options=abefhkmnptuvxBCEHPTo set

  # wait
  ((_ble_bash>=40300)) &&
    ble/cmdspec/opts +mandb-help-usage:mandb-help=@'
        -n          waits for a single job from the list of IDs, or, if no IDs
                    are supplied, for the next job to complete and returns its
                    exit status.' wait
  ((_ble_bash>=50000)) &&
    ble/cmdspec/opts +mandb-help-usage:mandb-help=@'
        -f          If job control is enabled, waits for the specified ID to
                    terminate, instead of waiting for it to change status.' wait
  ((_ble_bash>=50100)) &&
    ble/cmdspec/opts +mandb-help-usage:mandb-help=@'
        -p          the process or job identifier of the job for which the exit
                    status is returned is assigned to the variable VAR named by
                    the option argument. The variable will be unset initially,
                    before any assignment. This is useful only when the -n
                    option is supplied.' wait

  ble/cmdspec/opts mandb-help rsync
}
ble/complete/opts/initialize


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
      ble/syntax/highlight/vartype "$varname" global
      ble/progcolor/wattr#setattr "$wbeg" "$ret"
      ble/progcolor/wattr#setattr "$((wbeg+${#varname}))" d
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
