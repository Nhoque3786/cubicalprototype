# Cubic: The Player

Cubic is the player character of Cubical — a yellowish cuboid protagonist with a modular controller built on Godot's Composition pattern. Instead of one giant script doing everything, each responsibility lives in its own focused component.

## Core Components

### 1. `player.gd` (Central Coordinator)
The main script attached to the `CharacterBody3D`. Acts as the hub that owns all configuration and delegates work to its components.
- Holds all `@export` properties (speed, gravity, jump power, death thresholds) configurable from the Inspector.
- Tracks the player's overall `State` enum: `IDLE`, `MOVING`, `AIR`, `ROTATING`, `CLIMBING`, `GRABBING`, `DEAD`.
- Automatically finds or creates component nodes at startup — no manual scene wiring required.
- Emits `died` and `respawned` signals so external systems (UI, audio, etc.) can react without touching this script.

### 2. `PlayerMovement.gd` (Movement & Jump)
Handles all horizontal movement, gravity, and jump logic.
- **Horizontal Movement:** Applies acceleration and friction relative to the current camera orientation, not a fixed world axis.
- **Gravity:** Subtracts gravity from `velocity.y` each physics frame.
- **Jumping:** Supports a configurable `jump_delay` buffer before velocity launches. `did_jump` fires on the exact frame the velocity is set, so animations are always in sync.
- **Jump Buffering:** Remembers jump inputs pressed shortly before landing (up to `jump_buffer_time`), firing the jump instantly upon touching the floor.
- **Coyote Time:** Gives a short grace window to jump after walking off an edge.

### 3. `PlayerRIP.gd` (Death & Respawn)
Handles fall detection, death checks, and respawning.
- **Safe Position Tracking:** After `safe_ground_time` seconds on solid ground, saves `global_position` as the last safe respawn point.
- **Death Check:** Triggers death when `global_position.y` drops below `death_y_threshold`.
- **Death Sequence:** Plays the `death_fall` animation. Includes a 1.5s safety timeout to ensure respawning even if the animation signal is interrupted.
- **Respawn:** Teleports Cubic to `_last_safe_position`. Does not call `snap_to_grid` immediately — physics state is stale right after a teleport, so the normal `_physics_process` snap corrects it on the next frame.

### 4. `PlayerGhost.gd` (Silhouette)
Ensures Cubic is never lost behind world geometry.
- **Occlusion Sensing:** Performs a real-time raycast from the camera to Cubic.
- **Visual Silhouette:** If Cubic is occluded by physics layer 1, draws a "ghost" sprite with `no_depth_test` that mirrors Cubic's current animation frame and pose.

### 5. `PlayerAnimator.gd` (Visuals & Animations)
Manages all `AnimatedSprite3D` state transitions.
- Handles walk speed scaling, jump squish, hard/soft landing, stretch on fast fall, and direction flipping.
- Includes a blink system that randomly switches between base and `_blink` animation variants.

## Signals

| Signal | Description |
| :--- | :--- |
| `died` | Emitted when Cubic's death sequence begins. |
| `respawned` | Emitted after Cubic is teleported back to the safe position. |

## Configuration

| Setting | Description |
| :--- | :--- |
| `Hyprcore` | Reference to the Hyprcore node. Auto-found via group if not assigned. |
| `Speed` | Maximum horizontal movement speed (default: 6.0). |
| `Acceleration` | How fast Cubic reaches top speed (default: 60.0). |
| `Friction` | How fast Cubic decelerates when no input is held (default: 50.0). |
| `Jump Power` | Vertical velocity applied on jump (default: 8.0). |
| `Gravity` | Downward force per second (default: 24.0). |
| `Jump Delay` | Seconds between jump input and velocity launch, for squish timing (default: 0.03). |
| `Jump Buffer Time` | Grace period in seconds to buffer a jump input before landing (default: 0.12). |
| `Coyote Time` | Grace period in seconds to jump after leaving the floor (default: 0.15). |
| `Animated Sprite` | Reference to the `AnimatedSprite3D`. Auto-found if not assigned. |
| `Death Y Threshold` | Y position below which Cubic dies (default: -10.0). |
| `Death Freeze Duration` | Seconds to pause after the death animation before respawning (default: 0.6). |
| `Safe Ground Time` | Seconds Cubic must stand still on solid ground before the position is saved (default: 0.3). |
| `Ghost Tint` | The color of the occlusion silhouette (default: `Color(0,0,0,0.55)`). |

## Usage

### Setup
1. Instance `Cubic.tscn` into your level.
2. Assign `Hyprcore` in the Inspector, or ensure a node with the `hyprcore` group exists in the scene tree.
3. Components (`PlayerMovement`, `PlayerRIP`, `PlayerAnimator`, `PlayerGhost`) are created automatically at runtime if not already present as children.

### Code Examples

**Listening to player events:**
```gdscript
func _ready():
    var player = get_tree().get_first_node_in_group("player")
    player.died.connect(_on_player_died)
    player.respawned.connect(_on_player_respawned)

func _on_player_died():
    # Play death sound, show UI, etc.
    pass

func _on_player_respawned():
    # Reset level timer, camera shake, etc.
    pass
```

**Reading player state:**
```gdscript
var player = get_tree().get_first_node_in_group("player") as Player
if player.current_state == Player.State.AIR:
    print("Cubic is airborne!")
```

**Manually triggering death (e.g. from a hazard):**
```gdscript
var player = get_tree().get_first_node_in_group("player") as Player
player.rip.trigger_death()
```

## Internal Notes
- **Component Auto-Creation:** `player.gd` uses `find_child()` first, then `Node.new()` as a fallback. This means you can pre-place components in the scene to override defaults, or leave them out and let the code handle it.
- **X-Ray Visibility:** `PlayerGhost` uses a high `render_priority` and `no_depth_test = true` to ensure the silhouette is always visible "through" walls when occluded.
- **State Machine:** `_update_state()` runs every physics frame before movement. `ROTATING` locks out movement input while Hyprcore is mid-rotation. `DEAD` is set by `PlayerRIP` and blocks all processing.
- **Snap Optimization:** `snap_to_grid` is only called when `velocity.length_squared() > 0.01`, on floor, or on jump — not every frame unconditionally.
- **`did_jump` lifetime:** The flag is `true` for exactly one physics frame — the frame the jump velocity fires. It is consumed by the animator and reset implicitly the next frame.

