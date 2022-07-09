# bashrc -*- mode: sh; mode: sh-bash -*-

# 2022-07-10 Debug fzf & zoxide completion

source ~/.mwg/src/ble.sh/out/ble.sh --norc
_ble_contrib_fzf_base=~/.mwg/git/junegunn/fzf
if [[ ${BLE_VERSION-} ]]; then
  ble-import -d contrib/fzf-completion
  ble-import -d contrib/fzf-key-bindings
  #eval "$(zoxide init bash | grep -v '\\\e\[[0-9]n')"
  eval "$(zoxide init bash)"

  function _z() {
    [[ :$comp_type: == *:auto:* || :$comp_type: == *:[maA]:* ]] && return
    compopt -o noquote
    #--------------------------------------------------------------------------

    # Only show completions when the cursor is at the end of the line.
    [[ ${#COMP_WORDS[@]} -eq $((COMP_CWORD + 1)) ]] || return

    # If there is only one argument, use `cd` completions.
    if [[ ${#COMP_WORDS[@]} -eq 2 ]]; then
      \builtin mapfile -t COMPREPLY < \
               <(\builtin compgen -A directory -S / -- "${COMP_WORDS[-1]}" || \builtin true)
      # If there is a space after the last word, use interactive selection.
    elif [[ -z ${COMP_WORDS[-1]} ]]; then
      \builtin local result
      result="$(\command zoxide query -i -- "${COMP_WORDS[@]:1:${#COMP_WORDS[@]}-2}")" &&
        COMPREPLY=("${__zoxide_z_prefix}${result@Q}")
      \builtin printf '\e[5n'
    fi

    ble/textarea#invalidate

    #--------------------------------------------------------------------------
    # 単一候補生成の場合は他の候補 (sabbrev 等) を消去して単一確定させる
    if ((ADVICE_EXIT==0&&${#COMPREPLY[@]}==1)); then
      ble/complete/candidates/clear
      [[ $old_cand_count ]] &&
        ! ble/variable#is-global old_cand_count &&
        old_cand_count=0
    fi
  } >/dev/null

else
  PATH=$PWD/bin:$PATH
  source "$_ble_contrib_fzf_base/shell/completion.bash"
  eval "$(zoxide init bash)"
fi
