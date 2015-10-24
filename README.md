# ble.sh
Bash Line Editor - replaces GNU Readline, the default line editor of GNU Bash.

##Usage
First, generate `ble.sh` using the following commands:
```bash
$ cd ble.sh
$ make
```
The script file `ble.sh` will be generated in the directory `ble.sh/out`.

Add the following codes to your .bashrc file.
```bash
# bashrc

# Add the follwing line at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/ble.sh/out/ble.sh noattach

# your bashrc settings come here...

# Add the following line at the end of .bashrc:
((_ble_bash)) && ble-attach
```

