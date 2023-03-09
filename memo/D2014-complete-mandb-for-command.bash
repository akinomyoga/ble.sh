# -*- mode: sh-bash -*-

# This is a test case provided by "mozirilla213" at the following URL:
# https://github.com/akinomyoga/ble.sh/discussions/287
#
# Step to reproduce:
#
# $ myscript.sh -<TAB>  # Menu completions from the man page appear
# $ runme -<TAB>        # Menu completions don't appear of course
#

function memo/D2014-initialize {
  local base=$_ble_base_repository/memo/D2014

  export MANPATH=$base/man
  PATH+=:$base/bin

  if [[ ! -s $base/man/man8/myscript.sh.8 ]]; then
    mkdir -p "$base"/man/man8

    # The manpage was named "myscript.sh"
    cat <<\EOF > "$base"/man/man8/myscript.sh.8
.TH MYSCRIPT.SH 8 "myscript.sh Manual"
.SH SYNOPSIS
.SY runme
.SH DESCRIPTION
.PP
Change directory to /etc
.SH OPTIONS
.TP
.B \-h ", " \-\-help
Option -h
.TP
.B \-a ", " \-\-all
Option -a
EOF
  fi

  if [[ ! -s $base/bin/myscript.sh ]]; then
    mkdir -p "$base"/bin

    # The executable script was named "myscript.sh"
    cat <<\EOF > "$base"/bin/myscript.sh
#!/usr/bin/env bash
echo "/etc"
EOF
    chmod +x "$base"/bin/myscript.sh
  fi
}
memo/D2014-initialize

# It connects to a function that runs in current environment because
# it `cd`s, changes env variables, etc.
runme() {
  cd "$(myscript.sh "$@")"
  export SCRIPT_PATH=$PWD
}

#------------------------------------------------------------------------------
# An example to define a completion function that generates option names based
# on the man page of a different command.

complete -F _comp_runme runme
_comp_runme() {
  # If bash-completion is loaded, we handle basic stuff with _init_completion.
  if declare -f _init_completion &>/dev/null; then
    local cur prev words cword split
    _init_completion -s || return 0
    "$split" && return 0
  fi

  # If ble.sh is loaded and active, we call the man-page based completions.
  if [[ ${BLE_ATTACHED-} ]]; then
    ble/complete/source:option/generate-for-command myscript.sh "${comp_words[@]:1:comp_cword-1}"
  fi
}
