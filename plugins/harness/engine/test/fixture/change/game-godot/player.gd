extends CharacterBody2D
var speed = 200
var hp := 3
func _ready():
	print("ready")
	var hud = get_node("../HUD")
