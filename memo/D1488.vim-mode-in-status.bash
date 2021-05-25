#!/bin/bash

function 0neGal/set-up-status-line {

  # Hide the normal mode name
  bleopt keymap_vi_mode_show=

  function ble/prompt/backslash:0neGal/currentmode {
    bleopt keymap_vi_mode_update_prompt=1

    local mode; ble/keymap:vi/script/get-mode
    case $mode in
    (*n)  ble/prompt/print $'\e[1m-- NORMAL --\e[m' ;;
    (*v)  ble/prompt/print $'\e[1m-- VISUAL --\e[m' ;;
    (*V)  ble/prompt/print $'\e[1m-- V-LINE --\e[m' ;;
    (*) ble/prompt/print $'\e[1m-- V-BLOQ --\e[m' ;;
    (*s)  ble/prompt/print $'\e[1m-- SELECT --\e[m' ;;
    (*S)  ble/prompt/print $'\e[1m-- S-LINE --\e[m' ;;
    (*) ble/prompt/print $'\e[1m-- S-BLOQ --\e[m' ;;
    (i)   ble/prompt/print $'\e[1m-- INSERT --\e[m' ;;
    (R)   ble/prompt/print $'\e[1m-- RPLACE --\e[m' ;;
    ()  ble/prompt/print $'\e[1m-- VPLACE --\e[m' ;;
    (*)   ble/prompt/print $'\e[1m-- ?????? --\e[m' ;;
    esac

    # Change the default color of status line
    case $mode in 
    (*n)          ble-face prompt_status_line=bg=gray,fg=white ;;
    (*[vVsS]) ble-face prompt_status_line=bg=teal,fg=white ;;
    (*[iR])     ble-face prompt_status_line=bg=navy,fg=white ;;
    (*)           ble-face prompt_status_line=bg=240,fg=231 ;;
    esac
  }

  # In this example, we put the mode string, date and time, and the
  # current working directory in the status line.
  bleopt prompt_status_line='\q{0neGal/currentmode}\r\e[96m\w\e[m\r\D{%F %H:%M}'
}
blehook/eval-after-load keymap_vi 0neGal/set-up-status-line
