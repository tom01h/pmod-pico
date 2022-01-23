# MIG を使うのが難しかったところ

[MIG を使って DRAM メモリを動かそう (3) | ACRi Blog (titech.ac.jp)](https://www.acri.c.titech.ac.jp/wordpress/archives/7284) を参考にさせてもらいました

### 端子をケチっているのの対応

何本かの端子が使われていない為の MIG の設定

![CS.png](doc/CS.png)

![VREF.png](doc/VREF.png)

### クロック設定

DDRメモリ用のクロック

AXI のクロック (ui_clk) はこの 1/4 の周波数になる。

![DDRCLK.png](doc/DDRCLK.png)

sys_clk_i に入力する参照用のクロック

clk_ref_i とは別らしいがなんで？

![REFCLK.png](doc/REFCLK.png)

### クロック入力

clk_ref_i は 200MHz クロックを、sys_clk_i は先ほど設定した167MHz を入力する。

![INCLK.png](doc/INCLK.png)

### クロック出力

ui_clk は先ほどの通り 333MHz の 1/4 の 83MHz になる。これを S_AXI 用のクロックに使う。![BD.png](doc/BD.png)