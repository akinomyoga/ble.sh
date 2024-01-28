# D2122 https://github.com/akinomyoga/ble.sh/issues/394

if ble/bin#has kubectl; then
  eval "$(kubectl completion bash)"
else
  # https://github.com/akinomyoga/ble.sh/issues/394#issuecomment-1913122045
  source bashrc.kubectl
fi

source /etc/profile.d/bash_completion.sh

kubectl() { echo "KUBECTL $*" >/dev/tty; }
alias k=kubectl
complete -o default -F __start_kubectl k

alias e='echo hello >/dev/tty'
complete -F _test1 test1
_test1() { eval "e xxxx"; }

complete -F _test2 test2
_test2() { eval "e xxxx" | cat; }

complete -F _test3 test3
_test3() { (eval "e xxxx"); }

complete -F _test4 test4
_test4() { eval "e xxxx" & wait; }

complete -F _test5 test5
_test5() {
  if ble/complete/check-cancel <&"$_ble_util_fd_stdin"; then
    echo 'CANCELED' >/dev/tty
    ((_ble_decode_input_count)) && echo _ble_decode_input_count
    ((ble_decode_char_rest)) && echo ble_decode_char_rest
    ble/util/is-stdin-ready && echo stdin-ready
    ble/encoding:"$bleopt_input_encoding"/is-intermediate && echo UTF-8 intermediate
    ble-decode-char/is-intermediate && echo decode-char/intermediate
    return 1
  fi
  ble/util/conditional-sync \
    'e xxxx' \
    "! ble/complete/check-cancel <&$_ble_util_fd_stdin" 128 progressive-weight:killall
}

complete -F _test6 test6
_test6() { (eval "e xxxx" & wait); }

complete -F _test7 test7
_test7() { [[ str ]] && eval "e xxxx" & }
