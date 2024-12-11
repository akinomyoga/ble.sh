# bashrc

source ~/.opt/bash-completion/2.11/share/bash-completion/bash_completion
source ~/.mwg/src/ble.sh/out/ble.sh --norc
#ble/bin/awk() { mawk-1.3.4-20230525 -v AWKTYPE=mawk "$@"; }
ble/bin/awk() { mawk-1.3.4-20200120 -v AWKTYPE=mawk "$@"; }
unset -f ble/bin/gawk
