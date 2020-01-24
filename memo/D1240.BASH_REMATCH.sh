# bash source

rex='1..4'; [[ 1444 =~ $rex ]]
declare -p BASH_REMATCH

function fun1 {
  local BASH_REMATCH
  declare -p BASH_REMATCH
  local rex='1..4'
  [[ 1234 =~ $rex ]]
  declare -p BASH_REMATCH
}
fun1

declare -p BASH_REMATCH
