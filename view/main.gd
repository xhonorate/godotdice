extends Control
## Deep Cut's root. The app shell is built in `view/app.gd`; this only hands over to it.

func _ready() -> void:
	var app := load("res://view/app.gd")
	if app != null:
		var shell: Node = app.new()
		add_child(shell)
