# Cubical Prototype - TODO List

## Bugs & Fixes
- [] **Fix Hyprgrid rotation snapping:** Cubic still needs to snap correctly onto blocks during/after world rotation. (It works but i might have to make cubic be inside the level to get a better effect)
- [x] **Fix Hyprgrid Z-platform snapping:** Jumping to another platform on another Z axis now teleports/snaps Cubic to the projected block.

- [x] **Player Visuals:** Fix up the animations, they are not going back to default (idle) after playing and not inverting horizontally based on the movement.

## Features to Implement

### Mechanics
- [ ] Implement **Climbing** state (Raycasts for wall detection).
- [ ] Implement **Grabbing** state (Picking up small cubes/blocks).
- [ ] Implement **Coyote Time** for more forgiving platforming.

### Systems
- [ ] **Death & Respawn:** Logic for when Cubic falls below a certain Y level.
- [ ] **Level Transition:** A simple "door" block that loads a new scene.
- [ ] **Smooth Camera:** Implement a Lerp-based follow script for the Camera.
- [ ] **Camera Collision:** Prevent the Camera from clipping/going inside blocks.

### Visuals & Polish
- [ ] Create more block varieties (Slopes, transparent glass, etc.).
- [ ] Configure a "Night/Day" cycle or a dynamic WorldEnvironment.
- [ ] Add "Impact" particles when landing.
