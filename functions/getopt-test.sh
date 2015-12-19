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
  declare "${ble_getopt_locals[@]}"
  ble/getopt.init "$0" "$@"

  while ble/getopt.next; do
    case "$OPTION" in
    (-b|--bytes)  echo bytes  ;;
    (-s|--spaces) echo spaces ;;
    (-w|--width)
      if ! ble/getopt.get-optarg; then
        ble/getopt.print-argument-message "missing an option argument for $OPTION"
        _opterror=1
        continue
      fi
      echo "width=$OPTARG" ;;
    (--char-width|--tab-width|--indent-type)
      if ! ble/getopt.get-optarg; then
        ble/getopt.print-argument-message "missing an option argument for $OPTION"
        _opterror=1
        continue
      fi
      echo "${OPTION#--} = $OPTARG" ;;
    (--continue)
      if ble/getopt.has-optarg; then
        ble/getopt.get-optarg
        echo "continue = $OPTARG"
      else
        echo "continue"
      fi ;;
    (-i|--indent)
      if ble/getopt.has-optarg; then
        ble/getopt.get-optarg
        echo "indent = $OPTARG"
      else
        echo "indent"
      fi ;;
    (--text-justify|--no-text-justify)
      echo "${OPTION#--}" ;;
    (-[^-]*|--?*)
      ble/getopt.print-argument-message "unknown option."
      _opterror=1 ;;
    (*)
      ble/getopt.print-argument-message "unknown argument."
      _opterror=1 ;;
    esac
  done

  if ! ble/getopt.finalize; then
    echo "usage: getopt-test.sh [options]" >&2
    exit 1
  fi
}

command1 -b --bytes -w 1 --width 10 --width=123 \
         --char-width --continue=10 --continue \
         -i --indent --indent= \
         --text-justify --unknown argument

