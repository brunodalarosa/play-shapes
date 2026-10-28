@tool
class_name FlappyRaceCourseTuning
extends Resource
## How Flappy Race generates its course, in metres and seconds. Difficulty follows course
## progress, from 0 at the start line to 1 at the finish line, never time.

## Duration of a run with no hits and no pickups; sets the course length with the forward speed.
## Default: 120.
@export_range(30.0, 600.0, 1.0, "suffix:s") var perfect_run_seconds: float = 120.0
## Travel time from the start line to the first obstacle. Default: 3.
@export_range(0.0, 20.0, 0.5, "suffix:s") var start_clear_seconds: float = 3.0
## Travel time from the last obstacle to the finish line. Default: 3.
@export_range(0.0, 20.0, 0.5, "suffix:s") var finish_clear_seconds: float = 3.0
## Height from the ground to the top of the view the course is made for. Default: 34.
@export_range(10.0, 100.0, 0.5, "suffix:m") var view_height: float = 34.0
## Height of every Cubio's body centre at GO. Default: 17.
@export_range(1.0, 100.0, 0.5, "suffix:m") var start_height: float = 17.0
## Width of every obstacle pair along the course. Default: 6.
@export_range(1.0, 20.0, 0.25, "suffix:m") var obstacle_width: float = 6.0
## Lowest a gap reaches, as a share of the view height. Default: 0.2.
@export_range(0.0, 1.0, 0.01) var gap_lowest_share: float = 0.2
## Highest a gap reaches, as a share of the view height. Default: 0.8.
@export_range(0.0, 1.0, 0.01) var gap_highest_share: float = 0.8
## Distance from a respawn spot to the front face of its obstacle. Default: 2.
@export_range(0.0, 10.0, 0.25, "suffix:m") var respawn_distance: float = 2.0

@export_group("Difficulty over progress")
## Distance from one obstacle's front face to the next, metres, before its random spread.
## Default: 16.1 to 12.65.
@export var obstacle_spacing: Curve
## How far each spacing may stray from its curve, either way, as a share, drawn from the seed.
## Default: 0.25.
@export_range(0.0, 0.9, 0.05) var spacing_variation: float = 0.25
## No spacing is shorter than this, whatever the curve and spread say. Default: 11.
@export_range(1.0, 60.0, 0.25, "suffix:m") var shortest_spacing: float = 11.0
## No spacing is longer than this. Default: 20.
@export_range(1.0, 60.0, 0.25, "suffix:m") var longest_spacing: float = 20.0
## Gap height, metres. Default: 8.4 to 7.
@export var gap_height: Curve
## Largest change of gap centre from the previous obstacle, metres. Default: 4 to 9.
@export var largest_gap_change: Curve
## Chance that an obstacle's gap holds a speed pickup, 0 to 1. Default: 0.1 to 0.25.
@export var pickup_chance: Curve

@export_group("Speed pickups")
## Side of a pickup's square trigger. Default: 1.6.
@export_range(0.2, 4.0, 0.1, "suffix:m") var pickup_size: float = 1.6
## Distance from the pickup to the top or bottom edge of its gap. Default: 0.4.
@export_range(0.0, 4.0, 0.1, "suffix:m") var pickup_edge_distance: float = 0.4

@export_group("Ground obstacle looks")
## Relative chance of a stalagmite. Default: 0.6.
@export_range(0.0, 1.0, 0.05) var stalagmite_weight: float = 0.6
## Relative chance of a tiered rock stack. Default: 0.25.
@export_range(0.0, 1.0, 0.05) var rock_stack_weight: float = 0.25
## Relative chance of a crystal cluster. Default: 0.15.
@export_range(0.0, 1.0, 0.05) var crystal_cluster_weight: float = 0.15


## The spacing after an obstacle at [param progress], with [param roll] from -1 to 1 setting its
## share of the spread.
func spacing_at(progress: float, roll: float) -> float:
	var spread := obstacle_spacing.sample(progress) * (1.0 + roll * spacing_variation)
	return clampf(spread, shortest_spacing, longest_spacing)


## The shortest spacing the curve, its spread and the limits allow.
func shortest_possible_spacing() -> float:
	var lowest := curve_range(obstacle_spacing).x * (1.0 - spacing_variation)
	return clampf(lowest, shortest_spacing, longest_spacing)


## The lowest and highest value of [param curve] over progress, sampled in hundredths.
static func curve_range(curve: Curve) -> Vector2:
	var low := INF
	var high := -INF
	for step: int in 101:
		var value := curve.sample(step / 100.0)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var curves := [obstacle_spacing, gap_height, largest_gap_change, pickup_chance]
	if curves.has(null):
		errors.append("Flappy Race course: every difficulty curve must be set.")
		return errors

	if shortest_spacing > longest_spacing:
		errors.append("Flappy Race course: the shortest spacing cannot exceed the longest.")
	if shortest_possible_spacing() <= obstacle_width:
		errors.append("Flappy Race course: obstacles must be spaced wider than they are.")
	if curve_range(gap_height).x <= 0.0 or curve_range(largest_gap_change).x < 0.0:
		errors.append("Flappy Race course: gaps and gap changes cannot be negative.")
	var chance := curve_range(pickup_chance)
	if chance.x < 0.0 or chance.y > 1.0:
		errors.append("Flappy Race course: the pickup chance must stay between 0 and 1.")
	var gap_room := view_height * (gap_highest_share - gap_lowest_share)
	if gap_room < curve_range(gap_height).y:
		errors.append("Flappy Race course: the gap range must fit the largest gap.")
	if stalagmite_weight + rock_stack_weight + crystal_cluster_weight <= 0.0:
		errors.append("Flappy Race course: at least one ground obstacle look needs a weight.")
	return errors
