# Hyprcore: the "heart" and "brains" of this game!

Hyprcore is the central system responsible for managing the "2.5D" perspective of Cubical. It enables a 2D gameplay experience within a 3D environment by handling world rotation and ensuring the player remains aligned with the active plane of movement.

## Core Features

### 1. HyprCube (World Rotation)
Hyprcore manages the 90-degree rotations that define the game's perspective shifts.
- **Input Driven:** Listens for `rotate_right` and `rotate_left` actions.
- **Tweened Animation:** Uses configurable durations and ease types for smooth transitions.
- **Pause Management:** Automatically pauses the game tree during rotation to prevent physics glitches.
- **Player Anchoring:** Stores Cubic's local position inside the rotating `Level`, then restores it after rotation so Cubic stays on the block they were standing on.

### 2. Hyprgrid (Grid Snapping)
To prevent players from falling off or being misaligned after a "reality shift," Hyprcore includes a snapping system.
- **View-Depth Alignment:** Snaps along the camera's depth axis instead of assuming world `Z` is always the active depth lane.
- **GridMap Projection:** Uses occupied `GridMap` cells to find valid blocks under Cubic's 2D screen projection.
- **Depth Priority:** Supports `NEAREST`, `FRONTMOST`, and `BEHINDMOST` selection when multiple blocks overlap in the current 2D view.
- **Raycast Fallback:** Keeps the older depth raycast behavior as a backup when no projected `GridMap` cell is found.

### 3. HyprOrient (Orientation Flagging)
The system keeps track of the current world orientation using a 4-state enum:
- `NORTH` (Default starting side)
- `EAST`
- `SOUTH`
- `WEST`

## Configuration

| Setting | Description |
| :--- | :--- |
| `Level Node` | The 3D node that will be rotated (typically containing your Level and GridMaps). |
| `Rotation Duration` | How long the perspective shift takes (default: 0.4s). |
| `Transition Type` | The tweening curve (default: `TRANS_CUBIC`). |
| `Grid Map` | Optional direct reference to the active `GridMap`; Hyprcore can also find one under `Level Node`. |
| `Max Distance` | How far the snapping system looks for a valid plane. |
| `Projected Snap Tolerance` | How close Cubic's screen-space horizontal position must be to a projected cell center. |
| `Max Floor Snap Height` | Maximum height above a cell where Cubic can still snap to that cell's depth lane. |
| `Grounded Depth Priority` | Which depth lane to choose while Cubic is on the floor. Defaults to `NEAREST`. |
| `Airborne Depth Priority` | Which depth lane to choose while Cubic is jumping/falling. Defaults to `BEHINDMOST`. |

## Usage
To use Hyprcore in a new level, it is recommended to start from the `leveltemplate.tscn`. Ensure that your level geometry is parented to a node named `Level` (or assigned via the Inspector) so that Hyprcore can rotate it correctly.
For GridMap snapping, place the active `GridMap` inside the `Level` node or assign it directly in the Inspector.

```gdscript
# Example: Getting the current side from another script
if hyprcore.current_side == Hyprcore.Orientation.NORTH:
    print("Facing North")
```
