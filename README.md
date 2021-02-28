[ Languages: **English** | [日本語](README-ja_JP.md) (Japanese) ]

<h1 align="center">ble.sh ―Bash Line Editor―</h1>
<p align="center">
[ <b>README</b> | <a href="https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A71-Introduction">Manual</a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Q&A">Q&A</a> |
<a href="https://github.com/akinomyoga/blesh-contrib"><code>contrib</code></a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Recipes">Recipes</a> ]
</p>

*Bash Line Editor* (`ble.sh`) is a command line editor written in pure Bash scripts which replaces the default GNU Readline.

Current devel version is 0.4.
This script supports Bash 3.0 or higher although we recommend to use `ble.sh` with Bash 4.0 or higher.
Currently, only `UTF-8` encoding is supported for non-ASCII characters.
This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

## Quick instructions

Installation requires the commands `git`, `make` (GNU make), and `gawk`.
For detailed descriptions, see [Sec 1.1](#get-from-source) and [Sec 1.2](#get-from-tarball) for trial/installation,
[Sec 1.3](#set-up-bashrc) for the setup of your `~/.bashrc`.

```bash
# Quick INSTALL to BASHRC (If this doesn't work, please follow Sec 1.3)

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc

# Quick TRIAL without installation

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh
source ble.sh/out/ble.sh

# UPDATE (in a ble.sh session)

ble-update

# PACKAGE (for package maintainers)

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

## Features

- **Syntax highlighting**: Highlight command lines input by users as in `fish` and `zsh-syntax-highlighting`.
  Unlike the simple highlighting in `zsh-syntax-highlighting`, `ble.sh` performs syntactic analysis to enable the correct highlighting of complex structures such as nested command substitutions, multiple here documents, etc.
- **Enhanced completion**:
  Support syntax-aware completion, completion with quotes and parameter expansions in prefix texts, ambiguous candidate generation, etc.
  Also **menu-complete** supports selection of candidates in menu (candidate list) by cursor keys, <kbd>TAB</kbd> and <kbd>S-TAB</kbd>.
  The feature **auto-complete** supports the automatic suggestion of completed texts as in `fish` and `zsh-autosuggestions` (with Bash 4.0+).
  The feature **menu-filter** integrates automatic filtering of candidates into menu completion (with Bash 4.0+).
  There are other functionalities such as **dabbrev** and **sabbrev** like `zsh-abbreviations`.
- **Vim editing mode**: Enhance `readline`'s vi editing mode available with `set -o vi`.
  Vim editing mode supports various vim modes such as char/line/block visual/select mode, replace mode, command mode, operator pending mode as well as insert mode and normal mode.
  Vim editing mode supports various operators, text objects, registers, keyboard macros, marks, etc.
  It also provides `vim-surround` as an option.

Note: ble.sh does not provide a specific settings for the prompt, aliases, functions, etc.
ble.sh provides a more fundamental infrastructure so that users can set up their own settings for prompts, aliases, etc.
Of course ble.sh can be used in combination with other Bash configurations such as `bash-it` and `oh-my-bash`.

> Demo (version 0.2)
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

# 1 Usage

## 1.1 Try `ble.sh` generated from source (version ble-0.4 devel)<sup><a id="get-from-source" href="#get-from-source">†</a></sup>

### Generate

To generate `ble.sh`, `gawk` (GNU awk) and `gmake` (GNU make) is required.
The file `ble.sh` can be generated using the following commands.
If you have GNU make installed on `gmake`, please use `gmake` instead of `make`.
```bash
git clone --recursive https://github.com/akinomyoga/ble.sh.git
cd ble.sh
make
```

A script file `ble.sh` will be generated in the directory `ble.sh/out`.

### Try

Then, you can load `ble.sh` in the Bash session using the `source` command:
```bash
source out/ble.sh
```

### Install

To install `ble.sh` in a specified directory, use `make install`.

```bash
# INSTALL to ~/.local/share/blesh
make install

# INSTALL to a specified directory
make install INSDIR=/path/to/blesh

# PACKAGE (for package maintainers)
make install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

If either the make variables `DESTDIR` or `PREFIX` is supplied, `ble.sh` will be copied to `$DESTDIR/$PREFIX/share/blesh`.
Otherwise, if the make variables `INSDIR` is specified, it will be installed directly on `$INSDIR`.
Otherwise, if the environment variable `$XDG_DATA_HOME` is defined, the install location will be `$XDG_DATA_HOME/blesh`.
If none of these variables are specified, the default install location is `~/.local/share/blesh`.

To set up `.bashrc` see [Sec. 1.3](#set-up-bashrc).

## 1.2 Or, try `ble.sh` downloaded from GitHub releases (version ble-0.3 201902)<sup><a id="get-from-tarball" href="#get-from-tarball">†</a></sup>

With `wget`:
```bash
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.3.3/ble-0.3.3.tar.xz
tar xJf ble-0.3.3.tar.xz
source ble-0.3.3/ble.sh
```
With `curl`:
```bash
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.3.3/ble-0.3.3.tar.xz
tar xJf ble-0.3.3.tar.xz
source ble-0.3.3/ble.sh
```

If you want to place `ble.sh` in a specific directory, just copy the directory:
```bash
cp -r ble-0.3.3 /path/to/blesh
```

## 1.3 Set up `.bashrc`<sup><a id="set-up-bashrc" href="#set-up-bashrc">†</a></sup>

If you want to load `ble.sh` by default in interactive sessions of `bash`, usually one can just source `ble.sh` in `~/.bashrc`,
but more reliable way is to add the following codes to your `.bashrc` file:
```bash
# bashrc

# Add this lines at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# your bashrc settings come here...

# Add this line at the end of .bashrc:
[[ ${BLE_VERSION-} ]] && ble-attach
```

## 1.4 User settings `~/.blerc`

User settings can be placed in the init script `~/.blerc` (or `${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh` if `~/.blerc` is not available)
whose template is available as the file [`blerc`](https://github.com/akinomyoga/ble.sh/blob/master/blerc) in the repository.
The init script is a Bash script which will be sourced during the load of `ble.sh`, so any shell commands can be used in `~/.blerc`.
If you want to change the default path of the init script, you can add the option `--rcfile INITFILE` to `source ble.sh` as the following example:

```bash
# in bashrc

# Example 1: ~/.blerc will be used by default
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# Example 2: /path/to/your/blerc will be used
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach --rcfile /path/to/your/blerc
```

## 1.5 Update

You need Git (`git`), GNU awk (`gawk`) and GNU make (`make`).
For `ble-0.3+`, run `ble-update` in the session with `ble.sh` loaded:

```bash
$ ble-update
```

You can instead download the latest version by `git pull` and install it:

```bash
cd ble.sh   # <-- enter the git repository you already have
git pull
git submodule update --recursive --remote
make
make INSDIR="$HOME/.local/share/blesh" install
```

## 1.6 Uninstall

Basically you can simply delete the installed directory and the settings that user added.

- Remove the added lines in `.bashrc`.
- Remove `blerc` files (`~/.blerc` or `~/.config/blesh/init.sh`) if any.
- Remove the installed directory.
- Remove the temporary directory `/tmp/blesh` if any [ Only needed when your system does not automatically clears `/tmp` ].

# 2 Basic settings

Here some of the settings for `~/.blerc` are picked up.
You can find useful settings also in [Q\&A](https://github.com/akinomyoga/ble.sh/wiki/Q&A),
[Recipes](https://github.com/akinomyoga/ble.sh/wiki/Recipes)
and [`contrib` repository](https://github.com/akinomyoga/blesh-contrib).
The complete list of setting items can be found in the template [`blerc`](https://github.com/akinomyoga/ble.sh/blob/master/blerc).
For detailed explanations please refer to [Manual](https://github.com/akinomyoga/ble.sh/wiki).

## 2.1 Vim mode

For the vi/vim mode, check [the Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## 2.2 Configure `auto-complete`

The feature `auto-complete` is available for Bash 4.0+ and enabled by default.
If you want to turn off `auto-complete`, please put the following line in your `~/.blerc`.

```bash
bleopt complete_auto_complete=
```

Instead of completely turning off `auto-complete`, you can set a delay for `auto-complete`.

```bash
# Set the delay of the auto-complete to 300 milliseconds
bleopt complete_auto_delay=300
```

`auto-complete` candidates based on the bash command history can be turned off by the following line.

```bash
bleopt complete_auto_history=
```

## 2.3 CJK Width

The option `char_width_mode` controls the width of the Unicode characters with `East_Asian_Width=A` (Ambiguous characters).
Currently four values `emacs`, `west`, `east`, and `auto` are supported. With the value `emacs`, the default width in emacs is used.
With `west` all the ambiguous characters have width 1 (Hankaku). With `east` all the ambiguous characters have width 2 (Zenkaku).
With `auto` the width mode `west` or `east` is automatically chosen based on the terminal behavior.
The default value is `auto`. Appropriate value should be chosen in accordance with your terminal behavior.
For example, the value can be changed to `west` as:

```bash
bleopt char_width_mode='west'
```

## 2.4 Input Encoding

The option `input_encoding` controls the encoding scheme used in the decode of input. Currently `UTF-8` and `C` are available. With the value `C`, byte values are directly interpreted as character codes. The default value is `UTF-8`. For example, the value can be changed to `C` as:

```bash
bleopt input_encoding='C'
```

## 2.5 Bell

The options `edit_abell` and `edit_vbell` control the behavior of the edit function `bell`. If `edit_abell` is a non-empty string, audible bell is enabled, i.e. ASCII Control Character `BEL` (0x07) will be written to `stderr`. If `edit_vbell` is a non-empty string, visual bell is enabled. By default, the audible bell is enabled while the visual bell is disabled.

The option `vbell_default_message` specifies the message shown as the visual bell. The default value is `' Wuff, -- Wuff!! '`. The option `vbell_duration` specifies the display duration of the visual-bell message. The unit is millisecond. The default value is `2000`.

For example, the visual bell can be enabled as:
```
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

For another instance, the audible bell is disabled as:
```
bleopt edit_abell=
```

## 2.6 Highlight Colors

The colors and attributes used in the syntax highlighting are controlled by `ble-color-setface` function. The following code reproduces the default configuration:
```bash
# highlighting related to editing
ble-color-setface region                    bg=60,fg=white
ble-color-setface region_target             bg=153,fg=black
ble-color-setface region_match              bg=55,fg=white
ble-color-setface region_insert             fg=12,bg=252
ble-color-setface disabled                  fg=242
ble-color-setface overwrite_mode            fg=black,bg=51
ble-color-setface auto_complete             fg=238,bg=254
ble-color-setface menu_filter_fixed         bold
ble-color-setface menu_filter_input         fg=16,bg=229
ble-color-setface vbell                     reverse
ble-color-setface vbell_erase               bg=252
ble-color-setface vbell_flash               fg=green,reverse
ble-color-setface prompt_status_line        fg=231,bg=240

# syntax highlighting
ble-color-setface syntax_default            none
ble-color-setface syntax_command            fg=brown
ble-color-setface syntax_quoted             fg=green
ble-color-setface syntax_quotation          fg=green,bold
ble-color-setface syntax_expr               fg=26
ble-color-setface syntax_error              bg=203,fg=231
ble-color-setface syntax_varname            fg=202
ble-color-setface syntax_delimiter          bold
ble-color-setface syntax_param_expansion    fg=purple
ble-color-setface syntax_history_expansion  bg=94,fg=231
ble-color-setface syntax_function_name      fg=92,bold
ble-color-setface syntax_comment            fg=242
ble-color-setface syntax_glob               fg=198,bold
ble-color-setface syntax_brace              fg=37,bold
ble-color-setface syntax_tilde              fg=navy,bold
ble-color-setface syntax_document           fg=94
ble-color-setface syntax_document_begin     fg=94,bold
ble-color-setface command_builtin_dot       fg=red,bold
ble-color-setface command_builtin           fg=red
ble-color-setface command_alias             fg=teal
ble-color-setface command_function          fg=92
ble-color-setface command_file              fg=green
ble-color-setface command_keyword           fg=blue
ble-color-setface command_jobs              fg=red
ble-color-setface command_directory         fg=26,underline
ble-color-setface filename_directory        underline,fg=26
ble-color-setface filename_directory_sticky underline,fg=white,bg=26
ble-color-setface filename_link             underline,fg=teal
ble-color-setface filename_orphan           underline,fg=teal,bg=224
ble-color-setface filename_executable       underline,fg=green
ble-color-setface filename_setuid           underline,fg=black,bg=220
ble-color-setface filename_setgid           underline,fg=black,bg=191
ble-color-setface filename_other            underline
ble-color-setface filename_socket           underline,fg=cyan,bg=black
ble-color-setface filename_pipe             underline,fg=lime,bg=black
ble-color-setface filename_character        underline,fg=white,bg=black
ble-color-setface filename_block            underline,fg=yellow,bg=black
ble-color-setface filename_warning          underline,fg=red
ble-color-setface filename_url              underline,fg=blue
ble-color-setface filename_ls_colors        underline
ble-color-setface varname_array             fg=orange,bold
ble-color-setface varname_empty             fg=31
ble-color-setface varname_export            fg=200,bold
ble-color-setface varname_expr              fg=92,bold
ble-color-setface varname_hash              fg=70,bold
ble-color-setface varname_number            fg=64
ble-color-setface varname_readonly          fg=200
ble-color-setface varname_transform         fg=29,bold
ble-color-setface varname_unset             fg=124
```

The current list of faces can be obtained by the following command (`ble-color-setface` without arguments):
```console
$ ble-color-setface
```

The color codes can be checked in output of the function `ble-color-show` (defined in `ble.sh`):
```console
$ ble-color-show
```

## 2.7 Key Bindings

Key bindings can be controlled with the shell function, `ble-bind`.
For example, with the following setting, "Hello, world!" will be inserted on typing <kbd>C-x h</kbd>
```bash
ble-bind -f 'C-x h' 'insert-string "Hello, world!"'
```

For another example, if you want to invoke a command on typing <kbd>M-c</kbd>, you can write as follows:

```bash
ble-bind -c 'M-c' 'my-command'
```

Or, if you want to invoke a edit function (designed for Bash `bind -x`) on typing <kbd>C-r</kbd>, you can write as follows:

```bash
ble-bind -x 'C-r' 'my-edit-function'
```

The existing key bindings are shown by the following command:
```console
$ ble-bind -P
```

The list of widgets is shown by the following command:
```console
$ ble-bind -L
```

# 3 Tips

## 3.1 Use multiline mode

When the command line string contains a newline character, `ble.sh` enters the MULTILINE mode.

By typing <kbd>C-v RET</kbd> or <kbd>C-q RET</kbd>, you can insert a newline character in the command line string.
In the MULTILINE mode, <kbd>RET</kbd> (<kbd>C-m</kbd>) causes insertion of a new newline character.
In the MULTILINE mode, the command can be executed by typing <kbd>C-j</kbd>.

When the shell option `shopt -s cmdhist` is set (which is the default),
<kbd>RET</kbd> (<kbd>C-m</kbd>) inserts a newline if the current command line string is syntactically incomplete.

## 3.2 Use vim editing mode

If `set -o vi` is specified in `.bashrc` or `set editing-mode vi` is specified in `.inputrc`, the vim mode is enabled.
For details, please check the [Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## 3.3 Use `auto-complete`

The feature `auto-complete` is available in Bash 4.0 or later. `auto-complete` automatically suggests a possible completion on user input.
The suggested contents can be inserted by typing <kbd>S-RET</kbd>
(when the cursor is at the end of the command line, you can also use <kbd>right</kbd>, <kbd>C-f</kbd> or <kbd>end</kbd> to insert the suggestion).
If you want to insert only first word of the suggested contents, you can use <kbd>M-right</kbd> or <kbd>M-f</kbd>.
If you want to accept the suggestion and immediately run the command, you can use <kbd>C-RET</kbd> (if your terminal supports this special key combination).

## 3.4 Use `sabbrev` (static abbrev expansions)

By registering words to `sabbrev`, the words can be expanded to predefined strings.
When the cursor is just after a registered word, typing <kbd>SP</kbd> causes `sabbrev` expansion.
For example, with the following settings, when you type <kbd>SP</kbd> after the command line `command L`, the command line will be expanded to `command | less`.

```bash
# blerc
ble-sabbrev L='| less'
```

# 4 Contributors

I received many feedbacks from many people in GitHub Issues/PRs.
I thank all such people for supporting the project.
Among them, the following people have made particularly significant contributions.

- [`@cmplstofB`](https://github.com/cmplstofB) helped me implementing vim-mode by testing it and giving me a lot of suggestions.
- [`@dylankb`](https://github.com/dylankb) reported many issues for fzf-integration, initialization, etc.
- [`@rux616`](https://github.com/rux616) reported several issues and created a PR for fixing the default path of `.blerc`
- [`@timjrd`](https://github.com/timjrd) suggested and contributed to performance improvements in completion.
- [`@3ximus`](https://github.com/3ximus) reported many issues for a wide variety of problems.
