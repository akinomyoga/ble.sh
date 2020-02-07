# bash -*- mode: sh; mode: sh-bash -*-

if ((!_ble_bash)); then
  echo 'This script should be sourced into a ble.sh session' >&2
  return 1
elif ((_ble_bash>=40000)); then
  echo 'This source script is for bash 3.X' >&2
  return 1
fi

echo '# Check arr2=("${arr1[@]}")'
arr1[0]=
arr1[1]=
arr2=("${arr1[@]}")
ble/util/declare-print-definitions arr1 arr2 | cat -A
echo

echo '# Check arr1=(1 "$del" "$soh")'
_ble_term_DEL=
_ble_term_SOH=
arr1=(1 "$_ble_term_DEL" "$_ble_term_SOH")
ble/util/declare-print-definitions arr1 | cat -A
echo

echo '# Check arr1=(2 $del $soh)'
_ble_term_DEL=
_ble_term_SOH=
arr1=(2 $_ble_term_DEL $_ble_term_SOH)
arr2=(2 ''$_ble_term_DEL'' ''$_ble_term_SOH'')
ble/util/declare-print-definitions arr1 arr2 | cat -A
echo

# 以下は全部駄目。値が変化してしまう。
echo "# Check arr1=(3 \$'\\001' \$'\\177')"
arr1=(3 $'\001' $'\177')
arr2=(3  )
arr3=(3 '' '')
ble/util/declare-print-definitions arr1 arr2 arr3 | cat -A
echo
