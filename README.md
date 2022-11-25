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

```gdscript:Main.gd
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
	...
```

タグは `[タグ名 属性1=値 属性2=値 ...]` という書式で記述されます。
そのため、以下の正規表現で対応する文字にマッチングしています。

```gdscript:Main.gd
regex.compile("^\\[(?<tag>[a-z]+)[ ]?(?<attrs>.+)*\\]")
```

#### _parse_label(): ラベルの解析
ラベルの解析は以下のようにしています。

```gdscript:Main.gd
## ラベルの解析.
func _parse_label(txt:String) -> KAGLabel:
	var regex = RegEx.new()
	regex.compile("^\\*(?<label>[\\D][\\w]*)[|]?(?<comment>.+)*")
	...
```

ラベルの場合は行頭に "*" がある前提としてこのようなマッチングをしています。

#### _parse_msg(): 会話テキストの解析
会話テキストはそれぞれのタグが文字列に含まれるかどうか、という単純なマッチングとしています。

```gdscript:Main.gd
## メッセージの解析.
func _parse_msg(txt:String) -> KAGMsg:
	var msg = txt
	var is_click = txt.find("[l]") >= 0 # クリック待ちするかどうか.
	var is_ctrl = txt.find("[r]") >= 0 # 改行するかどうか.
	var is_pf = txt.find("[p]") >= 0 # 改ページするかどうか.
```

KAGの文法を完全に把握していないので、ひょっとしたらこの判定には問題があるのかもしれませんが、ひとまずこのようにしました。

### コマンドの実行
_process() で _state(状態) に対応する処理を行っています。
_state が保持する状態は現状、以下の4つです。

```gdscript:Main.gd
# 状態.
enum eState {
	EXEC_SCRIPT, # スクリプト実行中.
	MESSAGE_WAIT, # メッセージ待ち.
	TIME_WAIT, # 一定時間待つ.
	END, # 終了.
}
```

#### _exec_script(): スクリプトの実行
_exec_script()では _cmd_list の値を先頭から順番に実行していきます。

```gdscript:Main.gd
# スクリプト実行.
func _exec_script() -> void:
	
	var is_loop = true
	while is_loop:
		if _cmd_idx >= _cmd_list.size():
			# スクリプト終了.
			_state = eState.END
			break # 処理を中断する.
		
		# コマンド読み取り.
		_cmd = _cmd_list[_cmd_idx]
		_cmd_idx += 1 # コマンドを次に進める.
		
		# コマンドの種類ごとに処理をする.
		if _cmd is KAGTag:
			var tag:KAGTag = _cmd
			print("#TAG  # ", tag)
			var ret = _exec_tag(tag) # タグを実行する.
			match ret:
				eCmdRet.YIELD:
					is_loop = false # 処理を中断する.
				eCmdRet.CONTINUE:
					pass # 処理を継続する.
			
		elif _cmd is KAGMsg:
			var msg:KAGMsg = _cmd
			print("#MSG  # ", msg)
			# メッセージを表示.
			_text.text += msg.msg
			_state = eState.MESSAGE_WAIT	
			is_loop = false # 処理を中断する.
				
		elif _cmd is KAGLabel:
			var label:KAGLabel = _cmd
			print("#LABEL# ", label)
			# TODO: 未実装.
			
		else:
			push_error("不明なコマンド: " +  str(_cmd))
```

コマンドの種類は "is" 演算子で比較し対応する処理を行います。例えば、コマンドが "KAGMsg" であればテキスト表示となるので、_state を eState.MESSAGE_WAIT に遷移しています（※ただKAGMsgが必ずしもクリック待ちになるとは限らないので、このあたり調整が必要となるかもしれません）。
ノベルゲームエンジンでは、会話テキストのクリック待ちといった「ユーザー入力を受け付ける」「一定時間停止する」といった何らかのインタラクションがある場合、スクリプトの実行状態とそれ以外の状態への切り替えることが基本の実装方法となります。

#### _exec_tag(): タグの実行
このプログラムを拡張していく場合、タグの追加が必須となると思います。
タグの実行は以下の記述となっています。

```gdscript:Main.gd
# タグを実行する.
func _exec_tag(tag:KAGTag) -> int:
	# 関数名は "_" + タグ名.
	# @note タグを追加する場合は "_[タグ名]" の関数を追加します.
	var ret = eCmdRet.CONTINUE
	var func_name = "_" + tag.name
	if has_method(func_name):
		# タグ関数呼び出し.
		ret = call(func_name, tag)
	else:
		push_warning("未実装の関数: %s"%func_name)

	# コマンド実行時の戻り値を返す.
	return ret
```

GDScriptはクラス内の関数を「文字列指定」で呼び出すことができる call() が用意されています。
それを使って、タグ名に対して先頭に「_」をつけた関数を呼び出すようにして、各タグの処理を実行しています。例えば "image" タグは、"_image" を呼び出しています。

以下、image()の実装コードです。

```gdscript:Main.gd
# 画像タグの実行.		
func _image(tag:KAGTag) -> int:
	var layer = tag.get_attr_value("layer") # レイヤー名.
	if layer != "base":
		# baseでない場合は 前景レイヤー番号なので "image" を先頭につける.
		layer = "image" + layer
	# TextureRectを取得する.
	var tex:TextureRect = get_node("LayerImage/" + layer)
	
	# 表示モード.
	var display = tag.get_attr_value("visible")
	if display == "false":
		# 非表示の場合はここで終了
		tex.visible = false
		return eCmdRet.CONTINUE # 続行する.
	# それ以外は表示するとします
	tex.visible = true
	
  ...
  	
	return eCmdRet.CONTINUE # 続行する.
```

細かい属性の処理は省略していますが、基本的にはタグに含まれる属性の値で TextureRectノードを取得して各パラメータを設定しています。例えば、imageタグには "layer" という属性があるので、それに対応する TextureRect を取得しています。

関数の戻り値は、スクリプトの実行を続行するかどうかです。imageタグは画像を表示・非表示するだけでインタラクションが存在しないので、"eCmdRet.CONTINUE" を返しています。

それに対して、waitタグの関数 "_wait()" は、待ち時間のインタラクションが発生するので "eCmdRet.YIELD" を返しています。

```gdscript:Main.gd
# 一定時間待つタグ.
func _wait(tag:KAGTag) -> int:
	# 待ち時間.
	var time = int(tag.get_attr_value("time"))
	# msを秒に変換する.
	time *= 0.001

	# 一定時間待つ状態に遷移.	
	_state = eState.TIME_WAIT
	_timer = time
	
	return eCmdRet.YIELD # 待ち状態に入るので処理を中断する..
```

