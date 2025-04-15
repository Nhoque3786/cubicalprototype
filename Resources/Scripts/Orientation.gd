class_name Orientation

enum Facing { South, West, North, East }

func get_facing(angle) -> Facing:
	return angle / (PI / 2) % 4
