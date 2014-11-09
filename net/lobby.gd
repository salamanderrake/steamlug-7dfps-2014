extends Node

export (String) var host  #Set the default ip in the Godot inspector
export (int) var port     #Set the default port in the Godot inspector

const NET_NAME = 1  # player name
const NET_CHAT = 2  # chat message
const NET_JOIN = 3  # new player joined
const NET_PART = 4  # player left
const NET_STOP = 5  # server stopped
const NET_REDY = 6  # peer toggled ready status
const NET_OKGO = 7  # launch map

const PROTOCOL="H2" #haunt protocol version 2

var peerready       #array of player ready status
var ready
var current_time
var net             #network node

#widgets
var DebugButton
var HostButton
var JoinButton
var StopServerButton
var DisconnectButton
var ReadyButton
var LaunchButton
var LobbyChat
var EnterChat
var PlayerList
var PlayerNameBox

func _ready():
	net = get_node("/root/network")
	net.is_server = false
	ready = false
	net.launched = false
	net.peernames=[]
	peerready=[]
	
	# create peer
	net.peer = StreamPeerTCP.new()

	# create server
	net.server = TCP_Server.new()

	current_time = ""

	# init text and buttons
	DebugButton = get_node("Debug")
	DebugButton.connect("pressed", self, "Lobby_Debug")
	
	PlayerNameBox = get_node("Lobby_Name_Area/Lobby_Player_Name")
	PlayerNameBox.get_node("Lobby_Name_Text").add_text("Name:")
	PlayerNameBox.set_text(net.PlayerName)
	
	HostButton = get_node("Lobby_Host_Area/Lobby_Host_Button")
	HostButton.get_node("Lobby_Host_Port_text").add_text("Server Port")
	HostButton.get_node("Lobby_Host_Port").set_text(str(port))
	HostButton.connect("pressed", self, "On_Lobby_Host_Start")
	
	JoinButton = get_node("Lobby_Join_Area/Lobby_Join_Button")
	JoinButton.get_node("Lobby_Join_IP_text").add_text("Remote IP : Port")
	JoinButton.get_node("Lobby_Join_IP").set_text(host)
	JoinButton.get_node("Lobby_Join_Port").set_text(str(port))
	JoinButton.connect("pressed", self, "On_Lobby_Join_Start")
	
	StopServerButton = get_node("Lobby_Host_Area/Lobby_Stop_Server_Button")
	StopServerButton.connect("pressed", self, "On_Lobby_Stop_Server")
	StopServerButton.set_disabled(true)
	
	LaunchButton = get_node("Lobby_Host_Area/Lobby_Launch_Button")
	LaunchButton.connect("pressed", self, "On_Launch_Map")
	LaunchButton.set_disabled(true)
	
	DisconnectButton = get_node("Lobby_Join_Area/Lobby_Disconnect_Button")
	DisconnectButton.connect("pressed", self, "On_Lobby_Disconnect")
	DisconnectButton.set_disabled(true)
	
	ReadyButton = get_node("Lobby_Chat_Area/Lobby_Ready_Button")
	ReadyButton.connect("pressed", self, "On_Lobby_Ready")
	ReadyButton.get_node("Lobby_Ready_Text").add_text("NO")
	ReadyButton.set_disabled(true)
	
	LobbyChat = get_node("Lobby_Chat_Area/Lobby_Chat")
	
	EnterChat = get_node("Lobby_Chat_Area/Lobby_Enter_Chat")
	EnterChat.connect("text_entered", self, "On_Enter_Chat")
	
	PlayerList = get_node("Lobby_Chat_Area/Lobby_Player_List")
	
	set_process(true)

#add server browser later?
#func _on_selected_item(id):
#	is_server = id == 0

func Lobby_Debug():
	Lobby_Chat("peer names:")
	for i in range(0,net.peernames.size()):
		Lobby_Chat(net.peernames[i])

func On_Launch_Map():
	Lobby_Chat("Launching map..")
	if net.is_server:
		for apeer in net.peers:
				Lobby_Tcp_Send(apeer, NET_OKGO, "go!")
	net.launched=true
	get_node("/root/scene_switcher").goto_scene("res://map1/map1.xscn")



func On_Lobby_Ready():
	var text
	if net.is_server:
		if ready:
			text=(str("<",net.PlayerName,"> is NOT ready."))
		else:
			text=(str("<",net.PlayerName,"> is ready!"))
		Lobby_Chat(text)
		for apeer in net.peers:
			Lobby_Tcp_Send(apeer, NET_CHAT, text)
	else:
		Lobby_Tcp_Send(net.peer, NET_REDY, "rdy")
	ReadyButton.get_node("Lobby_Ready_Text").clear()
	if ready:
		ready=false
		ReadyButton.get_node("Lobby_Ready_Text").add_text("NO")
	else:
		ready=true
		ReadyButton.get_node("Lobby_Ready_Text").add_text("YES")

func Lobby_Chat ( text ):
	current_time = str(OS.get_time().hour) + ":" + str(OS.get_time().minute)
	LobbyChat.add_text(current_time + " " + text)
	LobbyChat.newline()

