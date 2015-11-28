# ble.sh
*Bash Line Editor* written in Bash Scripts.
- Replaces GNU Readline, the default line editor of GNU Bash.
- Syntax highlighting of command lines (as in `fish` shell)
- Syntax-aware completion

This script supports `bash` with the versions, 3.0 or larger.

Currently, only the `utf-8` encoding is supported for non-ASCII characters.

This script is provided under the **BSD License** (3-clause BSD license).

##Usage
First, generate `ble.sh` using the following commands:
```bash
$ git clone git@github.com:akinomyoga/ble.sh.git
$ cd ble.sh
$ make
```
A script file `ble.sh` will be generated in the directory `ble.sh/out`. Then, load `ble.sh` using the `source` command:
```bash
$ source out/ble.sh
```

If you would like to load `ble.sh` defaultly in the interactive sessions of `bash`, add the following codes to your .bashrc file:
```bash
# bashrc

# Add this line at the top of .bashrc:
if [[ $- == *i* ]]; then
  source /path/to/ble.sh/out/ble.sh noattach
  
  # settings for ble.sh...
fi

# your bashrc settings come here...

# Add this line at the end of .bashrc:
((_ble_bash)) && ble-attach
```

##Basic settings
Most settings for `ble.sh` are to be specified after the source of `ble.sh`.
```bash
...

if [[ $- == *i* ]]; then
  source /path/to/ble.sh/out/ble.sh noattach
  
  # ***** Settings Here *****
fi

...
```

**CJK Width**

The option `char_width_mode` controls the width of the unicode characters with `East_Asian_Width=A` (Ambiguous characters). Currently three values `emacs`, `west`, and `east` are supported. With the value `emacs`, the default width in emacs is used. With the value `west` all the ambiguous characters have the width 1 (Hankaku). With the value `east` all the ambiguous characters have the width 2 (Zenkaku). The default value is `emacs`. Appropriate value should be chosen in accordance with your terminal behavior. For example, the value can be changed to `east` as:

```
bleopt char_width_mode='east'
```

**Input Encoding**

The option `input_encoding` controls the encoding scheme used in the decode of input. Currently `UTF-8` and `C` are available. With the value `C`, byte values are directly interpreted as the character code. The default value is `UTF-8`. For example, the value can be changed to `C` as:

```
bleopt input_encoding='C'
```

**Bell**

The options `edit_abell` and `edit_vbell` control the behavior of the edit function `bell`. If `edit_abell` is a non-empty string, audible bell is enabled, i.e. ASCII Control Character `BEL` (0x07) will be written in `stderr`. If `edit_vbell` is a non-empty string, visual bell is enabled. Defaultly, the audible bell is enabled while the visual bell is disabled.

The option `vbell_default_message` specifies the message shown as the visual bell. The default value is `' Wuff, -- Wuff!! '`. The option `vbell_duration` specifies the display duration of the visual-bell message. The unit is millisecond. The default values is `2000`.

For example, the visual bell can be enabled as:
```
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

