# bashrc

function measure1 {
  time1=($(date +'%s %N'))
}
function measure2 {
  local -a time2=($(date +'%s %N'))
  local sec=$((time2[0]-time1[0]))
  local usec=$((sec*1000000+10#${time2[1]}/1000-10#${time1[1]}/1000))
  echo "${usec} us" >/dev/tty
}

function taisaku1 {
  count=($(history 1))
  echo count=${count[0]}
  ((HISTSIZE=count*2))
}

export HISTFILE=memo/D0702.HISTFILE
export HISTSIZE=100000
export HISTFILESIZE=100000
shopt -s histappend
history -n
taisaku1
measure1
PS1='$(measure2)'$PS1
