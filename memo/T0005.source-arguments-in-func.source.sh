# -*- mode: sh; mode: sh-bash -*-

args=("$0" "$@")
declare -p args
declare -p FUNCNAME
declare -p BASH_LINENO
declare -p BASH_SOURCE
declare -p BASH_ARGC
declare -p BASH_ARGV

# 呼び出しを行った後で extdebug を実行しても意味ない
# shopt -s extdebug
# declare -p BASH_ARGC
# declare -p BASH_ARGV
# shopt -u extdebug
echo ----------------------------------------

