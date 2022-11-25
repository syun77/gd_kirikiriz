# Godot Engineで吉里吉里のKAGっぽいスクリプトを実装するサンプル

## ノード構成

```
Main (Node2D)
 +-- LayerImage (CanvasLayer)
 |    +-- base (TextureRect): 背景
 |    +-- image0 (TextureRect): 前景レイヤー0
 |
 +-- LayerTalkWindow (CanvasLayer)
      +-- Window (ColorRect): 会話ウィンドウの背景
           +-- Text (RichTextLabel): 会話テキスト
           +-- Cursor (Sprite): テキスト送りカーソル
```

### 補足
前景レイヤーは "0番" のみとしています。たくさんの画像(キャラ)を表示したい場合には、"image0" を複製して連番でノードを作る必要があります。

## Main.gd
Main.gd は大きく分けて以下の3つの処理をしています。

* KAGTag/KAGAttr/KAGMsg/KAGLabel という KAGスクリプトの命令をオブジェクト化するクラスを定義している
* _ready()で "script.txt" を読み込み解析をして KAGオブジェクトを "_cmd_list" にコマンドとして格納している
* _process()で "_cmd_list" に格納されたコマンドを順次実行している

### 各KAGクラスの説明
#### KAGTagクラス
KAGTagクラスは KAG でのタグをオブジェクト化したものです。例えばKAGにおいて、画像を表示するタグは以下のように記述されます。

```
[image storage="bg001" layer=base]
```

このタグは以下のように要素を構造化できます。

* タグ名: image
* 属性リスト:
	* 属性1:
		* 名前: storage
		* 値: "bg001"
	* 属性2:
		* 名前: layer
		* 値: base

KAGTagは上記の要素のトップの部分の「タグ名」「属性リスト」を持ったクラスとなります。
そしてタグの「属性」は KAGAttr となります。

#### KAGAttrクラス

KAGAttrはKAGタグの属性情報で、キーとなる「名前」と「値」を持ちます。

#### KAGMsgクラス

KAGMsgはKAGで会話テキストを表示するためのコマンドです。

```
背景を表示[l][r]
```

KAGではタグの始まりである "[" が行頭に存在しない場合は会話テキストとしているようなので、上記のように記述されると会話テキストとしています。

今回の実装では、会話テキストには以下のタグを指定できるようにしています。

* `[l]`: クリック待ち
* `[r]`: 改行を入れる
* `[p]`: 改ページ

#### KAGLabelクラス
KAGLabelはラベルの定義で、ラベルジャンプの対象となる名前を定義します。

```
*start
```

ラベルは上記のように、行頭を「*」で開始するとラベル名となります。
ただ今回ラベルジャンプは未実装です。

### スクリプトの解析
スクリプトの解析は _parse() で行っています。

1. スクリプトを1行ずつ読み取る
2. _parse_tag() でその行がタグであれば KAGTag を返す
3. _parse_label() でその行がラベルであれば KAGLabel を返す
4. _parse_msg() でその行が会話テキストであれば KAGMsg を返す
5. スクリプトをすべて読み込み終わるまで 1〜4 を繰り返す

#### _parse_tag(): タグの解析
タグの解析の関数は以下のコードとなっています。

```gdscript
## タグ(+属性)の解析.
func _parse_tag(txt:String) -> KAGTag:
	var regex = RegEx.new()
	regex.compile("^\\[(?<tag>[a-z]+)[ ]?(?<attrs>.+)*\\]")
	var result = regex.search(txt)
	if result == null:
		# コマンド行かどうか調べる.
		regex.compile("^@(?<tag>[a-z]+)[ ]?(?<attrs>.+)*")
		result = regex.search(txt)
		if result == null:
			# コマンド行でもない.
			return null
	
	# タグ名を取得.
	var name = result.get_string("tag")
	
	# 属性を取得する.
	var attrs = {}
	var attrs_result = result.get_string("attrs")
```

タグは [タグ名 属性1=値 属性2=値 ...] という書式で記述されます。
そのため以下の正規表現で対応する文字にマッチングしています。

```
regex.compile("^\\[(?<tag>[a-z]+)[ ]?(?<attrs>.+)*\\]")
```