func On_Enter_Chat( text ):
	if net.is_server:
		text=str("<",net.PlayerName,">",text)
		Lobby_Chat(text)
		for apeer in net.peers:
			Lobby_Tcp_Send(apeer, NET_CHAT, text)
	else:
		Lobby_Tcp_Send(net.peer, NET_CHAT, text)
	EnterChat.clear()

func On_Lobby_Stop_Server( ):
	for apeer in net.peers:
		Lobby_Tcp_Send(apeer, NET_STOP, "bye")
	net.server.stop()
	net.peernames.clear()
	Lobby_Update_Player_List()
	Lobby_Chat("[SERVER] stopped.")
	HostButton.set_disabled(false)
	JoinButton.set_disabled(false)
	StopServerButton.set_disabled(true)
	PlayerNameBox.set_editable(true)
	ReadyButton.set_disabled(true)

func On_Lobby_Disconnect( ):
	Lobby_Tcp_Send(net.peer, NET_PART, "bye")
	net.peernames.clear()
	net.peer.disconnect()
	Lobby_Update_Player_List()
	Lobby_Chat("[PEER] disconnected.")
	JoinButton.set_disabled(false)
	DisconnectButton.set_disabled(true)
	PlayerNameBox.set_editable(true)
	ReadyButton.set_disabled(true)

func On_Lobby_Host_Start( ):
	Lobby_Chat("[SERVER] init!")
	net.PlayerName=PlayerNameBox.get_text()
	net.peers = []
	net.is_server = true
	port=HostButton.get_node("Lobby_Host_Port").get_text()
	Lobby_Update_Player_List()
	net.server.listen(port)
	HostButton.set_disabled(true)
	JoinButton.set_disabled(true)
	StopServerButton.set_disabled(false)
	ReadyButton.set_disabled(false)


func On_Lobby_Join_Start( ):
	var status=0
	var start_time=0
	var check_time=0
	HostButton.set_disabled(true)
	JoinButton.set_disabled(true)
	PlayerNameBox.set_editable(false)
	ReadyButton.set_disabled(false)
	Lobby_Chat("[PEER] init!")
	net.PlayerName=PlayerNameBox.get_text()
	net.host=JoinButton.get_node("Lobby_Join_IP").get_text()
	net.port=JoinButton.get_node("Lobby_Join_Port").get_text()
	net.peer.connect(host, port)
	status=net.peer.get_status()
	start_time=OS.get_ticks_msec()
	
	#wait for connection, timeout after 5 seconds
	while (status < StreamPeerTCP.STATUS_CONNECTED) && (check_time - start_time < 5000):
		check_time=OS.get_ticks_msec()
		status=net.peer.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		Lobby_Chat(str("[PEER] connection to ", host, ":", port, "... SUCCESS!"))
		Lobby_Tcp_Send(net.peer, NET_NAME, net.PlayerName)
		DisconnectButton.set_disabled(false)
	else:
		Lobby_Chat(str("[PEER] connection to ", host, ":", port, "... FAIL!"))
		net.peer.disconnect()
		JoinButton.set_disabled(false)

func Lobby_Update_Player_List():
	PlayerList.clear()
	PlayerList.add_text("Players:")
	PlayerList.newline()
	if net.is_server:
		PlayerList.add_text(net.PlayerName)
		PlayerList.newline()
	for i in range(0,net.peernames.size()):
		PlayerList.add_text(net.peernames[i])
		PlayerList.newline()

func Lobby_Tcp_Send(apeer, type, text):
	var rawdata = RawArray()
	var len = text.length()
	var i=0
	if(len>254):
		len=254  #no data over 254 bytes
	rawdata.push_back(PROTOCOL.ord_at(0))
	rawdata.push_back(PROTOCOL.ord_at(1))
	rawdata.push_back((len+1))
	rawdata.push_back(str(type))
	while(i<len):
		rawdata.push_back( text.ord_at(i) )
		i=i+1
	rawdata.push_back(0)
	apeer.put_data(rawdata)

