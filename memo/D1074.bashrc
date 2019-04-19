# bashrc -*- mode: sh; mode: sh-bash -*-

# test case from https://qiita.com/kxn4t/items/bd85397914a22e69cefd
#source ~/.git-prompt.sh

GIT_PS1_SHOWDIRTYSTATE=true
GIT_PS1_SHOWUNTRACKEDFILES=true
GIT_PS1_SHOWSTASHSTATE=true
GIT_PS1_SHOWUPSTREAM="auto"

# define for PS1
black=$'\e[30m' # Black - Regular
red=$'\e[31m' # Red
green=$'\e[32m' # Green
yellow=$'\e[33m' # Yellow
blue=$'\e[34m' # Blue
purple=$'\e[35m' # Purple
cyan=$'\e[36m' # Cyan
white=$'\e[37m' # White
gray=$'\e[90m' # Gray
reset=$'\e[m'

# add new line after the output
function add_line {
  if [[ -z "${PS1_NEWLINE_LOGIN}" ]]; then
    PS1_NEWLINE_LOGIN=true
  else
    printf '\n'
  fi
}
#PROMPT_COMMAND='add_line'

function check_result_yunocchi {
  if [ $? -eq 0 ]; then
    face="\001${yellow}\002 ✖╹◡╹✖"
  else
    face="\001${red}\002 xX_Xx"
  fi

  echo -e "${face}\001${reset}\002 < "
}

# output prompt
#prefix="\u \[$purple\]\w\[$reset\]\[$cyan\] "'$(__git_ps1 "(%s)")'"\[$reset\]\n"
prefix="\u \[$purple\]\w\[$reset\]\[$cyan\] \[$reset\]\n"
PS1="${prefix}"'$(check_result_yunocchi)'
