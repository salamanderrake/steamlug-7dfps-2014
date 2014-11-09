extends Node

#network globals

var peers           #array of StreamPeerTCP objects
var peernames       #array of player names
var PlayerName
var is_server
var launched
var server
var peer

func _ready():
	PlayerName = "Player1"
	
	set_process(true)



func _process(delta):
	# Data probably should not be set every tick, add logic to replace true
	if launched:
		# Get coords, direction from scene
		if is_server:
			# Send to clients
			print(PlayerName)
		#else:
			# Send to server
			
	
	# Set player coords from updated player_placement
