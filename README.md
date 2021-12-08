# Raspberry pi pico で FPGA と PC をつなぐ

Linux のソフトから FPGA にアクセスしたいですよね。でも、SoC FPGA の Linux は難解で CPU は遅いし、PCIe の FPGA はお高いし… USB 接続の FPGA ボードがあるとお手軽そうなんだけどお安いのは見たことない。

そんなわけで、Ubuntu の動く PC と FPGA を Raspberry Pi Pico でつないでみました。結論！お手軽さは期待通りだけど、転送速度は極めて遅いです！！

おまけで USB UART 機能もあります。さらに XVC 機能も盛り込んだ [tom01h/xvc-pico (github.com)](https://github.com/tom01h/xvc-pico) もあります。

## 特徴

Ubuntu PC 上では usblib を使って USB 経由で Raspberry Pi Pico とデータの送受信をします。Pico はUSB のフルスピードに対応しているので、転送速度は理論 MAX で 12Mbps です。今回作ったものは多分ここがボトルネックになっていて、最高で 5Mbps くらいの転送速度でした。USB 転送のコマンドは 1, 2, 4, 8 バイトのシングル転送と、8n バイト (最大1KB) のバースト転送をサポートします。FPGA 内に置くバスマスタは 8バイトのバス幅です。

Pico は USB と GPIO 間でデータの変換をします。Pico SDK は TinyUSB が標準なので、それをそのまま使いました。GPIO と FPGA 間のデータ転送はクロック・リードorライト・ウェイト (FPGAから) 各1本とリードデータとライトデータが各2本の合計7本です。USB で受け取ったリクエストを 、この 7本の信号を使って FPGA に渡します。

FPGA 内では先の7本の信号を使って AXI バスマスタのリクエストを生成します。AXI のデータ幅は 64bit 固定です。

### USB コマンド

バイト0 が 0 の時はリードリクエスト、1 の時はライトリクエストです。

{バイト2, バイト1} は転送サイズです。実際に使うのは 10bit です。1, 2, 4 バイト転送時はそのままバイト数を、8バイト転送時は 6 を、8×n バイト (n=2～128) 時は 8×(n-1) を指定します。

バイト4～7 はアドレスを指定します。バイト8～ は書き込みデータです。

上記のデータを 64バイトに区切って転送します (USB フルスピード転送の最大サイズです)。

### GPIO 転送

端子は PCLK, PWRITE, PWAIT, PRD[1:0], PWD[1:0] の 7本です。

PCLK はコマンド実行時のみトグルします。

USB コマンドのバイト0を PWRITE にのせます。

コマンドの最初の 5サイクルはデータ転送サイズを PWD[1:0] にのせて送ります。続く16 サイクルでアドレスを送ります。

ライトリクエスト時は書き込みデータを必要なだけ転送したらリクエスト終了です。FPGA からのウェイト要求はできません。(全体で USB が速度を律速しているようなので、ここは手抜きしました)

リードリクエスト時は PWAIT が 0のときに有効なデータを受け取ります。リクエストされたデータサイズ分の読み出しデータを PRD[1:0] 経由で受け取るとリクエスト終了です。

## 実行

### pico 用ファームウェアの準備

[pico-sdk](https://raspberrypi.github.io/pico-sdk-doxygen/) を [github](https://github.com/raspberrypi/pico-sdk.git) からクローンする。

サブモジュールの tinyUSB を取得 ` git submodule update --init` 。

依存 (ホストプログラムに必要な物も含めて)

```
sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi \
  libstdc++-arm-none-eabi-newlib git libusb-1.0-0-dev build-essential \
  make g++ gcc
```

環境設定↓。

```shell
export PICO_SDK_PATH=${PICO-SDK-INSTALL}/pico-sdk
export CFLAGS="-Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Wno-unused-but-set-variable"
```

pmod-pico/firmware にて

```shell
cmake .
make
```

`pmodUsb.uf2` を pico にコピーする。

### USB UART を使うには

pico の↓のハードウエア UART ピンを FPGA の UART とつなぐ。

```c
#define UART_TX_PIN 0
#define UART_RX_PIN 1
```

FPGA の UART は 115200bps に設定する。

pico の USB をつなぐと /dev/ttyACMn が生えてくる。

### バスマスタコントロールを使うには

#### FPGA の準備

PC から FPGA の AXIバスマスタをコントロールする。

FPGA には↓のファイルをインスタンスする。

```
fpga/busIf.sv  fpga/pmodCmd.sv  fpga/pmodIf.v
```

pmodIf の端子と pico の↓をつなぐ。

```
#define PWD0_PIN 2
#define PWD1_PIN 3
#define PRD0_PIN 4
#define PRD1_PIN 5
#define PCK_PIN 10
#define PWRITE_PIN 11
#define PWAIT_PIN 12
```

#### ホストプログラム準備

AXI UART Lite が 0x40600000 に、BRAM コントローラが 0xc0000000 にある例です。

`host/pmodUsb.c` を参考に、書き込みは `send_data.data` にデータを書いて `write_dev(SIZE, waddress, send_data);`。

読み出しは `read_dev(SIZE, raddress, receive_data);` を実行すると `receive_data` に読み出しデータが書き込まれる。

シングル転送時には、SIZE には 1,2,4 バイト時は 1,2,4 を、8バイト時は 6 を設定する。

バースト転送は 8バイト×128バーストまで対応。(バースト長-1)×8 を SIZE に設定する。バースト転送は ４KB 境界をまたいではいけない (AXI の決まりで守らなくても大丈夫な時が多い)。

最大バースト時に書き込み、読み出しともに 5Mbps 弱の速度で動く。

 