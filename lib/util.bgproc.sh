# -*- mode: sh; mode: sh-bash -*-

## @fn ble/util/bgproc#open prefix command [opts]
##   Start a session for a background process.  The session can be closed by
##   calling "ble/util/bgproc#close PREFIX".  The background process is usually
##   started on the start of the session and terminated on closing the session.
##   In addition, if requested, the background process can be stopped and
##   started any time in the session.  If the background process is stopped, it
##   is automatically restarted when it becomes needed.  If "timeout=TIMEOUT"
##   is specified in OPTS, the background process is automatically stopped
##   where there is no access for the time duration specified by TIMEOUT.
##
##   @param[in] prefix
##     This names the identifier of the bgproc.  This is actually used as the
##     prefix of the array names used to store the information of the created
##     bgproc, so the value needs to be a valid variable name.
##
##     When the bgproc is successfully created, the following array elements
##     are set, (where PREFIX in the variable name is replaced by the value of
##     prefix).
##
##     @var PREFIX_bgproc[0]       ... fd_response
##     @var PREFIX_bgproc[1]       ... fd_request
##     @var PREFIX_bgproc[2]       ... command
##     @var PREFIX_bgproc[3]       ... opts
##     @var PREFIX_bgproc[4]       ... bgpid
##     @var PREFIX_bgproc_fname[0] ... fname_response
##     @var PREFIX_bgproc_fname[1] ... fname_request
##     @var PREFIX_bgproc_fname[2] ... fname_run_pid
##
##     To send strings to stdin of the background process, one can write to the
##     file descriptor ${PREFIX_bgproc[1]}.  To read strings coming from stdout
##     of the background process, one can read from the file descriptor
##     ${PREFIX_bgproc[0]}.
##
##     When any of "timeout=TIMEOUT", "deferred", and "restart" are specified
##     to OPTS, one should call "ble/util/bgproc#use PREFIX" just before
##     directly accesssing the file descriptors ${PREFIX_bgproc[0]} and
##     ${PREFIX_bgproc[1]} to ensure that the background process is running.
##     Or, one can use a shorthand "ble/util/bgproc#post PREFIX STRING" to
##     ensure the background process and write STRING to it.  Immediately after
##     "ble/util/bgproc#post PREFIX STRING", one do not need to call
##     "ble/util/bgproc#use PREFIX" to read from ${PREFIX_bgproc[0]}.
##
##   @param[in] command
##     The command to execute.
##
##     @remarks Use `exec'--The command is started in a subshell.  When an
##     external command is started (as the last command of the subshell),
##     please start the command by `exec'.  This will replace the current
##     process with the external process.  If the external command is not
##     started with `exec', the external command is created as a child process
##     of the subshell, and the file descriptors are kept by also the subshell.
##     This may cause a deadlock in closing the file descriptors because the
##     file descriptors in the external process are still alive even after the
##     main Bash subshell closes them because the subshell still keeps the file
##     descriptor.
##
##     @remarks Reserved variables `bgproc' and `bgproc_fname'--If the command
##     wants to access the variable names "bgproc" and "bgproc_fname" defined
##     outside the command, please save the values in other names of variables
##     before calling "ble/util/bgproc#open" and access those alternative
##     variables from inside the command.  The variable names "bgproc" and
##     "bgproc_fname" are hidden by the local variables used by ble/util/bgproc
##     itself.
##
##   @param[in,opt] opts
##     A colon-separated list of options.  The following options can be
##     specified.
##
##     deferred
##       When this option is specified, the background process is initially not
##       started.  It will be started when it is first required.
##
##     restart
##       When this option is specified, if the background process died
##       unexpectedly, the background process will be restarted when it becomes
##       necessary.
##
##       Note: Even if this option is unspecified, the background process that
##       was intensiontally stopped will be always restarted when it becomes
##       necessary.  This option only affects the case that the background
##       process exited or died outside the management of bgproc.
##
##     timeout=TIMEOUT
##       When this option is specified, the background process is stopped when
##       there are no access to the background process for the time duration
##       specified by TIMEOUT.  The unit of TIMEOUT is millisecond.
##
##     owner-close-on-unload
##       This option suppresses the automatic call of "ble/util/bgproc#close"
##       from the "unload" blehook.  This option is useful when another
##       "unload" blehook needs to access to this bgproc.  When this option is
##       specified, another "unload" blehook needs to manually call
##       "ble/util/bgproc#close" for this bgproc.  If "ble/util/bgproc#close"
##       is not called, the background process may be forcibly terminated by
##       the final cleaup stage of ble.sh session.
##
##     no-close-on-unload
##       This option suppresses the automatic call of "ble/util/bgproc#close"
##       and any cleanups of the background process, so that the background
##       process survives after Bash terminates or ble.sh has been unloaded.
##
##       Note: Nevertheless, file descriptors at the side of the parent shell
##       will be closed on the termination of the parent shell, which can cause
##       SIGPIPE write error or EOF read error in the background process.
##
##     kill-timeout=TIMEOUT
##       This option specifies the timeout after the attempt of stopping the
##       background process in unit of millisecond.  The default is 10000 (10
##       seconds).  If the background process does not terminate within the
##       timeout after closing the file descriptors at the side of the parent
##       shell, the background process will receive SIGTERM.  If it does not
##       terminate even after sending SIGTERM, it will then receive SIGKILL
##       after additional timeout specified by "kill9-timeout".
##
##     kill9-timeout=TIMEOUT
##       This option specifies the additional timeout after sending SIGTERM
##       after "kill-timeout".  The default is 10000 (10 seconds).  If the
##       background process does not terminate within the timeout after sending
##       SIGTERM, the background process will receive SIGKILL.
##
##   @exit 0 if the background process is successfully started or "deferred" is
##   specified to OPTS.  2 if an invalid prefix value is specified.  3 if the
##   system does not support named pipes.  1 if the background process failed
##   to be started.
##
##   @remarks No FD_CLOEXEC for bgproc file descriptors--Unlike "coproc", the
##   file descriptors opened by bgproc are not closed in subshells.  This means
##   that if there are other background processes holding the file descriptors,
##   even when the main Bash process closes the file descriptors by
##   `ble/util/bgproc#stop' or `ble/util/bgproc#close', the file descriptors in
##   the bgproc process can still alive.  If one wants to make it sure that the
##   file descriptors are closed in the other subshells, one needs to close the
##   file descriptors
##
##   1) by calling eval "exec ${PREFIX_bgproc[0]}>&- ${PREFIX_bgproc[1]}>&-"
##
##   2) Or by calling `ble/fd#finalize' (Note that `ble/fd#finalize' closes all
##     the file descriptors opened by ble.sh including the ones used by
##     ble/util/msleep)..
##
##   3) Or another way is to use the loadable builtin "fdflags" to set
##     FD_CLOEXEC in `ble/util/bgproc/onstart:PREFIX'.  bgproc[]
##
##     # The loadable builtin needs to be loaded in advance.  Please replace
##     # the path /usr/lib/bash/fdflags based on your installation.
##     enable -f /usr/lib/bash/fdflags fdflags
##
##     function ble/util/bgproc/onstart:PREFIX {
##       fdflags -s +cloexec "${PREFIX_bgproc[0]}"
##       fdflags -s +cloexec "${PREFIX_bgproc[1]}"
##     }
##
## @fn ble/util/bgproc/onstart:PREFIX
##   When this function is defined, this function is called after the new
##   background process is created.
##
## @fn ble/util/bgproc/onstop:PREFIX
##   When this function is defined, this function is called before the
##   background process is stopped.
##
##   The application can send an intruction to terminate the background process
##   in this hook (in case that the background process does not automatically
##   end on the close of the file descriptors, or the file descriptors can be
##   shared with other background subshells).  Note that the background process
##   will receive SIGTERM if it does not terminate within the timeout specified
##   by "kill-timeout=TIMEOUT" and then will receive SIGKILL if it does not
##   even terminate within the additional timeout specified by
##   "kill9-timeout=TIMEOUT".
##
## @fn ble/util/bgproc/onclose:PREFIX
##   When this function is defined, this function is called before the bgproc
##   session is closed.
##
## @fn ble/util/bgproc/ontimeout:PREFIX
##   When this function is defined, this function is called before the timeout
##   specified by "timeout=TIMEOUT" in OPTS.  If this function exits with
##   non-zero status, the timeout is canceled.
##
function ble/util/bgproc#open {
  if ! ble/string#match "$1" '^[_a-zA-Z][_a-zA-Z0-9]*$'; then
    ble/util/print "$FUNCNAME: $1: invalid prefix value." >&2
    return 2
  fi

  # If there is an existing bgproc on the same prefix, close it first.
  ble/util/bgproc#close "$1"

  local -a bgproc=()
  bgproc[0]=
  bgproc[1]=
  bgproc[2]=$2
  bgproc[3]=${3-}

  local -a bgproc_fname=()
  bgproc_fname[0]=$_ble_base_run/$$.util.bgproc.$1.response.pipe
  bgproc_fname[1]=$_ble_base_run/$$.util.bgproc.$1.request.pipe
  bgproc_fname[2]=$_ble_base_run/$$.util.bgproc.$1.pid

  ble/util/save-vars "${1}_" bgproc bgproc_fname

  [[ :${bgproc[3]}: == *:deferred:* ]] || ble/util/bgproc#start "$1"; local ext=$?
  if ((ext!=0)); then
    builtin eval -- "${1}_bgproc=() ${1}_bgproc_fname=()"
  fi
  return "$ext"
}

