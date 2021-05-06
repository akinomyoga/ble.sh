

complete -C 'a'   aws1
complete -C $'\n' aws2
complete -C $'\a' aws3
complete -C ''\''' aws4
complete -C ''\''hello'\''' aws5
complete -p
complete -r

complete -C a 'aws 1'
complete -C a 'aws'\''2'
complete -C a $'aws\n2'
complete -C a $'aws\a2'
complete -p
complete -r

complete -W 'a b' aws1
complete -W 'a'\''b' aws2
complete -W $'a\nb' aws3
complete -W $'a\ab' aws4
complete -p
complete -r

complete -G 'a b'    -X 'a b'    aws1
complete -G 'a'\''b' -X 'a'\''b' aws2
complete -G $'a\nb'  -X $'a\nb'  aws3
complete -G $'a\ab'  -X $'a\ab'  aws4
complete -p
complete -r

complete -P 'a b'    -S 'a b'    aws1
complete -P 'a'\''b' -S 'a'\''b' aws2
complete -P $'a\nb'  -S $'a\nb'  aws3
complete -P $'a\ab'  -S $'a\ab'  aws4
complete -p
complete -r

complete -o bashdefault -P P -S S -G G -X X -W W -A user -C callback -F func aws1
complete -o bashdefault -P P -S S -G G -X X -W W -A running -C callback -F func aws2
complete -o bashdefault -P P -S S -G G -X X -W W -A user -C callback -F func -D
complete -o bashdefault -P P -S S -G G -X X -W W -A user -C callback -F func -I
complete -p

