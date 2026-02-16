# Codebase Analysis & Suggestions

## Summary
The `Cubical` repository is a Godot-based prototype for a FEZ-like game (2D gameplay in a 3D world). The codebase is clean and organized, with a clear separation of concerns in `Resources/Scripts`.

## Suggestions for Next Steps

### 1. Implement Climbing Logic
**File:** `Resources/Scripts/Player/Player.gd`
- Currently has a `# TODO: Implement climbing logic` placeholder.
- **Action:** Implement raycast or area detection for climbable surfaces. When detected, switch the player state to `State.CLIMBING` and handle vertical movement.

### 2. Enhance Z-Snapping
**File:** `Resources/Scripts/core/hyprground.gd`
- Handles keeping the player on the Z-axis.
- Currently assumes blocks are simple cubes and uses basic logic.
- **Action:** Improve robustness for slopes, different block sizes, or complex geometry.

### 3. Refactor Player Movement
**File:** `Resources/Scripts/Player/Player.gd`
- The `_physics_process` method handles input and state transitions directly.
- **Action:** Refactor into a dedicated State Machine (using separate classes or nodes for states) to make the code cleaner and easier to extend, especially for new mechanics like climbing or hyperjumps.

### 4. Add Camera Controls
**File:** `Resources/Scripts/Player/camera.gd`
- Has a `# TODO: add camera controls`.
- **Action:** Implement look-around functionality using the right stick or mouse to improve exploration.

### 5. Visual Polish - Squash & Stretch
**File:** `Resources/Scripts/Player/PlayerAnimator.gd`
- Has TODOs for adding squash and stretch effects to jump and landing animations.
- **Action:** Implement procedural animation scaling on the `AnimatedSprite3D` to add "juice" and better game feel.

### 6. Fix World Rotation Pausing
**File:** `Resources/Scripts/core/hyprcube.gd`
- Pauses the entire scene tree during rotation.
- **Action:** Consider pausing only specific nodes or disabling player input/physics instead of pausing the whole tree if you want background elements to remain active.

### 7. Input Verification
**File:** `project.godot`
- **Action:** Ensure the input map matches your intended controls, especially for controller support.

### 8. Testing
**File:** `Resources/Levels/test/PlayerTest.tscn`
- **Action:** Create specific test scenes for mechanics like climbing or complex platforming to iterate faster without playing the whole level.
