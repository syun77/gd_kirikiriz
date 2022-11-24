extends Node2D

# 吉里吉里のタグコマンド.
class KAGTag:
	var name:String = "" # タグ名
	var attrs = {} # 属性.
	
	# コンストラクタ.
	func _init(_name:String, _attrs):
		name = _name
		attrs = _attrs

	# 属性を取得する.
	func get_attr_value(key:String) -> String:
		var ret = get_attr_value_raw(key)
		# ダブルクォートを消しておく.
		return ret.replace('"', "")
	
	# 属性をそのまま取得する.
	func get_attr_value_raw(key:String) -> String:
		if key in attrs:
			return attrs[key].value
		else:
			# 存在しない属性名を指定した.
			return ""		
	
	func _to_string() -> String:
		var ret = "[%s"%name
		for attr in attrs:
			ret += " " + str(attr)
		ret += "]"
		return ret

# 吉里吉里のタグの属性.
class KAGAttr:
	var name:String = "" # 属性の名前.
	var value:String = "" # 属性の値.
	
	# コンストラクタ.
	func _init(_name:String, _value:String):
		name = _name
		value = _value
	func _to_string() -> String:
		return "%s=%s"%[name, value]
		
# 吉里吉里のメッセージ
class KAGMsg:
	var msg:String = ""
	var is_click:bool = false # クリック待ちするかどうか.
	var is_ctrl:bool = false # 改行するかどうか.
	var is_pf:bool = false # 改ページするかどうか.
	func _init(_msg:String, _is_click:bool, _is_ctrl:bool, _is_pf:bool):
		msg = _msg
		is_ctrl = _is_ctrl
		is_click = _is_click
		is_pf = _is_pf
	func _to_string() -> String:
		var ret = msg
		if is_pf:
			ret += "[p]"
		else:
			if is_click:
				ret += "[l]"
			if is_ctrl:
				ret += "[r]"
		
		return ret

# 吉里吉里のラベル.
class KAGLabel:
	var name:String = ""
	var comment:String = ""
	func _init(_name:String, _comment:String):
		name = _name
		comment = _comment
	func _to_string():
		var ret = "*%s"%name
		if comment != "":
			ret += " | %s"%comment
		return ret

# 状態.
enum eState {
	EXEC_SCRIPT, # スクリプト実行中.
	MESSAGE_WAIT, # メッセージ待ち.
	TIME_WAIT, # 一定時間待つ.
	END, # 終了.
}

# コマンドの戻り値.
enum eCmdRet {
	YIELD, # 中断する.
	CONTINUE, # 継続する.
}

# 会話ウィンドウテキスト.
onready var _text = $LayerTalkWindow/Window/Text
# 会話ウィンドウカーソル.
onready var _cursor = $LayerTalkWindow/Window/Cursor

# コマンドリスト.
var _timer = 0.0
var _state = eState.EXEC_SCRIPT
var _cmd_idx = 0 # コマンド実行カウンタ.
var _cmd_list = [] # コマンドリスト.
var _cmd = null # 現在実行中のコマンド.

func _ready() -> void:
	# スクリプトファイルの読み込み
	var f = File.new()
	f.open("res://script.txt", File.READ)
	var data = f.get_as_text()
	f.close()
	
	# スクリプトを解析する
	_parse(data)
	
# 更新.
func _process(delta: float) -> void:
	# デバッグ用
	if Input.is_action_just_pressed("ui_cancel"):
		# リロードする
		get_tree().change_scene("res://Main.tscn")
	
	# スクリプトの更新.
	match _state:
		eState.EXEC_SCRIPT: # スクリプト実行中.
			_exec_script()
		eState.MESSAGE_WAIT: # メッセージ待ち.
			_message_wait(delta)
		eState.TIME_WAIT:
			_time_wait(delta) # 一定時間待つ.
		eState.END: # 終了.
			_text.text = "<<スクリプト終了>>"
# --------------------------------------
# ここから_stateに対応する処理.
# --------------------------------------
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

