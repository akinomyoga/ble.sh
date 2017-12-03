[Languages: **:us: English** | [:jp: 日本語](README-ja_JP.md)]
# ble.sh

*Bash Line Editor* is a command line editor written in pure Bash scripts to replace the default GNU Readline.
- Syntax highlighting of command lines (as in `fish` shell)
- Syntax-aware completion
- Enhanced vim mode

This script supports `bash` with the version 3.0 or later.

Currently, only `UTF-8` encoding is supported for non-ASCII characters.

This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/demo.gif)

## Usage
**Generate `ble.sh` from source**

To generate `ble.sh`, `gawk` (GNU awk) and `gmake` (GNU make) is required.
The file `ble.sh` can be generated using the following commands.
If you have GNU make installed on `gmake`, please use `gmake` instead of `make`.
```console
$ git clone https://github.com/akinomyoga/ble.sh.git
$ cd ble.sh
$ make
```
A script file `ble.sh` will be generated in the directory `ble.sh/out`. Then, load `ble.sh` using the `source` command:
```console
$ source out/ble.sh
```
If you want to install `ble.sh` in a specified directory, use the following command (if `INSDIR` is not specified, the default location `${XDG_DATA_DIR:-$HOME/.local/share}/blesh` is used):
```console
$ make INSDIR=/path/to/blesh install
```

**Or, download `ble.sh`** (201512 stable, old)

With `wget`:
```console
$ wget https://github.com/akinomyoga/ble.sh/releases/download/v0.1.7/ble-0.1.7.tar.xz
$ tar xJf ble-0.1.7.tar.xz
$ source ble-0.1.7/ble.sh
```
With `curl`:
```console
$ curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.1.7/ble-0.1.7.tar.xz
$ tar xJf ble-0.1.7.tar.xz
$ source ble-0.1.7/ble.sh
```

If you want to place `ble.sh` in a specific directory, just copy the directory:
```console
$ cp -r ble-0.1.7 /path/to/blesh
```

**Setup `.bashrc`**

If you want to load `ble.sh` defaultly in interactive sessions of `bash`, add the following codes to your `.bashrc` file:
```bash
# bashrc

# Add these lines at the top of .bashrc:
if [[ $- == *i* ]]; then
  source /path/to/blesh/ble.sh noattach
  
  # settings for ble.sh...
fi

# your bashrc settings come here...

# Add this line at the end of .bashrc:
((_ble_bash)) && ble-attach
```

## Basic settings
Most settings for `ble.sh` are to be specified after the `source` of `ble.sh`.
```bash
...

if [[ $- == *i* ]] && source /path/to/blesh/ble.sh noattach; then
  # ***** Settings Here *****
fi

...
```

**Vim mode***
For the vi/vim mode, check [the Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

**CJK Width**

The option `char_width_mode` controls the width of the unicode characters with `East_Asian_Width=A` (Ambiguous characters).
Currently three values `emacs`, `west`, and `east` are supported. With the value `emacs`, the default width in emacs is used.
With `west` all the ambiguous characters have width 1 (Hankaku). With `east` all the ambiguous characters have width 2 (Zenkaku).
The default value is `east`. Appropriate value should be chosen in accordance with your terminal behavior.
For example, the value can be changed to `west` as:

```bash
bleopt char_width_mode='west'
```

**Input Encoding**

The option `input_encoding` controls the encoding scheme used in the decode of input. Currently `UTF-8` and `C` are available. With the value `C`, byte values are directly interpreted as character codes. The default value is `UTF-8`. For example, the value can be changed to `C` as:

```bash
bleopt input_encoding='C'
```

**Bell**

The options `edit_abell` and `edit_vbell` control the behavior of the edit function `bell`. If `edit_abell` is a non-empty string, audible bell is enabled, i.e. ASCII Control Character `BEL` (0x07) will be written to `stderr`. If `edit_vbell` is a non-empty string, visual bell is enabled. Defaultly, the audible bell is enabled while the visual bell is disabled.

The option `vbell_default_message` specifies the message shown as the visual bell. The default value is `' Wuff, -- Wuff!! '`. The option `vbell_duration` specifies the display duration of the visual-bell message. The unit is millisecond. The default value is `2000`.

For example, the visual bell can be enabled as:
```
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

For another instance, the audible bell is disabled as:
```
bleopt edit_abell=
```

**Highlight Colors**

The colors and attributes used in the syntax highlighting are controled by `ble-color-setface` function. The following code reproduces the default configuration:
```bash
ble-color-setface region                   bg=60,fg=white
ble-color-setface disabled                 fg=gray
ble-color-setface overwrite_mode           fg=black,bg=51
ble-color-setface syntax_default           none
ble-color-setface syntax_command           fg=red
ble-color-setface syntax_quoted            fg=green
ble-color-setface syntax_quotation         fg=green,bold
ble-color-setface syntax_expr              fg=navy
ble-color-setface syntax_error             bg=203,fg=231
ble-color-setface syntax_varname           fg=202
ble-color-setface syntax_delimiter         bold
ble-color-setface syntax_param_expansion   fg=purple
ble-color-setface syntax_history_expansion bg=94,fg=231
ble-color-setface syntax_function_name     fg=purple
ble-color-setface syntax_comment           fg=gray
ble-color-defface syntax_document          fg=94
ble-color-defface syntax_document_begin    fg=94,bold
ble-color-setface command_builtin_dot      fg=red,bold
ble-color-setface command_builtin          fg=red
ble-color-setface command_alias            fg=teal
ble-color-setface command_function         fg=purple
ble-color-setface command_file             fg=green
ble-color-setface command_keyword          fg=blue
ble-color-setface command_jobs             fg=red
ble-color-setface command_directory        fg=navy,underline
ble-color-setface filename_directory       fg=navy,underline
ble-color-setface filename_link            fg=teal,underline
ble-color-setface filename_executable      fg=green,underline
ble-color-setface filename_other           underline
```

The color codes can be checked in output of the function `ble-color-show` (defined in `ble.sh`):
```console
$ ble-color-show
```

**Key Bindings**

Key bindings can be controlled with the shell function, `ble-bind`.
For example, with the following setting, "Hello, world!" will be inserted on typing `C-x h`
```bash
ble-bind -f 'C-x h' 'insert-string "Hello, world!"'
```

The existing key bindings can be checked with the following command:
```console
$ ble-bind -d
```

The list of functions can be checked with the following command:
```console
$ ble-bind -L
```

## Tips

**Using multiline command line**

By typing `C-v RET` or `C-q RET`, you can insert a newline character in the command line string.
When the command line string contains a newline character, `RET` (`C-m`) causes insertion of a new newline character.
The command containing newline characters can be executed by typing `C-j`.

## Special thanks

- many thanks for testing the `ble.sh` vi mode: @cmplstofB
