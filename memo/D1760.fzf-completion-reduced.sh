
_fzf_host_completion () {
  _fzf_complete +m -- "$@" < <(
    command cat <(
      command tail -n +1 ~/.ssh/config ~/.ssh/config.d/* /etc/ssh/ssh_config 2> /dev/null |
        command grep -i '^\s*host\(name\)\? ' |
        awk '{for (i = 2; i <= NF; i++) print $1 " " $i}' |
        command grep -v '[*?]'
    ) <(
      command grep -oE '^[[a-z0-9.,:-]+' ~/.ssh/known_hosts |
        tr ',' '\n' |
        tr -d '[' |
        awk '{ print $1 " " $1 }'
    ) <(
      command grep -v '^\s*\(#\|$\)' /etc/hosts | command grep -Fv '0.0.0.0'
    ) | awk '{if (length($2) > 0) {print $2}}' | sort -u
  )
}


function generate1 {
  {
    command tail -n +1 ~/.ssh/config ~/.ssh/config.d/* /etc/ssh/ssh_config 2> /dev/null |
      command grep -i '^\s*host\(name\)\? ' |
      awk '{for (i = 2; i <= NF; i++) print $1 " " $i}' |
      command grep -v '[*?]'
    command grep -oE '^[[a-z0-9.,:-]+' ~/.ssh/known_hosts |
      tr ',' '\n' |
      tr -d '[' |
      awk '{ print $1 " " $1 }'
    command grep -v '^\s*\(#\|$\)' /etc/hosts |
      command grep -Fv '0.0.0.0'
  } | awk '{if (length($2) > 0) {print $2}}' | sort -u
}

function generate2 {
  cat <<EOF
aur.archlinux.org
bitbucket.org
chat
chatoyancy.home
front1
gell-mann
github.com
gitlab.com
hankel
hp2019
laguerre
ln25
localhost
mag
magnate
magnate2016
magnate2016.home
magnate2018.home
mercury
neumann
pad
padparadscha
padparadscha.home
song123
tkynt2
tkyntn
EOF
}
