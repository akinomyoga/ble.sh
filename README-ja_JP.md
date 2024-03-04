[ Languages: [English](README.md) (英語) | **日本語** ]

<h1 align="center"><ruby>ble.sh<rp> (</rp><rt>/blɛʃ/</rt><rp>)</rp></ruby> ―Bash Line Editor―</h1>
<p align="center">
[ <b>README</b> | <a href="https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A71-%E5%9F%BA%E6%9C%AC">説明書</a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/%E8%B3%AA%E5%95%8F%E3%81%A8%E5%9B%9E%E7%AD%94">Q&A</a> |
<a href="https://github.com/akinomyoga/blesh-contrib"><code>contrib</code></a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/%E9%80%86%E5%BC%95%E3%81%8D%E3%83%AC%E3%82%B7%E3%83%94">逆引き</a> ]
</p>

`ble.sh` (*Bash Line Editor*) はピュア Bash スクリプトで書かれたコマンドラインエディタで、標準の GNU Readline を置き換える形で動作します。

現在の開発バージョンは 0.4 です。
このスクリプトは Bash 3.0 以降で利用できますが、速度・機能などの観点から 4.0 以降のリリース版 Bash でお使い頂くことがお薦めです。
現時点では、文字コードとして `UTF-8` のみの対応です。
このスクリプトは [**BSD License**](LICENSE.md) (3条項 BSD ライセンス) の下で提供されます。

免責: ラインエディタ本体は **ピュア Bash** で書かれていますが、
ユーザーコマンド実行時には TTY 設定の為に `stty` (POSIX) を呼び出します。
他にも処理の高速化の為に、初期化・終了処理、
巨大なデータの処理 (補完、貼り付けなど) の局面でPOSIX 標準コマンドを利用しています。

呼称: `ble.sh` はお好きな様に読んでいただいて問題ありませんが、一番短いのは標記の /blɛʃ/ になりましょう。
しかし個人的には脳裡で /biːɛliː/ または /biːɛliː dɑt ɛseɪtʃ/ と読んでいるものですから、標記の読み方は飽くまで参考と受け止めていただければ幸いです。

## 簡単設定

`ble.sh` をお使いいただくには Bash 3.0 以上 (及び POSIX の基本的なコマンド) が必要です。
<!-- 但し、macOS では附属の `/usr/bin/awk` (awk-32 以降) でマルチバイト文字セットの問題があるため、`gawk`, `nawk`, または `mawk` を別途インストールする必要があるかもしれません。 -->
`ble.sh` を取得するには主に2つの方法があります: `git` を用いてソースを取得しビルドする方法と `curl` または `wget` を用いて nightly ビルドをダウンロードする方法です。
詳細は、試用またはインストールに関しては [節1.1](#get-from-source) と [節1.2](#get-from-tarball) を、
`~/.bashrc` の設定に関しては [節1.3](#set-up-bashrc) を御覧ください。

> [!NOTE]
> `fzf` を `ble.sh` と組み合わせてお使いの場合は [節2.8](#set-up-bashrc) を必ず
> 御覧ください。

<details open><summary><b><code>git</code> を用いてソースを取得し <code>ble.sh</code> を生成</b></summary>

この方法では `git`, `make` (GNU make), 及び `gawk` が必要です。
以下、GNU make が `gmake` として提供されているシステム (BSD など) では、`make` を `gmake` に置き換えて実行してください。

```bash
# 簡単お試し (インストールせずにお試しいただけます)

git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
make -C ble.sh
source ble.sh/out/ble.sh

# インストール & .bashrc 簡単設定 (動かない場合は節1.3を御参照下さい)

git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

生成過程では、複数のBashスクリプトファイルを前処理・結合することで `ble.sh` を生成し、
他の関連ファイルを正しく配置し、またソースコード中のコードコメントを削除してロードを最適化します。

※生成過程は、C/C++ のコンパイルも伴わずバイナリも生成しませんので、コンパイラを準備していただく必要はありません。
</details>

<details><summary><b><code>curl</code> を用いて nightly ビルドをダウンロード</b></summary>

この方法では `curl`, `tar` (オプション `J` に対応), 及び `xz` (XZ Utils) が必要です。

```bash
# 簡単お試し (インストールせずにお試しいただけます)

curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
source ble-nightly/ble.sh

# インストール & .bashrc 簡単設定 (動かない場合は節1.3を御参照下さい)

curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install ~/.local/share
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

インストール後はディレクトリ `ble-nightly` は削除して問題ありません。
</details>

<details><summary><b><code>wget</code> を用いて nightly ビルドをダウンロード</b></summary>

この方法では `wget`, `tar` (オプション `J` に対応), 及び `xz` (XZ Utils) が必要です。

```bash
# 簡単お試し (インストールせずにお試しいただけます)

wget -O - https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
source ble-nightly/ble.sh

# インストール & .bashrc 簡単設定 (動かない場合は節1.3を御参照下さい)

wget -O - https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install ~/.local/share
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

インストール後はディレクトリ `ble-nightly` は削除して問題ありません。
</details>

<details open><summary><b>パッケージ管理システムを通じてパッケージをインストール</b> (現在限られたパッケージのみ)</summary>

この方法では対応するパッケージ管理ツールのみが必要です。

- [AUR (Arch Linux)](https://github.com/akinomyoga/ble.sh/wiki/Manual-A1-Installation#user-content-AUR) `blesh-git` (devel), `blesh` (stable 0.3.4)
- [NixOS (nixpkgs)](https://github.com/akinomyoga/ble.sh/wiki/Manual-A1-Installation#user-content-nixpkgs) `blesh` (devel)
- [Guix](https://packages.guix.gnu.org/packages/blesh/0.4.0-devel2/) `blesh` (0.4.0-devel2)
</details>

<details open><summary><b>既存の <code>ble.sh</code> を更新</b></summary>

```bash
# 更新 (ble.sh をロードした状態で)

ble-update

# 更新 (ble.sh 外部から)

bash /path/to/ble.sh --update
```
</details>

<details><summary><b><code>ble.sh</code> のパッケージ作成</b></summary>

`ble.sh` は単にシェルスクリプトの集合ですので環境に依存せずにお使いいただけます (いわゆる "`noarch`") ので、
単にリリースページからビルド済みの tar ボールをダウンロードし中身を `/tmp/blesh-package/usr/local` など所定の位置に配置するだけで問題ありません。
それでも何らかの理由により自前でビルドする必要がある場合には以下のコマンドをお使いください。
ビルドの為には git リポジトリ (`.git`) が必要になることにご注意ください。

```bash
# ビルド & パッケージ作成用コマンド

git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

パッケージ管理システムを用いたパッケージ更新方法を指定すると `ble-update` でそれが呼び出されます。
更新方法を指定するにはスクリプトファイルを `${prefix}/share/blesh/lib/_package.bash` に配置します。
スクリプトは次の様な変数と関数を定義します。但し `XXX` はパッケージ管理システムの名前に置き換えてください。

```bash
# ${prefix}/share/blesh/lib/_package.bash

_ble_base_package_type=XXX

function ble/base/package:XXX/update {
  update-the-package-in-a-proper-way
  return 0
}
```

シェル関数がステータス 0 で終了した場合、更新が成功した事を表し `ble.sh` のリロードが自動的に行われます。
シェル関数がステータス 6 で終了した場合、`ble.sh` のタイムスタンプが確認され、`ble.sh` が現セッションの開始時刻よりも新しい時に限りリロードが行われます。
シェル関数がステータス 125 で終了した場合、`ble.sh` に組み込みの更新処理が試みられます。
それ以外の場合には更新処理が中断されます。この場合、シェル関数が状況を説明するメッセージを出力するようにして下さい。
具体例として `AUR` パッケージの [`_package.bash`](https://aur.archlinux.org/cgit/aur.git/tree/blesh-update.sh?h=blesh-git) も参考にしていただければ幸いです。
</details>

## 機能概要

- **構文着色**: `fish` や `zsh-syntax-highlighting` のような文法構造に従った着色を行います。
  `zsh-syntax-highlighting` のような単純な着色ではなく、構文の入れ子構造や複数のヒアドキュメントなども正しく解析して着色します。
  着色は[全て設定可能](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A72-%E6%8F%8F%E7%94%BB)です。
- **補完増強**: [補完](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C)を大幅に増強します。
  **文法構造に応じた補完**、クォートやパラメータ展開を展開した上でのプログラム補完、**曖昧補完**に対応しています。
  また、候補をカーソルキーや <kbd>TAB</kbd>, <kbd>S-TAB</kbd> で選択できる
  [**メニュー補完**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C#user-content-sec-menu-complete)、
  `fish` や `zsh-autosuggestions` のような
  [**自動補完**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C#user-content-sec-auto-complete)
  (Bash 4.0 以上) の機能もあります。
  更に、従来 `peco` や `fzf` を呼び出さなければならなかった補完候補の絞り込みも
  [**メニュー絞り込み**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C#user-content-sec-menu-filter)
  (Bash 4.0 以上) として自然な形で組み込んでいます。
  他に、[**動的略語展開**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C#user-content-sec-dabbrev)
  や、[*zsh abbreviations*](https://unix.stackexchange.com/questions/6152/zsh-alias-expansion)・[`zsh-abbr`](https://github.com/olets/zsh-abbr) のような
  [**静的略語展開**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A77-%E8%A3%9C%E5%AE%8C#user-content-sec-sabbrev)
  にも対応しています。
- **Vim編集モード**: `set -o vi` による編集モードを増強します。
  挿入・ノーマルモードの他に(行・矩形)ビジュアルモード、置換モードなどの各種モードに対応しています。
  テキストオブジェクト・各種レジスタ・オペレータ・キーボードマクロなどにも対応しています。
  拡張として `vim-surround` も提供しています。
- 他にも
  [**ステータス行**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A74-%E7%B7%A8%E9%9B%86#user-content-bleopt-prompt_status_line),
  [**コマンド履歴共有**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A74-%E7%B7%A8%E9%9B%86#user-content-bleopt-history_share),
  [**右プロンプト**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A74-%E7%B7%A8%E9%9B%86#user-content-bleopt-prompt_rps1),
  [**過渡的プロンプト**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A74-%E7%B7%A8%E9%9B%86#user-content-bleopt-prompt_ps1_transient),
  [**xterm タイトル**](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A74-%E7%B7%A8%E9%9B%86#user-content-bleopt-prompt_xterm_title),
  など様々な機能に対応しています。

注意: `ble.sh` は、(プロンプト (`PS1`)、エイリアス、関数などを提供する) 典型的な Bash 設定集と異なります。
`ble.sh` はより低層の基盤を提供するもので、ユーザは自分でプロンプトやエイリアスを設定する必要があります。
勿論 [`bash-it`](https://github.com/Bash-it/bash-it) や [`oh-my-bash`](https://github.com/ohmybash/oh-my-bash) の様な他の Bash 設定と一緒に使っていただくことも可能です。

> デモ
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

## 来し方行く末

このプロジェクトは初めは `.bashrc` の片隅で行われた小さな実験からスタートしました。
2013年5月に `zsh-syntax-highlighting` のとある記事に触発されたのがきっかけでした。
初めは数百行のコードを書けば構文着色が簡単に実現できるのではないかと思って始めた実験ですが、
すぐに行エディタを根本から書き直さなければ実現できないのではないかということが分かり、
独立したファイルにコードを移動した後に `ble.sh` という名前を与えました。
この名前は Zsh の行エディタ (*ZLE* (*Zsh Line Editor*)) を真似て、
但しシェルで書かれているという事を意識して `.sh` という拡張子にしたように記憶しています。
`ble.sh` の読み方について屡々訊かれるのですが、最初に書いたように特に定まった読み方はありません。
最初の実験は2週間程コードを弄って原理的に行エディタを作れるという事を結論づけて終わりました。
本格的な実装が始まったのは2015年2月の事で12月には公開しました。
その時点で行エディタとしては普段遣いに堪える程度に完成していました。
Vimモードの実装は2017年9月に始まり2018年3月に一先ず完成としました。
続いて補完の拡張は2018年8月に始まり2019年2月には一通り完成しました。
現在は漫然とメンテナンスしている所でいつになるかは分かりませんが、以下に挙げるような機能も加えたいと何となく考えています。

- 2013-06 v0.0 -- 実験
- 2015-12 v0.1 -- 構文着色 [[v0.1.15](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.15)]
- 2018-03 v0.2 -- Vim モード [[v0.2.7](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.7)]
- 2019-02 v0.3 -- 拡張補完 [[v0.3.4](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.4)]
- 20xx-xx v0.4 (plan) -- プログラム着色 [[nightly build](https://github.com/akinomyoga/ble.sh/releases/tag/nightly)]
- 20xx-xx v0.5 (plan) -- TUI設定画面
- 20xx-xx v0.6 (plan) -- エラー診断?

## 制限

`ble.sh` の実装形態から来る制限があります。
ユーザー設定や他の Bash の枠組みとの干渉によって問題が起こる可能性があります。

- `ble.sh` は、実行コストの都合、既定では前回のコマンドライン実行後の `PIPESTATUS` を設定しません。代わりに `BLE_PIPESTATUS` を参照することができます。
  もし本当に `PIPESTATUS` 経由でこれらの値を利用する必要がある場合には設定 `bleopt exec_restore_pipestatus=1` を使用して下さい。
- `ble.sh` は一般的な変数名のシェル変数や環境変数 (`LC_*` など) がグローバルで読み込み専用変数になっていないことを想定します。
  Bash ではグローバル変数の読み込み専用属性は関数のローカルスコープに於いても制限を与えます。
  つまり、同名の異なるローカル変数さえ定義することができません。
  この問題は `ble.sh` 固有の制限ではなく、あらゆる Bash の枠組みがグローバルの読み込み専用変数に影響を受けます。
  一般的にグローバルスコープに読み込み変数を設定することはセキュリティ的な理由がない限りは非推奨と考えられています (参照 [[1]](https://lists.gnu.org/archive/html/bug-bash/2019-03/threads.html#00150), [[2]](https://lists.gnu.org/archive/html/bug-bash/2020-04/threads.html#00200), [[3]](https://mywiki.wooledge.org/BashProgramming?highlight=%28%22readonly%22%20flag,%20or%20an%20%22integer%22%20flag,%20but%20these%20are%20mostly%20useless,%20and%20serious%20scripts%20shouldn%27t%20be%20using%20them%29#Variables))。
  また、`ble.sh` はビルトインコマンド `readonly` をシェル関数で置き換え、グローバル変数を読み込み専用にするのをブロックします。
  例外として、全て大文字の変数 (`ble.sh` が内部使用するものを除く) および `_*` の形の変数 (`_ble_*` および `__ble_*` を除く) を読み込み専用にすることは可能です。
- `ble.sh` は Bash のビルトインコマンド (`trap`, `readonly`, `bind`, `history`, `read`, `exit`) をシェル関数で上書きし、`ble.sh` と干渉しないようにその振る舞いを調整します。
  ユーザーまたは他の枠組みが元のビルトインを直接呼び出した場合、または `ble.sh` の定義したシェル関数を別のシェル関数で上書きした場合、正しい動作を保証できません。
- シェル及び端末の設定はラインエディタ用とコマンド実行用で異なります。`ble.sh`
  はラインエディタ向けに必要な調整を行い、ユーザが指定したコマンド実行用の設定
  をできるだけ復元します。但し、様々な理由により、一部の設定については意図的に
  復元しない場合や復元することができない場合があります。詳細については
  [wiki](https://github.com/akinomyoga/ble.sh/wiki/Internals#internal-and-external)
  (英語) に情報があります。

# 1 使い方

## 1.1 最新の git repository のソースから生成して試す (バージョン ble-0.4)<sup><a id="get-from-source" href="#get-from-source">†</a></sup>

### ble.sh 生成

`ble.sh` を生成する為には `gawk` (GNU awk) と `gmake` (GNU make) が必要です。
以下のコマンドで生成できます。
GNU make が `gmake` という名前でインストールされている場合は、`make` の代わりに `gmake` として下さい。
```console
$ git clone --recursive https://github.com/akinomyoga/ble.sh.git
$ cd ble.sh
$ make
```
スクリプトファイル `ble.sh` がサブディレクトリ `ble.sh/out` 内に生成されます。

### 試用

生成された `ble.sh` は `source` コマンドを用いてお試しいただけます。

```console
$ source out/ble.sh
```

### インストール

指定したディレクトリにインストールするには `make install` コマンドを使用します。

```bash
# ~/.local/share/blesh にインストール
make install

# 指定したディレクトリにインストール
make install INSDIR=/path/to/blesh

# パッケージ作成用 (パッケージ管理者用)
make install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

Make 変数 `DESTDIR` または `PREFIX` が指定されている時、`ble.sh` は `$DESTDIR/$PREFIX/share/blesh` にコピーされます。
それ以外で Make 変数 `INSDIR` が指定されている時、直接 `$INSDIR` にインストールされます。
更にそれ以外で環境変数 `$XDG_DATA_HOME` が指定されている時、`$XDG_DATA_HOME/blesh` にインストールされます。
以上の変数が何れも指定されていない時の既定のインストール先は `~/.local/share/blesh` です。

インストール時にコード中のコメントは自動で削除されますが、コメントを保持したい場合は `strip_comment=no` を `make` の引数に指定して下さい。

`.bashrc` の設定に関しては[節1.3](#set-up-bashrc)を御覧ください。

## 1.2 GitHub Releases から tar をダウンロードして使う<sup><a id="get-from-tarball" href="#get-from-tarball">†</a></sup>

ダウンロード・試用・インストールの方法については各リリースページの説明を御覧ください。
現在、安定版は開発版に比べてかなり古いので様々な機能が欠けている事にご注意下さい。

- 開発版 [v0.4.0-devel3](https://github.com/akinomyoga/ble.sh/releases/tag/v0.4.0-devel3) (2020-12), [nightly build](https://github.com/akinomyoga/ble.sh/releases/tag/nightly)
- 安定版 [v0.3.4](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.4) (2019-02 fork) 拡張補完
- 安定版 [v0.2.7](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.7) (2018-03 fork) Vim モード
- 安定版 [v0.1.15](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.15) (2015-12 fork) 構文着色

## 1.3 `.bashrc` に設定する<sup><a id="set-up-bashrc" href="#set-up-bashrc">†</a></sup>

対話シェルで常用する場合には `.bashrc` に設定を行います。
単に `ble.sh` を `source` して頂くだけでも大抵の場合動作しますが、
より確実に動作させる為には以下の様にコードを記述します。
```bash
# bashrc

# .bashrc の先頭近くに以下を追加して下さい。
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# 間に通常の bashrc の内容を既述します。

# .bashrc の末端近くに以下を追加して下さい。
[[ ${BLE_VERSION-} ]] && ble-attach
```

`source /path/to/ble.sh` 及び `ble-attach` を呼び出す時は、
標準ストリーム (`stdin`, `stdout`, `stderr`) が現在のセッションの制御端末とは別の物にリダイレクトされていない様にして下さい。
`source /path/to/ble.sh` をシェル関数の中から実行するのは避けて下さい。
この「より確実な設定」が必要になる詳細な条件については [Discussion #254 への回答 (英語)](https://github.com/akinomyoga/ble.sh/discussions/254#discussioncomment-4284757) で説明されています。

## 1.4 初期化スクリプト `~/.blerc` について

ユーザー設定は初期化スクリプト `~/.blerc` (またはもし `~/.blerc` が見つからなければ `${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh`) に記述します。
テンプレートとしてリポジトリの [`blerc.template`](https://github.com/akinomyoga/ble.sh/blob/master/blerc.template) というファイルを利用できます。
初期化スクリプトは `ble.sh` ロード時に自動で読み込まれる Bash スクリプトなので、Bash で使えるコマンドを初期化スクリプトの中で利用できます。
初期化スクリプトの位置を変更する場合には、`source ble.sh` 時に `--rcfile INITFILE` を指定します。以下に例を挙げます。

```bash
# in bashrc

# Example 1: ~/.blerc will be used by default
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# Example 2: /path/to/your/blerc will be used
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach --rcfile /path/to/your/blerc
```

## 1.5 アップデート

Git (`git'), GNU awk (`gawk`), 及び GNU make (`make`) が必要になります。
`ble-0.3` 以上をお使いの場合は `ble.sh` をロードした状態で `ble-update` を実行して下さい。

```bash
$ ble-update
```

`ble-0.4` 以上をお使いの場合は `ble.sh` をロードしなくても以下のコマンドで更新可能です。

```bash
$ bash /path/to/ble.sh --update
```

それ以外の場合には、以下のように `git pull` で最新版を入手・インストールできます。

```bash
cd ble.sh   # ※既に持っている git リポジトリに入る
git pull
git submodule update --recursive --remote
make
make INSDIR="$HOME/.local/share/blesh" install
```

## 1.6 アンインストール

基本的に `ble.sh` ディレクトリとユーザの追加した設定を単に削除していただければ問題ありません。

- 全ての `ble.sh` セッション (`ble.sh` をロードしている Bash 対話セッション) を終了します。
- 関連するユーザーデータを削除します。これらのデータを保持しておきたい場合は必要に応じてスキップしてください。
  - `.bashrc` に追加した行があれば削除します。
  - `blerc` 設定ファイル (`~/.blerc` または `~/.config/blesh/init.sh`) があれば削除します。
  - 状態ディレクトリ `~/.cache/blesh` が生成されていればそれを削除します。
- `ble.sh` をインストールしたディレクトリを削除します。git リポジトリ内の
  `out/ble.sh` を直接ご使用の場合はインストールしたディレクトリは、git リポジト
  リ自体です。`make intall` を用いてインストールした場合は、インストールしたディ
  レクトリは `<PREFIX>/share/blesh` です。但し、`<PREFIX>` (既定値: `~/.local`)
  は `make install` に指定した `PREFIX` の値です。生成済み tarball をご利用の際
  には、インストールしたディレクトリは tarball を展開して得られたディレクトリを
  配置した場所です。
- キャッシュディレクトリ `~/.cache/blesh` が生成されていればそれを削除します。
- 一時ディレクトリ `/tmp/blesh` が生成されていればそれを削除します。これは `/tmp` の内容が自動的にクリアされないシステムで必要です。

# 2 基本設定

ここでは `~/.blerc` に記述する基本的な設定を幾つか紹介します。
[質問と回答](https://github.com/akinomyoga/ble.sh/wiki/%E8%B3%AA%E5%95%8F%E3%81%A8%E5%9B%9E%E7%AD%94)、
[逆引きレシピ](https://github.com/akinomyoga/ble.sh/wiki/%E9%80%86%E5%BC%95%E3%81%8D%E3%83%AC%E3%82%B7%E3%83%94)、
[`contrib` リポジトリ](https://github.com/akinomyoga/blesh-contrib/blob/master/README-ja.md) にも便利な設定があります。
その他の全ての設定項目はテンプレート [`blerc.template`](https://github.com/akinomyoga/ble.sh/blob/master/blerc.template) に含まれています。
詳細な説明に関しては[説明書](https://github.com/akinomyoga/ble.sh/wiki/%E7%9B%AE%E6%AC%A1)を参照して下さい。

## 2.1 Vim モード

Vim モードについては [Wiki の説明ページ](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode) を御覧ください。

## 2.2 各機能の無効化

よくお尋ね頂くご質問の一つにそれぞれの機能をどのように無効化すれば良いのかというものが御座います。
各機能の無効化方法を以下にまとめます。

```bash
# 構文着色を無効化
bleopt highlight_syntax=

# ファイル名に基づく構文着色を無効化
bleopt highlight_filename=

# 変数の種類に基づく構文着色の無効化
bleopt highlight_variable=

# 自動補完の無効化 (自動補完は Bash 4.0 以降にて既定で有効です)
bleopt complete_auto_complete=
# Tip: 代わりに自動補完の起動遅延をミリ秒単位でご指定いただくこともできます。
bleopt complete_auto_delay=300

# コマンド履歴に基づく自動補完の無効化
bleopt complete_auto_history=

# 曖昧補完の無効化
bleopt complete_ambiguous=

# TAB によるメニュー補完の無効化
bleopt complete_menu_complete=

# メニュー自動絞り込みの無効化 (Bash 4.0 以降にて既定で有効化されます)
bleopt complete_menu_filter=

# 行末マーカー "[ble: EOF]" の無効化
bleopt prompt_eol_mark=''
# Tip: 代わりに他の文字列をご指定頂くこともできます。
bleopt prompt_eol_mark='⏎'

# 終了ステータスマーカー "[ble: exit %d]" の無効化
bleopt exec_errexit_mark=
# Tip: 代わりに他の文字列をご指定頂くこともできます。
bleopt exec_errexit_mark=$'\e[91m[error %d]\e[m'

# コマンド実行時間マーカー "[ble: elapsed 1.203s (CPU 0.4%)]" の無効化
bleopt exec_elapsed_mark=
# Tip: 代わりに別の文字列をご指定いただくこともできます。
bleopt exec_elapsed_mark=$'\e[94m[%ss (%s %%)]\e[m'
# Tip: マーカーを表示する条件を変更することも可能です。
bleopt exec_elapsed_enabled='sys+usr>=10*60*1000' # 例: 合計CPU時間が 10 分以上の時に表示

# 終了マーカー "[ble: exit]" の無効化
bleopt exec_exit_mark=

# その他のマーカー "[ble: ...]" の無効化
bleopt edit_marker=
bleopt edit_marker_error=
```

## 2.3 曖昧文字幅

設定 `char_width_mode` を用いて、曖昧文字幅を持つ文字 (Unicode 参考特性 `East_Asian_Width` が `A` (Ambiguous) の文字) の幅を制御できます。
現在は 4 つの選択肢 `emacs`, `west`, `east`, `auto` が用意されています。
設定値 `emacs` を指定した場合、GNU Emacs における既定の文字幅と同じ物を使います。
設定値 `west` を指定した場合、全ての曖昧文字幅を 1 (半角) と解釈します。
設定値 `east` を指定した場合、全ての曖昧文字幅を 2 (全角) と解釈します。
設定値 `auto` を指定した場合、`west` か `east` かを端末とのやり取りに基づいて自動判定します。
既定値は `auto` です。この設定項目は、利用している端末の振る舞いに応じて適切に設定する必要があります。
例えば `west` に設定する場合は以下の様にします:

```bash
bleopt char_width_mode='west'
```

## 2.4 文字コード

設定 `input_encoding` は入力の文字コードを制御するのに使います。現在 `UTF-8` と `C` のみに対応しています。
設定値 `C` を指定した場合は、受信したバイト値が直接文字コードであると解釈されます。
既定値は `UTF-8` です。`C` に設定を変更する場合には以下の様にします:

```bash
bleopt input_encoding='C'
```

## 2.5 ベル

設定 `edit_abell` と設定 `edit_vbell` は、編集関数 `bell` の振る舞いを制御します。
`edit_abell` が非空白の文字列の場合、音による通知が有効になります (つまり、制御文字の `BEL` (0x07) が `stderr` に出力されます)。
`edit_vbell` が非空白の文字列の場合、画面での通知が有効になります。既定では音による通知が有効で、画面での通知が無効になっています。

設定 `vbell_default_message` は画面での通知で使用するメッセージ文字列を指定します。既定値は `' Wuff, -- Wuff!! '` です。
設定 `vbell_duration` は画面での通知を表示する時間の長さを指定します。単位はミリ秒です。既定値は `2000` です。

例えば、画面での通知は以下のように設定・有効化できます:
```bash
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

もう一つの例として、音による通知は以下の様にして無効化できます。
```bash
bleopt edit_abell=
```

## 2.6 着色の設定

構文に従った着色で使用される、各文法要素の色と属性は `ble-face` シェル関数で設定します。
既定の設定は以下のコードに対応します:
```bash
# 編集に関連する着色の設定
ble-face -s region                    bg=60,fg=white
ble-face -s region_target             bg=153,fg=black
ble-face -s region_match              bg=55,fg=white
ble-face -s region_insert             fg=12,bg=252
ble-face -s disabled                  fg=242
ble-face -s overwrite_mode            fg=black,bg=51
ble-face -s auto_complete             fg=238,bg=254
ble-face -s menu_filter_fixed         bold
ble-face -s menu_filter_input         fg=16,bg=229
ble-face -s vbell                     reverse
ble-face -s vbell_erase               bg=252
ble-face -s vbell_flash               fg=green,reverse
ble-face -s prompt_status_line        fg=231,bg=240

# 構文着色の設定
ble-face -s syntax_default            none
ble-face -s syntax_command            fg=brown
ble-face -s syntax_quoted             fg=green
ble-face -s syntax_quotation          fg=green,bold
ble-face -s syntax_escape             fg=magenta
ble-face -s syntax_expr               fg=26
ble-face -s syntax_error              bg=203,fg=231
ble-face -s syntax_varname            fg=202
ble-face -s syntax_delimiter          bold
ble-face -s syntax_param_expansion    fg=purple
ble-face -s syntax_history_expansion  bg=94,fg=231
ble-face -s syntax_function_name      fg=92,bold
ble-face -s syntax_comment            fg=242
ble-face -s syntax_glob               fg=198,bold
ble-face -s syntax_brace              fg=37,bold
ble-face -s syntax_tilde              fg=navy,bold
ble-face -s syntax_document           fg=94
ble-face -s syntax_document_begin     fg=94,bold
ble-face -s command_builtin_dot       fg=red,bold
ble-face -s command_builtin           fg=red
ble-face -s command_alias             fg=teal
ble-face -s command_function          fg=92
ble-face -s command_file              fg=green
ble-face -s command_keyword           fg=blue
ble-face -s command_jobs              fg=red
ble-face -s command_directory         fg=26,underline
ble-face -s filename_directory        underline,fg=26
ble-face -s filename_directory_sticky underline,fg=white,bg=26
ble-face -s filename_link             underline,fg=teal
ble-face -s filename_orphan           underline,fg=teal,bg=224
ble-face -s filename_executable       underline,fg=green
ble-face -s filename_setuid           underline,fg=black,bg=220
ble-face -s filename_setgid           underline,fg=black,bg=191
ble-face -s filename_other            underline
ble-face -s filename_socket           underline,fg=cyan,bg=black
ble-face -s filename_pipe             underline,fg=lime,bg=black
ble-face -s filename_character        underline,fg=white,bg=black
ble-face -s filename_block            underline,fg=yellow,bg=black
ble-face -s filename_warning          underline,fg=red
ble-face -s filename_url              underline,fg=blue
ble-face -s filename_ls_colors        underline
ble-face -s varname_array             fg=orange,bold
ble-face -s varname_empty             fg=31
ble-face -s varname_export            fg=200,bold
ble-face -s varname_expr              fg=92,bold
ble-face -s varname_hash              fg=70,bold
ble-face -s varname_number            fg=64
ble-face -s varname_readonly          fg=200
ble-face -s varname_transform         fg=29,bold
ble-face -s varname_unset             fg=124
ble-face -s argument_option           fg=teal
ble-face -s argument_error            fg=black,bg=225
```

現在の描画設定の一覧は以下のコマンドでも確認できます (`ble-face` を無引数で呼び出す)。
```console
$ ble-face
```

色コードはシェル関数 `ble-color-show` (`ble.sh` 内で定義) で確認できます。
```console
$ ble-color-show
```

## 2.7 キーバインディング

キーバインディングはシェル関数 `ble-bind` を使って変更できます。
例えば <kbd>C-x h</kbd> を入力した時に "Hello, world!" と挿入させたければ以下のようにします。
```bash
ble-bind -f 'C-x h' 'insert-string "Hello, world!"'
```

上記の <kbd>C-x h</kbd> の様なキー表記については
[マニュアル §3.1](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A73-%E3%82%AD%E3%83%BC%E3%83%90%E3%82%A4%E3%83%B3%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0#user-content-sec-kspecs) で詳細に説明されています。
スペース・タブ・エンター・バックスペース・エスケープなどの特殊キーの表記については
[マニュアル §3.1.1](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A73-%E3%82%AD%E3%83%BC%E3%83%90%E3%82%A4%E3%83%B3%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0#user-content-sec-kspecs-ret) で説明されています:
スペースは <kbd>SP</kbd> と表現します。
タブキーは端末によって <kbd>C-i</kbd> または <kbd>TAB</kbd> と表現します。
エンター・リターンキーは端末によって <kbd>C-m</kbd> または <kbd>RET</kbd> と表現します。
バックスペースは端末によって <kbd>C-?</kbd>, <kbd>DEL</kbd>, <kbd>C-h</kbd>, または <kbd>BS</kbd> 等様々な表現があります。
<kbd>Ctrl+Return</kbd> や <kbd>Shift+Return</kbd> などの修飾された特殊キーの取り扱いについては
[マニュアル §3.6.4](https://github.com/akinomyoga/ble.sh/wiki/%E8%AA%AC%E6%98%8E%E6%9B%B8-%C2%A73-%E3%82%AD%E3%83%BC%E3%83%90%E3%82%A4%E3%83%B3%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0#user-content-sec-modifyOtherKeys-manual) で説明されています。
お使いの端末が `modifyOtherKeys` に対応していない場合、手動で各キーの組み合わせに対応するエスケープシーケンスを設定する必要があります。


<kbd>M-c</kbd> を入力した時にコマンドを実行するには以下のようにします。

```bash
ble-bind -c 'M-c' 'my-command'
```

<kbd>C-r</kbd> を入力した時に、ユーザー定義編集関数 (Bash の `bind -x` で指定するのと同様の物) を実行するには以下のようにします。

```bash
ble-bind -x 'C-r' 'my-edit-function'
```

既存のキーバインディングは以下のコマンドで確認できます。
```console
$ ble-bind -P
```

以下のコマンドでキーバインディングに使える編集関数一覧を確認できます。
```console
$ ble-bind -L
```

一つのキーで複数の編集関数を呼び出したい場合は、以下の例の様に、
`ble/widget/編集関数の名前` という名前のシェル関数を通して新しい編集関数を定義できます。
既存の標準の編集関数と名前が重複しない様に、
編集関数の名前は `ユーザー名/`, `my/`, `blerc/`, `dotfiles/` などで始める事が強く推奨されます。

```bash
# C-t で複数の操作を行う例
function ble/widget/my/example1 {
  ble/widget/beginning-of-logical-line
  ble/widget/insert-string 'echo $('
  ble/widget/end-of-logical-line
  ble/widget/insert-string ')'
}
ble-bind -f C-t my/example1
```

## 2.8 fzf との統合<sup><a id="fzf-integration" href="#fzf-integration">†</a></sup>

`fzf` を `ble.sh` と一緒にお使いいただく場合には、[`contrib/fzf` 統合機能](https://github.com/akinomyoga/blesh-contrib#pencil-fzf-integration) を用いて `fzf` を設定していただく必要があります。
詳細についてはリンク先の説明を御覧ください。

```bash
# blerc

# 注意: fzf を bash_completion と組み合わせて使用する場合は、fzf-completion よ
# りも先に bash_completion をロードしておく必要があります。これは ble.sh と関係
# なく必要です。
source /etc/profile.d/bash_completion.sh

ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
```

上記 `ble-import` に指定されているオプション `-d` は指定したファイルの読み込み
を遅延させます。このように設定した場合、指定したファイルはプロンプトが表示され
た後にバックグランドで読み込まれます。詳細に関しては [`ble-import` - 説明書
§8](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A78-Miscellaneous#user-content-fn-ble-import)
を御覧ください。もし fzf の設定を読み込んだ後で更に設定を行うには、四つの方法が
ございます。最も単純な方法はオプション `-d` を指定しない方法 [1] です。或いは、
`ble-import -d` [2] または `ble/util/idle.push` [3] を用いて追加設定も同様に遅
延させることができます。または、fzf 設定ファイルの読み込み完了に対して
`ble-import -C` [4] を用いてフックを設定することもできます。

```bash
# [1] オプション -d を使用しない
ble-import integration/fzf-completion
ble-import integration/fzf-key-bindings
<settings>

# [2] 追加設定も ble-import -d を使う
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble-import -d '<filename containing the settings>'

# [3] 追加設定を ble/util/idle.push で登録
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble/util/idle.push '<settings>'

# [4] 追加設定を ble-import -C で登録
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble-import -C '<settings>' integration/fzf-key-bindings
```

# 3 ヒント

## 3.1 複数行モード

コマンドラインに改行が含まれている場合、複数行モード (MULTILINE モード) になります。

<kbd>C-v C-j</kbd> または <kbd>C-q C-j</kbd> とすると改行をコマンドラインの一部として入力できます。
複数行モードでは、<kbd>RET</kbd> (<kbd>C-m</kbd>) はコマンドの実行ではなく新しい改行の挿入になります。
複数行モードでは、<kbd>C-j</kbd> を用いてコマンドを実行して下さい。

`shopt -s cmdhist` が設定されているとき (既定)、もし <kbd>RET</kbd> (<kbd>C-m</kbd>) を押した時にコマンドラインが構文的に閉じていなければ、コマンドの実行ではなく改行の挿入を行います。

## 3.2 Vim モード

`.bashrc` に `set -o vi` が設定されているとき、または `.inputrc` に `set editing-mode vi` が設定されているとき、vim モードが有効になります。
Vim モードの詳細な設定については [Wiki のページ (英語)](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode) を御覧ください。

## 3.3 自動補完

Bash 4.0 以降では自動補完が有効になり、予測候補が表示されます。
候補を確定するには <kbd>S-RET</kbd> を入力します (編集文字列の末尾にいる時は <kbd>right</kbd>, <kbd>C-f</kbd> または <kbd>end</kbd> でも確定できます)。
表示されている候補の初めの単語だけ部分的に確定する時は <kbd>M-f</kbd> または <kbd>M-right</kbd> を入力します。
現在の候補で確定しそのままコマンドを実行する場合には <kbd>C-RET</kbd> (※お使いの端末が対応している時) を入力します。
お使いの端末が対応していない時は [マニュアル §3.6.4](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A73-Key-Binding#user-content-sec-modifyOtherKeys-manual) を参照して下さい。


## 3.4 静的略語展開

特定の単語を静的略語展開に登録することで好きな文字列に展開することができます。
登録済み単語に一致する単語の直後で <kbd>SP</kbd> を入力した時に静的略語展開が起きます。
例えば、以下の設定をしておくと `command L` まで入力した状態で <kbd>SP</kbd> を押した時に、コマンドラインが `command | less` に展開されます。

```bash
# blerc
ble-sabbrev L='| less'
```

実際に実行したいコマンドに含まれる可能性の低い単語として、`\` で始まる単語を静的略語展開に登録することもお薦めです。

```bash
# blerc
ble-sabbrev '\L'='| less'
```

`~` で始まる静的略語展開は <kbd>/</kbd> でも展開されます。これは Zsh の名前付きディレクトリ (named directories) に模した使い方ができます。
例えば、以下の設定の下で `~mybin/` と入力すると、`/home/user/bin/` など (`HOME=/home/user` の場合) に展開されます。

```bash
# blerc

ble-sabbrev "~mybin=$HOME/bin"
```

# 4 謝辞

GitHub の Issue/PR を通して多くの方からフィードバックを頂き、皆様に本当に感謝しております。
特に以下の方には大きな寄与を受けたので言及させていただきます。

- [`@cmplstofB`](https://github.com/cmplstofB) 様には vim モードの実装において初期よりテスト及び様々な提案をしていただきました。
- [`@dylankb`](https://github.com/dylankb) 様には `fzf` との互換性や `ble.sh` 初期化に関連して様々な問題報告をいただきました。
- [`@rux616`](https://github.com/rux616) 様には幾つかの問題報告および `.blerc` の既定パス解決のバグ修正をいただきました。
- [`@timjrd`](https://github.com/timjrd) 様には補完の枠組みの高速化に関する PR をいただきました。
- [`@3ximus`](https://github.com/3ximus) 様には広範囲に渡る様々な問題について報告いただきました。
- [`@SuperSandro2000`](https://github.com/SuperSandro2000) 様には NixOS 関係を始め様々なご報告をいただきました。
