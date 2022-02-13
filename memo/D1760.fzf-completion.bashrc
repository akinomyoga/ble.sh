#!/bin/bash

source out/ble.sh --norc

source ~/.mwg/git/scop/bash-completion/bash_completion

_ble_contrib_fzf_base=~/.mwg/git/junegunn/fzf
if [[ ${BLE_VERSION-} ]]; then
  ble-import -d contrib/fzf-completion
else
  PATH=$PATH:$_ble_contrib_fzf_base/bin
  source $_ble_contrib_fzf_base/shell/completion.bash
fi

if [[ ${BLE_VERSION-} ]]; then
  ble-attach
fi
