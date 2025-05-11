# bashrc

# HISTSIZE=
# HISTSIZE=a
# HISTSIZE=100a
#HISTSIZE=100 #limited
#HISTSIZE=100.0
#HISTSIZE=0 #limited
#HISTSIZE=-
#HISTSIZE=-1
#HISTSIZE=4294967552 # limited to 256
#HISTSIZE=-2147483904
#HISTSIZE=-2415918848
#HISTSIZE=-4294967040 # limited to 256
#HISTSIZE=+100 # limited to 100
#HISTSIZE=' 100 ' # limited
#HISTSIZE='100 ' # limited
#HISTSIZE=' 100' # limited
#HISTSIZE='1 000'
#HISTSIZE='+ 100'
#HISTSIZE=2147483648 # unlimited?
# HISTSIZE='
# 100' # limited
#HISTSIZE='+'

# bash-4.2..3.0
#HISTSIZE='  ' # unlimited
#HISTSIZE='unlimited' # unlimited
#HISTSIZE=-1 # limited to 0
#HISTSIZE=' 100 ' # limited
# HISTSIZE='
# 100' # limited

HISTFILE='D2346.bash_history'
HISTFILESIZE="$HISTSIZE"

printf 'echo Hello, %d\n' {0..9999} >| "$HISTFILE"
