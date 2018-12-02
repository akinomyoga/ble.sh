[Languages: **English** | [日本語](README-ja_JP.md)]
# ble.sh

*Bash Line Editor* (`ble.sh`) is a command line editor written in pure Bash scripts to replace the default GNU Readline.
- Syntax highlighting of command lines (as in `fish` shell or `zsh-syntax-highlighting`)
- Syntax-aware completion
  - `auto-complete` (similar to `fish` and `zsh-autosuggestions`)
  - `menu-complete`, `menu-filter` (similar to completions with `peco`/`fzf`/etc.)
  - `sabbrev` (similar to `zsh-abbreviations`), `dabbrev`, etc.
- Enhanced vim mode

This script supports Bash 3.0 or later although we recommend to use `ble.sh` with Bash 4.0 or later.

Currently, only `UTF-8` encoding is supported for non-ASCII characters.

This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

> Demo
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

## Usage
**Generate `ble.sh` from source** (version ble-0.3 devel)

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

**Or, download `ble.sh`** (version ble-0.2 release 201809)

With `wget`:
```console
$ wget https://github.com/akinomyoga/ble.sh/releases/download/v0.2.1/ble-0.2.1.tar.xz
$ tar xJf ble-0.2.1.tar.xz
$ source ble-0.2.1/ble.sh
```
With `curl`:
```console
$ curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.2.1/ble-0.2.1.tar.xz
$ tar xJf ble-0.2.1.tar.xz
$ source ble-0.2.1/ble.sh
```

If you want to place `ble.sh` in a specific directory, just copy the directory:
```console
$ cp -r ble-0.2.1 /path/to/blesh
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

**Vim mode**

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

The colors and attributes used in the syntax highlighting are controlled by `ble-color-setface` function. The following code reproduces the default configuration:
```bash
ble-color-setface region                   bg=60,fg=white
ble-color-setface region_target            bg=153,fg=black
ble-color-setface disabled                 fg=242
ble-color-setface overwrite_mode           fg=black,bg=51
ble-color-setface syntax_default           none
ble-color-setface syntax_command           fg=brown
ble-color-setface syntax_quoted            fg=green
ble-color-setface syntax_quotation         fg=green,bold
ble-color-setface syntax_expr              fg=26
ble-color-setface syntax_error             bg=203,fg=231
ble-color-setface syntax_varname           fg=202
ble-color-setface syntax_delimiter         bold
ble-color-setface syntax_param_expansion   fg=purple
ble-color-setface syntax_history_expansion bg=94,fg=231
ble-color-setface syntax_function_name     fg=92,bold
ble-color-setface syntax_comment           fg=242
ble-color-setface syntax_glob              fg=198,bold
ble-color-setface syntax_brace             fg=37,bold
ble-color-setface syntax_tilde             fg=navy,bold
ble-color-setface syntax_document          fg=94
ble-color-setface syntax_document_begin    fg=94,bold
ble-color-setface command_builtin_dot      fg=red,bold
ble-color-setface command_builtin          fg=red
ble-color-setface command_alias            fg=teal
ble-color-setface command_function         fg=92
ble-color-setface command_file             fg=green
ble-color-setface command_keyword          fg=blue
ble-color-setface command_jobs             fg=red
ble-color-setface command_directory        fg=26,underline
ble-color-setface filename_directory       fg=26,underline
ble-color-setface filename_link            fg=teal,underline
ble-color-setface filename_executable      fg=green,underline
ble-color-setface filename_other           underline
ble-color-setface filename_socket          fg=cyan,bg=black,underline
ble-color-setface filename_pipe            fg=lime,bg=black,underline
ble-color-setface filename_character       fg=white,bg=black,underline
ble-color-setface filename_block           fg=yellow,bg=black,underline
ble-color-setface filename_warning         fg=red,underline
```

The color codes can be checked in output of the function `ble-color-show` (defined in `ble.sh`):
```console
$ ble-color-show
```

**Key Bindings**

Key bindings can be controlled with the shell function, `ble-bind`.
For example, with the following setting, "Hello, world!" will be inserted on typing <kbd>C-x h</kbd>
```bash
ble-bind -f 'C-x h' 'insert-string "Hello, world!"'
```

The existing key bindings are shown by the following command:
```console
$ ble-bind -P
```

The list of widgets is shown by the following command:
```console
$ ble-bind -L
```

## Tips

**Use multiline mode**

When the command line string contains a newline character, `ble.sh` enters the MULTILINE mode.

By typing <kbd>C-v RET</kbd> or <kbd>C-q RET</kbd>, you can insert a newline character in the command line string.
In the MULTILINE mode, <kbd>RET</kbd> (<kbd>C-m</kbd>) causes insertion of a new newline character.
In the MULTILINE mode, the command can be executed by typing <kbd>C-j</kbd>.

When the shell option `shopt -s cmdhist` is set (which is the default),
<kbd>RET</kbd> (<kbd>C-m</kbd>) inserts a newline if the current command line string is syntactically incomplete.

**Use vim-mode**

If `set -o vi` is specified in `.bashrc` or `set editing-mode vi` is specified in `.inputrc`, the vim mode is enabled.
For details, please check the [Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

**Use `auto-complete`**

The feature `auto-complete` is available in Bash 4.0 or later. `auto-complete` automatically suggests a possible completion on user input.
The suggested contents can be inserted by typing <kbd>S-RET</kbd>
(when the cursor is at the end of the command line, you can also use <kbd>right</kbd> or <kbd>C-f</kbd> to insert the suggestion).
If you want to insert only first word of the suggested contents, you can use <kbd>M-right</kbd> or <kbd>M-f</kbd>.
If you want to accept the suggestion and immediately run the command, you can use <kbd>C-RET</kbd> (if your terminal supports this special key combination).

**Use `sabbrev` (static abbrev expansions)**

By registering words to `sabbrev`, the words can be expanded to predefined strings.
When the cursor is just after a registered word, typing <kbd>SP</kbd> causes `sabbrev` expansion.
For example, with the following settings, when you type <kbd>SP</kbd> after the command line `command L`, the command line will be expanded to `command | less`.

```bash
# bashrc (after source ble.sh)
ble-sabbrev L='| less'
```

## Special thanks

- @cmplstofB for testing vim-mode and giving me a lot of suggestions
