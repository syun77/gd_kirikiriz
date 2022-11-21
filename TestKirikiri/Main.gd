extends Node2D

# 吉里吉里のタグコマンド.
class KzTag:
	var name:String = ""
	var attrs = []
	func _init(_name:String, _attrs):
		name = _name
		attrs = _attrs
	
	func _to_string() -> String:
		var ret = "[%s"%name
		for attr in attrs:
			ret += " " + str(attr)
		ret += "]"
		return ret

# 吉里吉里のタグの属性.
class KzAttr:
	var name:String = ""
	var value:String = ""
	func _init(_name:String, _value:String):
		name = _name
		value = _value
	func _to_string() -> String:
		return "%s=%s"%[name, value]
		
# 吉里吉里のメッセージ
class KzMsg:
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
class KzLabel:
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

func _ready():
	var f = File.new()
	f.open("res://script.txt", File.READ)
	
	var data = f.get_as_text()
	
	f.close()
	
	_parse(data)
	
func _parse(txt:String) -> void:
	var data = txt.split("\n")
	for line in data:
		line = line.strip_edges ()
		if line == "":
			continue # 空行は読み飛ばします.
		#print(line)
		var tag = _parse_tag(line)
		if tag:
			print("#TAG  # ", tag)
			continue
		var label = _parse_label(line)
		if label:
			print("#LABEL# ", label)
			continue
			
		# それ以外はメッセージ
		var msg = _parse_msg(line)
		print("#MSG  # ", msg)

## タグの解析.
func _parse_tag(txt:String) -> KzTag:
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
	
	var name = result.get_string("tag")
	var attrs = []
	var attrs_result = result.get_string("attrs")
	if attrs_result:
		# スペース区切り.
		var arr = attrs_result.split(" ")
		for a in arr:
			var d = a.split("=")
			var attr = KzAttr.new(d[0], d[1])
			attrs.append(attr)
		
	var kz = KzTag.new(name, attrs)
	return kz

## ラベルの解析.
func _parse_label(txt:String) -> KzLabel:
	var regex = RegEx.new()
	regex.compile("^\\*(?<label>[\\D][\\w]*)[|]?(?<comment>.+)*")
	var result = regex.search(txt)
	if result == null:
		return null
	
	var label = result.get_string("label")
	var comment = ""
	var comment_result = result.get_string("comment")
	if comment_result:
		comment = comment_result
	var kz = KzLabel.new(label, comment)
	return kz

## メッセージお解析.
func _parse_msg(txt:String) -> KzMsg:
	var msg = txt
	var is_click = txt.find("[l]") >= 0
	var is_ctrl = txt.find("[r]") >= 0
	var is_pf = txt.find("[p]") >= 0
	if is_pf:
		# 改ページ
		is_ctrl = false # 改行不要.
		is_click = true # クリック待ちする.
	# 余計なタグを消す.
	msg = msg.replace("[l]", "")
	msg = msg.replace("[r]", "")
	msg = msg.replace("[p]", "")
	var kz = KzMsg.new(msg, is_click, is_ctrl, is_pf)
	
	return kz
