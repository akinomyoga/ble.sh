#!/bin/bash

# # usage
#
# declare "${ble_getopt_locals[@]}"
# ble/getopt.init "$0" "$@"
#
# while ble/getopt.next; do
#   case "$OPTION" in
#   (-a|--hoge)
#     echo hoge ;;
#   esac
# done
#
# if ! ble/getopt.finalize; then
#   print-usage
#   return 1
# fi

source getopt.sh

function command1 {
  eval "$ble_getopt_prologue"
  ble/getopt.init "$0" "$@"

  while ble/getopt.next; do
    case "$OPTION" in
    (-b|--bytes)  ble/bin/echo bytes  ;;
    (-s|--spaces) ble/bin/echo spaces ;;
    (-w|--width)
      if ! ble/getopt.get-optarg; then
        ble/getopt.print-argument-message "missing an option argument for $OPTION"
        _opterror=1
        continue
      fi
      ble/bin/echo "width=$OPTARG" ;;
    (--char-width|--tab-width|--indent-type)
      if ! ble/getopt.get-optarg; then
        ble/getopt.print-argument-message "missing an option argument for $OPTION"
        _opterror=1
        continue
      fi
      ble/bin/echo "${OPTION#--} = $OPTARG" ;;
    (--continue)
      if ble/getopt.has-optarg; then
        ble/getopt.get-optarg
        ble/bin/echo "continue = $OPTARG"
      else
        ble/bin/echo "continue"
      fi ;;
    (-i|--indent)
      if ble/getopt.has-optarg; then
        ble/getopt.get-optarg
        ble/bin/echo "indent = $OPTARG"
      else
        ble/bin/echo "indent"
      fi ;;
    (--text-justify|--no-text-justify)
      ble/bin/echo "${OPTION#--}" ;;
    (-[^-]*|--?*)
      ble/getopt.print-argument-message "unknown option."
      _opterror=1 ;;
    (*)
      ble/getopt.print-argument-message "unknown argument."
      _opterror=1 ;;
    esac
  done

  if ! ble/getopt.finalize; then
    ble/bin/echo "usage: getopt-test.sh [options]" >&2
    builtin exit 1
  fi
}

command1 -b --bytes -w 1 --width 10 --width=123 \
         --char-width --continue=10 --continue \
         -i --indent --indent= \
         --text-justify --unknown argument

