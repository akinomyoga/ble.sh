# bashrc

HISTFILE=A.txt
HISTTIMEFORMAT='[%F %T]  '
#HISTTIMEFORMAT=
#HISTTIMEFORMAT='__ble_time_%s__'
HISTSIZE=
HISTFILESIZE=
shopt -s histappend
source out/ble.sh

#bleopt history_lazyload=
bleopt history_share=1
ble-attach
