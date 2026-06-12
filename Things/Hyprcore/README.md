# Hyprcore: The Heart and brains of Cubical!

Hyprcore is the central system responsible for managing the "2.5D" perspective of Cubical. It enables a 2D gameplay experience within a 3D environment by handling world rotation, grid snapping, and safe spawn tracking.

> **Architecture:** Hyprcore is split across three scripts.
> - **`Hyprcore.gd`** (`class_name Hyprcore`) — the node you attach to your world root. Owns shared state, tuning, orientation flags, the public API, and shared helpers; delegates the heavy lifting to the two modules below.
> - **`Hyprcube.gd`** (`class_name Hyprcube`) — stateless world-rotation module. Drives the tweened 90-degree spins via `Hyprcube.rotate_world(core)`.
> - **`Hyprsnap.gd`** (`class_name Hyprsnap`) — stateless grid/depth snapping module. Holds the heavy depth-search math via `Hyprsnap.snap_to_grid(core, body, ...)`.
>
> Both modules operate on a `Hyprcore` instance passed to them, so all public calls still go through the `Hyprcore` node (e.g. `hyprcore.snap_to_grid(...)`).

## Core Features

### 1. HyprCube (World Rotation)
Hyprcore manages the 90-degree rotations that define the game's perspective shifts.
- **Input Driven:** Listens for `rotate_right` and `rotate_left` actions.
- **Tweened Animation:** Uses configurable durations, transition types, and ease types for smooth transitions.
- **Pause Management:** Automatically pauses the game tree during rotation to prevent physics glitches and ensures the rotation finishes consistently.
- **Player Anchoring:** Stores Cubic's local position relative to the `Level`, then restores it after rotation so Cubic stays on the block they were standing on.

### 2. Hyprgrid (Grid Snapping)
To prevent players from falling off or being misaligned after a "reality shift," Hyprcore includes a dual-layer snapping system.
- **View-Depth Alignment:** Snaps along the camera's depth axis instead of assuming world `Z` is always the active depth lane.
- **Infinite Depth Snapping:** Searches deep into the camera's projection to allow Cubic to stand on any visible platform.
- **Smooth Depth Snapping:** Uses frame-independent exponential smoothing to glide Cubic between depth layers, preventing "popping" visuals.
- **Depth Priority:** Supports `NEAREST`, `FRONTMOST`, and `BEHINDMOST` selection when multiple blocks overlap in the current 2D view.

### 3. HyprOrient (Orientation Flagging)
The system keeps track of the current world orientation using a 4-state enum (`WorldSide`):
- `NORTH` (Default starting side)
- `EAST`
- `SOUTH`
- `WEST`



## Signals

| Signal | Description |
| :--- | :--- |
| `rotation_started` | Emitted when a world rotation begins. |
| `rotation_finished` | Emitted when the rotation animation and snapping are complete. |

## Configuration

| Setting | Description |
| :--- | :--- |
| `Level Node` | The 3D node that will be rotated (typically containing your Level and GridMaps). |
| `Rotation Duration` | How long the perspective shift takes (default: 0.4s). |
| `Transition Type` | The tweening curve (default: `TRANS_CUBIC`). |
| `Ease Type` | The tweening ease (default: `EASE_IN_OUT`). |
| `Grid Map` | Optional direct reference to the active `GridMap`; Hyprcore can also find one under `Level Node`. |
| `Max Distance` | How far the snapping system looks for a valid plane. |
| `Collision Mask` | Which physics layers to check during raycast snapping. |
| `Vertical Offsets` | Array of Y-offsets for the raycast snapping system to ensure detection across the player's height. |
| `Projected Snap Tolerance` | How close Cubic's screen-space horizontal position must be to a projected cell center. |
| `Max Floor Snap Height` | Maximum height above a cell where Cubic can still snap to that cell's depth lane. |
| `Snap Speed` | Speed of the depth interpolation. Set to `0` for instant snapping (default: 24.0). |
| `Search Depth Radius` | Number of cells to search along the depth axis for alignment (default: 64). |
| `Grounded Depth Priority` | Which depth lane to choose while Cubic is on the floor. Defaults to `NEAREST`. |
| `Airborne Depth Priority` | Which depth lane to choose while Cubic is jumping/falling. Defaults to `BEHINDMOST`. |

## Public API

| Method | Returns | Description |
| :--- | :--- | :--- |
| `snap_to_grid(body, force_instant)` | `void` | Snaps a `CharacterBody3D` to the correct depth lane. `force_instant` (bool) toggles interpolation. |
| `get_grid_map()` | `GridMap` | Returns the active GridMap, searching under `Level Node` if needed. |
| `get_depth_direction()` | `Vector3` | Returns the current camera depth axis (normalized, Y-flattened). |
| `get_screen_horizontal_direction()` | `Vector3` | Returns the current camera horizontal axis (normalized, Y-flattened). |

## Usage

### Setup
1. Use `leveltemplate.tscn` as a base for new levels.
2. Ensure level geometry is parented to a node named `Level`.
3. Assign the `Level` node and `GridMap` in the Hyprcore inspector if they are not found automatically.

### Code Examples

**Checking the current side:**
```gdscript
var hyprcore = get_tree().get_first_node_in_group("hyprcore")
if hyprcore.current_side == Hyprcore.WorldSide.NORTH:
    print("The world is facing North.")
```

**Reacting to rotation signals:**
```gdscript
func _ready():
    var hyprcore = get_tree().get_first_node_in_group("hyprcore")
    hyprcore.rotation_started.connect(_on_rotation_started)
    hyprcore.rotation_finished.connect(_on_rotation_finished)

func _on_rotation_started():
    # Disable player input or hide UI
    pass

func _on_rotation_finished():
    # Re-enable systems
    pass
```


## Internal Notes
- **Smooth Snapping:** The system uses the formula `1.0 - exp(-snap_speed * delta)` for snapping. This ensures the "feel" of the movement remains consistent regardless of the game's framerate.
- **Process Mode:** Hyprcore is set to `PROCESS_MODE_ALWAYS` so it can handle world rotation even while the game tree is paused.
- **Hierarchy:** The player (Cubic) should be a child of the `Level` node, so it rotates together with the world automatically. Hyprcore also includes a fallback that manually converts positions if Cubic is ever placed outside the `Level` node.
- **`get_grid_map()` limitation:** Currently finds only the first GridMap named `"GridMap"` under `Level Node`. If you add multiple GridMaps in the future, the safe spawn probe may need to switch to a physics raycast approach instead.

---
