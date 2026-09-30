class_name ControllerStream
extends RefCounted
## Shared nonblocking TCP/TLS lifecycle; callers process HTTP/WS only after readiness.

var tcp: StreamPeerTCP
var tls: StreamPeerTLS
var stream: StreamPeer
var failed := false

func _init(connection: StreamPeerTCP, options: TLSOptions = null) -> void:
	tcp = connection
	tcp.set_no_delay(true)
	stream = tcp
	if options != null:
		tls = StreamPeerTLS.new()
		failed = tls.accept_stream(tcp, options) != OK
		stream = tls

func poll_ready() -> bool:
	tcp.poll()
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		failed = true
		return false
	if tls != null:
		tls.poll()
		var state := tls.get_status()
		if state not in [StreamPeerTLS.STATUS_HANDSHAKING, StreamPeerTLS.STATUS_CONNECTED]:
			failed = true
		return state == StreamPeerTLS.STATUS_CONNECTED
	return not failed

func close() -> void:
	if tls != null:
		tls.disconnect_from_stream()
	tcp.disconnect_from_host()
