
_histcmd='\!'
print-histcmd() {
  local history_histcmd=$(history 1 | cut -d ' ' -f 1)
  echo "histcmd=$HISTCMD;${_histcmd@P};$history_histcmd lineno=$LINENO;${BASH_LINENO[-1]}(${#BASH_LINENO[@]})"
}
unset HISTCMD
PROMPT_COMMAND='print-histcmd'
