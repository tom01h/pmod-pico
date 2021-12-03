# Raspberry pi pico で Xlinx FPGA と PC をつなぐ

ホスト PC では Ubuntu を使っています。

## pico 用ファームウェアの準備

[pico-sdk](https://raspberrypi.github.io/pico-sdk-doxygen/) を [github](https://github.com/raspberrypi/pico-sdk.git) からクローンする。

サブモジュールの tinyUSB を取得 ` git submodule update --init` 。

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

`dirtyJtag.uf2` を pico にコピーする。

## USB UART

pico の↓のハードウエア UART ピンを FPGA の UART とつなぐ。

```c
#define UART_TX_PIN 0
#define UART_RX_PIN 1
```

FPGA の UART は 115200bps に設定する。

pico の USB をつなぐと /dev/ttyACMn が生えてくる。

## バスマスタコントロール

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

`host/pmodUsb.c` を参考に、書き込みは `send_data.data` にデータを書いて `write_dev(SIZE, waddress, send_data);`。

読み出しは `read_dev(SIZE, raddress, receive_data);` を実行すると `receive_data` に読み出しデータが書き込まれる。

シングル転送時には、SIZE には 1,2,4 バイト時は 1,2,4 を、8バイト時は 6 を設定する。

バースト転送は 8バイト×128バーストまで対応。(バースト長-1)×8 を SIZE に設定する。バースト転送は ４KB 境界をまたいではいけない。

最大バースト時に書き込み、読み出しともに 5Mbps 弱の速度で動く。

 