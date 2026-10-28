class_name BootSteps
extends RefCounted
## Every boot step, in the order they run. Presets is the one Essential step: it runs on every
## launch. The others are Optional and run only when an entry lists them or a listed step needs
## them, so a scene started on its own loads nothing it does not use.

const PRESETS := &"presets"
## The player registry: identities, seats and reconnect tokens.
const REGISTRY := &"registry"
## The minigame catalog, with every minigame definition.
const CATALOG := &"catalog"
## The local network file, local/network.json or PLAY_SHAPES_NETWORK_CONFIG.
const NETWORK_CONFIG := &"network_config"
## The HTTPS certificate the network file names, when it turns TLS on.
const CERTIFICATE := &"certificate"
## The HTTP and WebSocket servers on the local network, as the network file sets them.
const SERVERS := &"servers"
## The HTTP and WebSocket servers bound to this PC only, without TLS or the network file.
const SERVERS_THIS_PC := &"servers_this_pc"
## Opens the Playground lobby.
const LOBBY := &"lobby"

const ORDER: Array[StringName] = [
	PRESETS,
	REGISTRY,
	CATALOG,
	NETWORK_CONFIG,
	CERTIFICATE,
	SERVERS,
	SERVERS_THIS_PC,
	LOBBY,
]
const ESSENTIAL: Array[StringName] = [PRESETS]
## The steps that start the servers, forgotten when they stop so a restart runs them again.
const NETWORK: Array[StringName] = [NETWORK_CONFIG, CERTIFICATE, SERVERS, SERVERS_THIS_PC]
const NEEDS: Dictionary[StringName, Array] = {
	SERVERS: [REGISTRY, NETWORK_CONFIG, CERTIFICATE],
	SERVERS_THIS_PC: [REGISTRY],
	LOBBY: [SERVERS],
}


## The Essential steps, [param requested] and everything they need, in run order.
static func with_needs(requested: Array[StringName]) -> Array[StringName]:
	var wanted: Dictionary[StringName, bool] = { }
	var pending: Array[StringName] = ESSENTIAL + requested
	while not pending.is_empty():
		var step: StringName = pending.pop_back()
		if wanted.has(step):
			continue
		wanted[step] = true
		for need: StringName in NEEDS.get(step, []):
			pending.append(need)
	var result: Array[StringName] = []
	for step: StringName in ORDER:
		if wanted.has(step):
			result.append(step)
	return result


## Why [param requested] cannot run, or an empty string.
static func request_error(requested: Array[StringName]) -> String:
	for step: StringName in requested:
		if step not in ORDER:
			return "Unknown boot step: %s" % step
	if SERVERS in with_needs(requested) and SERVERS_THIS_PC in requested:
		return "Ask for servers or servers_this_pc, not both"
	return ""