# テキスト待ち.
func _message_wait(delta:float) -> void:
	_timer += delta
	var msg:KAGMsg = _cmd
	
	# カーソルアニメーション.
	if msg.is_click:
		_cursor.visible = true
		_cursor.scale.x = sin(_timer * 4) # 回転させてみる.
	
	if msg.is_click == false or Input.is_action_just_pressed("ui_click"):
		# クリック待ちでない or クリックしたのでメッセージ送り.
		if msg.is_ctrl:
			# 改行する.
			_text.text += "\n"
		if msg.is_pf:
			# 改ページの場合はメッセージを消す.
			_text.text = ""
		
		# カーソルを消します.
		_cursor.visible = false
		
		# スクリプト実行に戻る
		_state = eState.EXEC_SCRIPT

# 一定時間待つ.
func _time_wait(delta:float) -> void:
	_timer -= delta
	if _timer < 0:
		# 待ち時間終了.
		# スクリプト実行に戻る.
		_state = eState.EXEC_SCRIPT

# --------------------------------------
# ここからコマンドタグ実行処理..
# --------------------------------------
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
	
	# ファイル名を取得
	var file = tag.get_attr_value("storage")
	var res = "res://assets/" + file
	var res2 = res + ".jpg"
	var directory = Directory.new()
	if directory.file_exists(res2) == false:
		res2 = res + ".png"
		if directory.file_exists(res2) == false:
			push_error("画像ファイルが見つかりません: %s"%res2)
			return eCmdRet.CONTINUE # 続行する.
	# 画像読み込み.
	tex.texture = load(res2)
	
	# 位置を設定.
	tex.rect_position.x = 0
	tex.rect_position.y = 0
	var left = tag.get_attr_value("left")
	if left != "":
		tex.rect_position.x = int(left)
	var top = tag.get_attr_value("top")
	if top != "":
		tex.rect_position.y = int(top)
	
	return eCmdRet.CONTINUE # 続行する.

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

# メッセージ消去タグ.
func _cm(tag:KAGTag) -> int:
	# メッセージを消去する.
	_text.text = ""
	return eCmdRet.CONTINUE # 続行する.

# --------------------------------------
# ここからスクリプト解析処理.
# --------------------------------------
# スクリプトを解析する.	
func _parse(txt:String) -> void:
	var data = txt.split("\n")
	for line in data:
		line = line.strip_edges ()
		if line == "":
			continue # 空行は読み飛ばします.
		#print(line)
		var tag = _parse_tag(line)
		if tag:
			_cmd_list.append(tag)
			continue
		var label = _parse_label(line)
		if label:
			_cmd_list.append(label)
			continue
			
		# それ以外はメッセージ
		var msg = _parse_msg(line)
		_cmd_list.append(msg)

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
	if attrs_result:
		# スペースで分割する
		var arr = attrs_result.split(" ")
		for a in arr:
			# "=" で分割する.
			var d = a.split("=")
			var key = d[0]
			var attr = KAGAttr.new(key, d[1])
			attrs[key] = attr
		
	var kag = KAGTag.new(name, attrs)
	return kag

## ラベルの解析.
func _parse_label(txt:String) -> KAGLabel:
	var regex = RegEx.new()
	regex.compile("^\\*(?<label>[\\D][\\w]*)[|]?(?<comment>.+)*")
	var result = regex.search(txt)
	if result == null:
		return null
	
	# ラベル名を取得する.
	var label = result.get_string("label")
	# コメントを取得する.
	var comment = ""
	var comment_result = result.get_string("comment")
	if comment_result:
		comment = comment_result
	
	var kag = KAGLabel.new(label, comment)
	return kag

## メッセージの解析.
func _parse_msg(txt:String) -> KAGMsg:
	var msg = txt
	var is_click = txt.find("[l]") >= 0 # クリック待ちするかどうか.
	var is_ctrl = txt.find("[r]") >= 0 # 改行するかどうか.
	var is_pf = txt.find("[p]") >= 0 # 改ページするかどうか.
	if is_pf:
		# 改ページ
		is_ctrl = false # 改行不要.
		is_click = true # クリック待ちする.
	# 余計なタグを消す.
	msg = msg.replace("[l]", "")
	msg = msg.replace("[r]", "")
	msg = msg.replace("[p]", "")
	
	var kag = KAGMsg.new(msg, is_click, is_ctrl, is_pf)
	return kag
