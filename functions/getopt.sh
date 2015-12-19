# bash source -*- mode:sh; mode:sh-bash -*-

ble_getopt_locals=(_optargs _optchars _optarg _opterror OPTIND OPTION OPTARG)
function ble/getopt.init {
  _optargs=("$@")
  _optchars= _optarg= _opterror=
  OPTIND=1 OPTION= OPTARG=
}
function ble/getopt.print-argument-message {
  local index=$((OPTIND-1))
  echo "${_optargs[0]##*/} (argument#$index \`${_optargs[index]}'): $*">&2
}
function ble/getopt.print-message {
  local index=$((OPTIND-1))
  echo "${_optargs[0]##*/} (arguments): $*">&2
}

function ble/getopt.next {
  ble/getopt/.check-optarg-cleared
  if ((${#_optchars})); then
    OPTION=-${_optchars::1}
    _optchars=${_optchars:1}
  elif ((OPTIND<${#_optargs[@]})); then
    OPTION=${_optargs[OPTIND++]}
    if [[ $OPTION == -[^-]* ]]; then
      _optchars=${OPTION:2}
      OPTION=${OPTION::2}
    elif [[ $OPTION == --*=* ]]; then
      _optarg==${OPTION#--*=}
      OPTION=${OPTION%%=*}
    fi
  else
    return 1
  fi
}

# optarg
function ble/getopt.get-optarg {
  if [[ $_optarg ]]; then
    OPTARG=${_optarg:1}
    _optarg=
  elif ((OPTIND<${#_optargs[@]})); then
    OPTARG=${_optargs[OPTIND++]}
  else
    return 1
  fi
}
function ble/getopt.has-optarg {
  [[ $_optarg ]]
}
function ble/getopt/.check-optarg-cleared {
  if [[ $_optarg ]]; then
    ble/getopt.print-argument-message "the option argument \`${_optarg:1}' is not processed ">&2
    _opterror=1 _optarg=
  fi
}

function ble/getopt.finalize {
  ble/getopt/.check-optarg-cleared
  
  [[ ! $_opterror ]]
}

