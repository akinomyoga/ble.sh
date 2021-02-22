# bashrc -*- mode: sh-bash; -*-

sub=T0005.source-arguments-in-func.source.sh

function sourcer1 { source "$sub"; }
function sourcer2 { source "$sub" x; }

sourcer1 A B C
sourcer2 A B C
shopt -s extdebug
sourcer1 A B C
sourcer2 A B C
