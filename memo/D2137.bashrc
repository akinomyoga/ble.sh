# 2024-02-04

source out/ble.sh --norc
ble/function#advice \
  after ble/decode/cmap/decode-chars \
  '[[ ${keyseq-} ]] && ble/debug/print-variables keyseq chars keys'
bind '"\e[A": "\C-x\xC0\x96\C-x\xC0\x8F\C-x\xC0\x8D"'
bind '"\C-x\xC0\x96": ""'
bind '"\C-x\xC0\x8F": ""'
bind '"\C-x\xC0\x8D": ""'
bind '"\e": ""'
bind '"\e\e": ""'
bind '"\e[123": ""'
ble/function#advice \
  clear ble/decode/cmap/decode-chars