func Lobby_Peer_Recv():
	var len=0
	var type
	var raw_packet=RawArray()
	var raw_err=RawArray()
	var raw_data=RawArray()
	var Protocol=RawArray()
	raw_packet=net.peer.get_partial_data(4)
	raw_err=raw_packet[0]
	raw_data=raw_packet[1]
	if(raw_err !=0 or raw_data.size() < 4):
		#error or no data this frame
		return
	Protocol.push_back(raw_data[0])
	Protocol.push_back(raw_data[1])
	if(Protocol.get_string_from_utf8() != PROTOCOL):
		Lobby_Chat(str("[ERR] version missmatch ", Protocol.get_string_from_utf8()))
		net.peer.disconnect()
		return
	len=raw_data[2]
	type=raw_data[3]
	if(len<1):
		return
	raw_packet=net.peer.get_data(len)
	raw_err=raw_packet[0]
	raw_data=raw_packet[1]
	if(type==NET_CHAT):
		var rawtext=RawArray()
		for i in range(0,raw_data.size()):
			rawtext.push_back( raw_data[i] )
		Lobby_Chat(str(rawtext.get_string_from_utf8()))
	if(type==NET_JOIN):
		var rawtext=RawArray()
		for i in range(0,raw_data.size()):
			rawtext.push_back( raw_data[i] )
		var name=rawtext.get_string_from_utf8()
		net.peernames.append(name)
		Lobby_Chat(str(name, " joined lobby."))
		Lobby_Update_Player_List()
	if(type==NET_PART):
		var rawtext=RawArray()
		for i in range(0,raw_data.size()):
			rawtext.push_back( raw_data[i] )
		var index=rawtext.get_string_from_utf8()
		Lobby_Chat(str(net.peernames[index.to_int()]," disconnected."))
		net.peernames.remove(index.to_int())
		Lobby_Update_Player_List()
	if(type==NET_STOP):
		net.peer.disconnect()
		Lobby_Chat("Disconnected: Server stopped.")
		net.peernames.clear()
		Lobby_Update_Player_List()
		JoinButton.set_disabled(false)
		DisconnectButton.set_disabled(true)
		PlayerNameBox.set_editable(true)
	if(type==NET_OKGO):
		Lobby_Chat("Launching map..")
		On_Launch_Map()


func Lobby_Server_Recv( index, apeer ):
	var len=0
	var type
	var raw_packet=RawArray()
	var raw_err=RawArray()
	var raw_data=RawArray()
	var Protocol=RawArray()
	raw_packet=apeer.get_partial_data(4)
	raw_err=raw_packet[0]
	raw_data=raw_packet[1]
	if(raw_err !=0 or raw_data.size() < 4):
		#error or no data this frame
		return
	Protocol.push_back(raw_data[0])
	Protocol.push_back(raw_data[1])
	if(Protocol.get_string_from_utf8() != PROTOCOL):
		Lobby_Chat(str("[ERR] version missmatch ", Protocol.get_string_from_utf8()))
		apeer.disconnect()
		return
	len=raw_data[2]
	type=raw_data[3]
	if(len<1):
		return
	raw_packet=apeer.get_data(len)
	raw_err=raw_packet[0]
	raw_data=raw_packet[1]
	if(type==NET_NAME):
		var name=RawArray()
		for i in range(0,raw_data.size()):
			name.push_back( raw_data[i] )
		var newname=name.get_string_from_utf8()
		net.peernames.append(newname)
		peerready.append(0)
		Lobby_Chat(str(newname, " joined lobby."))
		Lobby_Update_Player_List()
		#send player join to all peers
		for ipeer in net.peers:
			Lobby_Tcp_Send(ipeer, NET_JOIN, newname)
	if(type==NET_CHAT):
		var rawtext=RawArray()
		var text
		for i in range(0,raw_data.size()):
			rawtext.push_back( raw_data[i] )
		text=str("<",net.peernames[index],"> ",rawtext.get_string_from_utf8())
		Lobby_Chat(text)
		#send chat message to all peers
		for ipeer in net.peers:
			Lobby_Tcp_Send(ipeer, NET_CHAT, text)
	if(type==NET_PART):
		Lobby_Chat(str(net.peernames[index]," disconnected."))
		net.peernames.remove(index)
		peerready.remove(index)
		Lobby_Update_Player_List()
		apeer.disconnect()
		net.peers.remove(index)
		#tell everyone else which player left
		for ipeer in net.peers:
			Lobby_Tcp_Send(ipeer, NET_PART, str(index+1))
	if(type==NET_REDY):
		var text
		if peerready[index]==0:
			peerready[index]=1
			text=(str("<",net.peernames[index],"> is ready!"))
			var count=0
			for i in range(0,peerready.size()):
				if(peerready[i]==1):
					count=count+1
			if count==peerready.size():
				LaunchButton.set_disabled(false)
		else:
			peerready[index]=1
			text=(str("<",net.peernames[index],"> is NOT ready."))
			LaunchButton.set_disabled(true)
		Lobby_Chat(text)
		for apeer in net.peers:
			Lobby_Tcp_Send(apeer, NET_CHAT, text)


func _process(delta):
	if net.is_server:
		if(net.launched==false && net.server.is_connection_available()):
			var newpeer = net.server.take_connection()
			Lobby_Chat(str("[SERVER] new peer, ", newpeer.get_connected_host(), ":", newpeer.get_connected_port()))
			net.peers.append(newpeer)
			#send server player name to new peer
			Lobby_Tcp_Send(newpeer, NET_JOIN, net.PlayerName)
			#send other player names to new peer
			for i in range (0, net.peernames.size()):
				Lobby_Tcp_Send(newpeer, NET_JOIN, net.peernames[i])
		#process new data from peers
		var i=0
		for apeer in net.peers:
			Lobby_Server_Recv(i, apeer)
			i=i+1
	else:
		#process new data from server
		if(net.peer.is_connected()):
			Lobby_Peer_Recv()


