#!/bin/bash

# ble/unicode/EmojiStatus 128512; echo $ret
# ble/unicode/EmojiStatus 128529; echo $ret
# ble/unicode/EmojiStatus 128533; echo $ret
# ble/unicode/EmojiStatus 128535; echo $ret
# ble/unicode/EmojiStatus 128537; echo $ret
# ble/unicode/EmojiStatus 128539; echo $ret
# ble/unicode/EmojiStatus 128543; echo $ret
# ble/unicode/EmojiStatus 128550; echo $ret
# ble/unicode/EmojiStatus 128556; echo $ret
# ble/unicode/EmojiStatus 128558; echo $ret
# ble/unicode/EmojiStatus 128564; echo $ret

function list-range-code-for-version-detection {
  local nversion=$_ble_unicode_c2w_UnicodeVersionCount
  local _ble_unicode_c2w_ambiguous=3
  local ver ret prev_ver
  for ((ver=1;ver<nversion;ver++)); do
    prev_ver=$((ver-1))

    local code
    for code in "${!_ble_unicode_c2w[@]}"; do
      ble/unicode/EmojiStatus "$code"
      ((ret)) && continue
      local -a _ble_unicode_c2w_custom=()
      _ble_unicode_c2w_version=$prev_ver ble/unicode/c2w "$code"; local oldw=$ret
      _ble_unicode_c2w_version=$ver ble/unicode/c2w "$code"; local neww=$ret
      ble/util/unlocal _ble_unicode_c2w_custom
      ((oldw==neww||oldw==3&&neww>0||neww==3&&oldw>0)) && continue

      ble/util/c2s "$code"; local ch=$ret

      local note=
      if [[ ${_ble_unicode_c2w_custom[code]} ]]; then
        note="${note:+$note, }overwritten by wcwidth-custom"
      fi

      printf 'ver%s U+%04X(%d) %s %d->%d (%s)%s\n' \
             "$ver" "$code" "$code" "$ch" \
             "$oldw" "$neww" "${_ble_unicode_c2w_UnicodeVersionMapping[*]:_ble_unicode_c2w[code]*nversion:nversion}" \
             "${note:+ # $note}"
    done
  done

  printf '               | %-*s|musl\n' "$((nversion*3))" '-----Unicode EAW+GeneralCategory'
  local -a keys=(
    U+9FBC  U+9FC4  U+31B8  U+D7B0
    U+3099  U+9FCD  U+1F93B U+312E
    U+312F  U+16FE2 U+32FF  U+31BB
    U+9FFD  U+1B132)
  local code index=0 ret
  for code in "${keys[@]}"; do
    ((code=16#${code#U+}))
    ble/unicode/EmojiStatus "$code"
    if ((ret)); then
      printf 'U+%04X: emoji cannot be used to detect the Unicode version\n' "$code" >&2
      continue
    fi

    local c2w=${_ble_unicode_c2w[code]}
    if [[ ! $c2w ]]; then
      local c=$code
      until [[ $c2w || c -eq 0 ]]; do c2w=${_ble_unicode_c2w[--c]}; done
      if [[ $c2w ]]; then
        printf 'U+%04X: warning: not c2w boundary. borrow the data of boundary U+%04X\n' "$code" "$c" >&2
      else
        printf 'U+%04X: this is not c2w boundary\n' "$code" >&2
        continue
      fi
    fi

    local width_vec=$(printf ' %2d' "${_ble_unicode_c2w_UnicodeVersionMapping[@]:c2w*nversion:nversion}")
    ble/util/c2w:musl "$code"; local c2w_musl=$ret
    printf '%-6s U+%05X |%s |%2d\n' "ws[$((index++))]" "$code" "$width_vec" "$c2w_musl"
  done
}
list-range-code-for-version-detection
