
extends Spatial

# member variables here, example:
# var a=2
# var b="textvar"

func _ready():
	# Initalization here
	pass

func _on_col_body_enter(body):
	if body.get_name() == "Player":
		body.pickup_oil()
		queue_free()
	pass