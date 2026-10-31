extends CanvasLayer
## Finds newer versions of the game on the LAN and downloads their pack from that PC.
## Only active in exported builds.

const PORT := 47800
const BROADCAST_INTERVAL := 1.0

var version: String = ProjectSettings.get_setting("application/config/version")
var newest := version
var source_ip := ""
var udp := PacketPeerUDP.new()
var server := TCPServer.new()
var broadcast_timer := 0.0
var download: StreamPeerTCP
var download_size := 0
var download_data := PackedByteArray()

@onready var button: Button = $Button


func _ready() -> void:
	set_process(false)
	if not OS.has_feature("template"):
		return
	udp.set_broadcast_enabled(true)
	udp.bind(PORT)
	udp.set_dest_address("255.255.255.255", PORT)
	server.listen(PORT)
	set_process(true)


func _process(delta: float) -> void:
	broadcast_timer -= delta
	if broadcast_timer <= 0.0:
		broadcast_timer = BROADCAST_INTERVAL
		udp.put_packet(version.to_utf8_buffer())

	while udp.get_available_packet_count() > 0:
		var v := udp.get_packet().get_string_from_utf8()
		if download == null and is_newer(v, newest):
			newest = v
			source_ip = udp.get_packet_ip()
			button.text = "Update to v%s" % newest
			button.show()

	if server.is_connection_available():
		var peer := server.take_connection()
		var bytes := FileAccess.get_file_as_bytes(_own_pack())
		peer.put_u64(bytes.size())
		peer.put_data(bytes)

	if download:
		download.poll()
		if download.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if download_size == 0 and download.get_available_bytes() >= 8:
				download_size = download.get_u64()
			if download_size > 0 and download.get_available_bytes() > 0:
				download_data.append_array(download.get_data(download.get_available_bytes())[1])
				if download_data.size() >= download_size:
					_install()


static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _on_button_pressed() -> void:
	button.disabled = true
	button.text = "Downloading v%s..." % newest
	download = StreamPeerTCP.new()
	download.connect_to_host(source_ip, PORT)


func _own_pack() -> String:
	return OS.get_executable_path().get_basename() + ".pck"


# Official export templates refuse `--main-pack`, so the new pack replaces the one next to the exe.
func _install() -> void:
	var file := FileAccess.open(_own_pack(), FileAccess.WRITE)
	file.store_buffer(download_data)
	file.close()
	OS.create_process(OS.get_executable_path(), [])
	get_tree().quit()
