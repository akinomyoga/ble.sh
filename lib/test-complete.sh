# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

function ble-test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    echo "fail: command=($f $in) result=($ret) expected=($expected)" >&2
}

function ble-test:ble-complete/candidates/filter:hsubseq/match {
  local args arr; args=($1)
  ble-complete/candidates/filter:hsubseq/match "${args[@]}"; arr=("${ret[@]}")

  local text=${args[1]} p0=0 out=
  for ((i=0;i<${#arr[@]};i++)); do
    ((p=arr[i]))
    if ((i%2==0)); then
      out=$out${text:p0:p-p0}'['
    else
      out=$out${text:p0:p-p0}']'
    fi
    p0=$p
  done
  ((p0<${#text})) && out=$out${text:p0}

  ret=$out
}

ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'akf Makefile 0' 'M[ak]e[f]ile'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'akf Makefile 1' 'Makefile'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'Mkf Makefile 1' '[M]a[k]e[f]ile'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'Maf Makefile 1' '[Ma]ke[f]ile'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'Mak Makefile 1' '[Mak]efile'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'ake Makefile 0' 'M[ake]file'
ble-test/check-ret ble-test:ble-complete/candidates/filter:hsubseq/match 'afe Makefile 0' 'M[a]ke[f]il[e]'
