# bashrc

HISTFILE=A
source out/ble.sh
blehook ADDHISTORY=myfunction
function myfunction { [[ $1 != ' '* ]]; }
#function myfunction { false; }
#function myfunction { echo "[$1,$command](${FUNCNAME[*]})"; }
function myfunction {
  if [[ $1 == ' '* ]]; then
    history -s "#$1"
    return 1
  fi
}
