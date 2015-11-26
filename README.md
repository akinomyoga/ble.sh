# ble.sh
*Bash Line Editor* written in Bash Scripts.
- Replaces GNU Readline, the default line editor of GNU Bash.
- Syntax highlighting of command lines (as in `fish` shell)
- Syntax-aware completion

##Usage
First, generate `ble.sh` using the following commands:
```bash
$ git clone git@github.com:akinomyoga/ble.sh.git
$ cd ble.sh
$ make
```
A script file `ble.sh` will be generated in the directory `ble.sh/out`. Then, load `ble.sh` using the `source` command:
```bash
$ source ble.sh
```

If you would like to load `ble.sh` defaultly in the interactive sessions of `bash`, add the following codes to your .bashrc file:
```bash
# bashrc

# Add this line at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/ble.sh/out/ble.sh noattach

# your bashrc settings come here...

# Add this line at the end of .bashrc:
((_ble_bash)) && ble-attach
```

