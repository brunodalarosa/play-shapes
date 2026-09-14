extends SceneTree

func _initialize() -> void:
	var expression := CharacterExpression.new(11011)
	var seen: Dictionary = {}
	for unused: int in 2400:
		expression.advance(0.05)
		seen[expression.current_tag()] = true
	if not _check(seen.has(&"blink"), "Neutral face blinks at life-like intervals"):
		return
	if not _check(seen.has(&"delighted") or seen.has(&"cheeky"), "Happy micro-expressions appear"):
		return
	if not _check(seen.has(&"sad") or seen.has(&"worried"), "Rare sad micro-expressions appear"):
		return
	print("Character expression checks passed: %s" % [seen.keys()])
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
