class_name MinigameProtocol
extends RefCounted
## The transport adapter of one running minigame. The WebSocket service routes the message
## types it [method handles] here, sends what it asks for, and asks it for each player's
## snapshot on joins, reconnects and broadcasts. A minigame adds a subclass; the shared service
## needs no change for it.

## Asks the service to send [param message] to one player. With [param coalesce], the message is
## dropped while that player's connection still has output queued, for frequent visual updates.
@warning_ignore("unused_signal")
signal send_requested(player_id: String, message: Dictionary, coalesce: bool)
## Asks the service to send every joined player a fresh snapshot.
@warning_ignore("unused_signal")
signal broadcast_requested


## True for the client message types this protocol accepts.
func handles(_message_type: String) -> bool:
	return false


## Handles one client message from a host-resolved [param player]. Returns at least
## [code]accepted[/code]; a rejection carries [code]code[/code] and [code]message[/code]. An
## accepted result may carry a [code]reply[/code] for the sender and [code]snapshot: true[/code]
## to follow it with the sender's snapshot.
func handle_message(_player: Dictionary, _message: Dictionary, _host_msec: int) -> Dictionary:
	return { "accepted": false, "code": &"unsupported_message", "message": "Not supported" }


## The full state one player's phone needs now.
func snapshot_for(_player_id: String) -> Dictionary:
	return { "type": "lobby", "state": "waiting", "message": "Waiting for the next game" }


## Disconnects from the game; the service calls this when the protocol is cleared.
func detach() -> void:
	pass