## @fn ble/util/bgproc#alive prefix
##   Test if the bgproc session is active.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
function ble/util/bgproc#opened {
  local bgpid_ref=${1}_bgproc[0]
  [[ ${!bgpid_ref+set} ]] || return 2
}

## @fn ble/util/bgproc/.alive
##   @var[in] bgproc
function ble/util/bgproc/.alive {
  [[ ${bgproc[4]-} ]] && kill -0 "${bgproc[4]}" 2>/dev/null
}

## @fn ble/util/bgproc/.exec
##   @var[in] bgproc
function ble/util/bgproc/.exec {
  # Note: We need to specify the redirections for ${bgproc[0]} and ${bgproc[1]}
  # on "builtin eval" because of a bash-3.0 bug.  In Bash 3.0, the redirections
  # are not properly set up if one uses a function definition of the form
  # "function fname { } redirections".
  builtin eval -- "${bgproc[2]}" <&"${bgproc[1]}" >&"${bgproc[0]}"
}

## @fn ble/util/bgproc/.mkfifo
##   @var[in] bgproc_fname
function ble/util/bgproc/.mkfifo {
  local -a pipe_remove=() pipe_create=()
  local i
  for i in 0 1; do
    [[ -p ${bgproc_fname[i]} ]] && continue
    ble/array#push pipe_create "${bgproc_fname[i]}"
    if [[ -e ${bgproc_fname[i]} || -h ${bgproc_fname[i]} ]]; then
      ble/array#push pipe_remove "${bgproc_fname[i]}"
    fi
  done
  ((${#pipe_remove[@]}==0)) || ble/bin/rm -f "${pipe_remove[@]}" 2>/dev/null
  ((${#pipe_create[@]}==0)) || ble/bin/mkfifo "${pipe_create[@]}" 2>/dev/null
}

## @fn ble/util/bgproc#start prefix
##   Start the background process.  This runs the command specified to
##   "ble/util/bgproc#open".
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
##   @exit 0 if the background process is successfully started or was already
##   running.  2 if the PREFIX does not corresponds to an existing bgproc.  3
##   if the system does not support the named pipes.  1 if the background
##   process failed to be started.
##
function ble/util/bgproc#start {
  local bgproc bgproc_fname
  ble/util/restore-vars "${1}_" bgproc bgproc_fname
  if ((!${#bgproc[@]})); then
    ble/util/print "$FUNCNAME: $1: not an existing bgproc name." >&2
    return 2
  fi

  if ble/util/bgproc/.alive; then
    # The background process is already running
    return 0
  fi
  [[ ! ${bgproc[0]-} ]] || ble/fd#close 'bgproc[0]'
  [[ ! ${bgproc[1]-} ]] || ble/fd#close 'bgproc[1]'

  # Note: mkfifo may fail in MSYS-1
  local _ble_local_ext=0 _ble_local_bgproc0= _ble_local_bgproc1=
  if ble/util/bgproc/.mkfifo &&
    ble/fd#alloc _ble_local_bgproc0 '<> "${bgproc_fname[0]}"' &&
    ble/fd#alloc _ble_local_bgproc1 '<> "${bgproc_fname[1]}"'
  then
    bgproc[0]=$_ble_local_bgproc0
    bgproc[1]=$_ble_local_bgproc1
    # Note: We want to assign a new process group to the background process
    #   without affecting the job table of the main shell so use the subshell
    #   `(...)'.  The process group is later used to kill the process tree in
    #   stopping the background process.  Note that the command substitutions
    #   $(...) do not create a new process group even if we specify `set -m' so
    #   cannot be used for the present purpose.
    ble/util/assign 'bgproc[4]' '(set -m; ble/util/bgproc/.exec __ble_suppress_joblist__ >/dev/null & bgpid=$!; ble/util/print "$bgpid")'

    if ble/util/bgproc/.alive; then
      [[ :${bgproc[3]}: == *:no-close-on-unload:* ]] ||
        ble/util/print "-${bgproc[4]}" >| "${bgproc_fname[2]}"
      [[ :${bgproc[3]}: == *:no-close-on-unload:* || :${bgproc[3]}: == *:owner-close-on-unload:* ]] ||
        blehook unload!="ble/util/bgproc#close $1"
      ble/util/bgproc#keepalive "$1"
    else
      builtin unset -v 'bgproc[4]'
      _ble_local_ext=1
    fi
  else
    _ble_local_ext=3
  fi

  if ((_ble_local_ext!=0)); then
    [[ ! ${bgproc[0]-} ]] || ble/fd#close 'bgproc[0]'
    [[ ! ${bgproc[1]-} ]] || ble/fd#close 'bgproc[1]'
    bgproc[0]=
    bgproc[1]=
    builtin unset -v 'bgproc[4]'
  fi

  ble/util/save-vars "${1}_" bgproc bgproc_fname

  if ((_ble_local_ext==0)); then
    ble/function#try ble/util/bgproc/onstart:"$1"
  fi
  return "$_ble_local_ext"
}

function ble/util/bgproc#stop/.kill {
  local pid=$1 opts=$2 ret

  # kill --
  local timeout=10000
  if ble/opts#extract-last-optarg "$opts" kill-timeout; then
    timeout=$ret
  fi
  ble/util/conditional-sync '' '((1))' 1000 progressive-weight:pid="$pid":no-wait-pid:timeout="$timeout"
  kill -0 "$pid" || return 0

  # kill -9
  local timeout=10000
  if ble/opts#extract-last-optarg "$opts" kill9-timeout; then
    timeout=$ret
  fi
  ble/util/conditional-sync '' '((1))' 1000 progressive-weight:pid="$pid":no-wait-pid:timeout="$timeout":SIGKILL
}

## @fn ble/util/bgproc#stop prefix
##   Stop the background process.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
function ble/util/bgproc#stop {
  local prefix=$1
  ble/util/bgproc#keepalive/.cancel-timeout "$prefix"

  local bgproc bgproc_fname
  ble/util/restore-vars "${prefix}_" bgproc bgproc_fname
  if ((!${#bgproc[@]})); then
    ble/util/print "$FUNCNAME: $prefix: not an existing bgproc name." >&2
    return 2
  fi

  [[ ${bgproc[4]-} ]] || return 1

  if ble/is-function ble/util/bgproc/onstop:"$prefix" && ble/util/bgproc/.alive; then
    ble/util/bgproc/onstop:"$prefix"
  fi

  ble/fd#close 'bgproc[0]'
  ble/fd#close 'bgproc[1]'
  >| "${bgproc_fname[2]}"

  # When the background process is active, kill the process after waiting for
  # the time specified by kill-timeout.
  if ble/util/bgproc/.alive; then
    (ble/util/nohup 'ble/util/bgproc#stop/.kill "-${bgproc[4]}" "${bgproc[3]}"')
  fi

  builtin eval -- "${prefix}_bgproc[0]="
  builtin eval -- "${prefix}_bgproc[1]="
  builtin unset -v "${prefix}_bgproc[4]"
  return 0
}

## @fn ble/util/bgproc#alive prefix
##   Test if the background process is currently running.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
##   @exit 2 if the prefix does not define a bgproc.  1 if the bgproc
##     process is temporarily stopped.  3 if the bgproc process has
##     crashed.  0 if the process is running.
function ble/util/bgproc#alive {
  local prefix=$1 bgproc
  ble/util/restore-vars "${prefix}_" bgproc
  ((${#bgproc[@]})) || return 2
  [[ ${bgproc[4]-} ]] || return 1
  kill -0 "${bgproc[4]}" 2>/dev/null || return 3
  return 0
}

function ble/util/bgproc#keepalive/.timeout {
  local prefix=$1

  # Call ble/util/bgproc/ontimeout:PREFIX if any
  if ble/is-function ble/util/bgproc/ontimeout:"$prefix"; then
    if ! ble/util/bgproc/ontimeout:"$prefix"; then
      ble/util/bgproc#keepalive "$prefix"
      return 0
    fi
  fi

  ble/util/bgproc#stop "$prefix"
}

function ble/util/bgproc#keepalive/.cancel-timeout {
  local prefix=$1
  ble/function#try ble/util/idle.cancel "ble/util/bgproc#keepalive/.timeout $prefix"
}

## @fn ble/util/bgproc#keepalive prefix
##   Rest the timeout to stop the background process.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
function ble/util/bgproc#keepalive {
  local prefix=$1 bgproc
  ble/util/restore-vars "${prefix}_" bgproc
  ((${#bgproc[@]})) || return 2
  ble/util/bgproc/.alive || return 1

  ble/util/bgproc#keepalive/.cancel-timeout "$prefix"
  local ret
  ble/opts#extract-last-optarg "${bgproc[3]}" timeout || return 0; local bgproc_timeout=$ret
  if ((bgproc_timeout>0)); then
    local timeout_proc="ble/util/bgproc#keepalive/.timeout $1"
    ble/function#try ble/util/idle.push --sleep="$bgproc_timeout" "$timeout_proc"
  fi
  return 0
}

_ble_util_bgproc_onclose_processing=
## @fn ble/util/bgproc#close prefix
##   Close the bgproc session.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
function ble/util/bgproc#close {
  # If the bgproc does not exist, do nothing.
  ble/util/bgproc#opened "$1" || return 2

  local prefix=${1}
  blehook unload-="ble/util/bgproc#close $prefix"
  ble/util/bgproc#keepalive/.cancel-timeout "$prefix"

  # When the callback function "ble/util/bgproc/onclose:PREFIX" is defined, we
  # call the function before starting the closing process.  However, we skip
  # this if the present call of "ble/util/bgproc#close" is already from inside
  # the callback, we skip it to avoid the infinite recursion.
  if ble/is-function ble/util/bgproc/onclose:"$prefix"; then
    if [[ :${_ble_util_bgproc_onclose_processing-}: != *:"$prefix":* ]]; then
      local _ble_util_bgproc_onclose_processing=${_ble_util_bgproc_onclose_processing-}:$prefix
      ble/util/bgproc/onclose:"$prefix"
    fi
  fi

  ble/util/bgproc#stop "$prefix"
  builtin eval -- "${prefix}_bgproc=() ${prefix}_bgproc_fname=()"
}

## @fn ble/util/bgproc#use prefix
##   Ensure the file descriptors to be ready for uses.  When the background
##   process is temporarily stopped, this will restart the background process.
##   When the background process was terminated unexpectedly and "restart" is
##   specified to the bgproc's OPTS, this will also restart the background
##   process.
##
##   @param[in] prefix
##     The name to identify the bgproc.
##
##   @exit 0 if the background process is ready.  2 if the specified PREFIX
##   does not correspond to an existing bgproc.  3 if the system does not seem
##   to support named pipes.  1 if the background process was stopped and
##   failed to restart it.
##
function ble/util/bgproc#use {
  local bgproc
  ble/util/restore-vars "${1}_" bgproc
  if ((!${#bgproc[@]})); then
    ble/util/print "$FUNCNAME: $1: not an existing bgproc name." >&2
    return 2
  fi

  if [[ ! ${bgproc[4]-} ]]; then
    # The background process has been stopped intenstionally.  We automatically
    # restart the background process in this case.
    ble/util/bgproc#start "$1" || return "$?"
  elif ! kill -0 "${bgproc[4]-}"; then
    # The background process died unexpectedly
    if [[ :${bgproc[3]-}: == *:restart:* ]]; then
      ble/util/bgproc#start "$1" || return "$?"
    else
      return 1
    fi
  else
    ble/util/bgproc#keepalive "$1"
    return 0
  fi
}

function ble/util/bgproc#post {
  ble/util/bgproc#use "$1" || return "$?"
  local fd1_ref=${1}_bgproc[1]
  ble/util/print "$2" >&"${!fd1_ref}"
}
