# Orientation controls. Only for some technical shit. Perhaps weird camera effects
class_name Orientation

enum Facing { South, West, North, East }

func get_facing(angle) -> Facing:
	# Normalizing the angle between 0 and 2*PI
	var normalized_angle = fposmod(angle, TAU)
	# Converts to facing direction (each spans PI/2 radians)
	# 0 rad (0º) = south, PI/2 (90º) = west, PI (180º) = north, 3*PI/2 (270º) = east
	var facing_index = int(round(normalized_angle / (PI / 2))) % 4
	return facing_index as Facing

