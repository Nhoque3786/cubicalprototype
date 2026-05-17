# Cubical Prototype - TODO List

## Bugs & Fixes
- [x] **Fix Hyprgrid rotation snapping:** Cubic still needs to snap correctly onto blocks during/after world rotation. (It works but i might have to make cubic be inside the level to get a better effect)
- [x] **Fix Hyprgrid Z-platform snapping:** Jumping to another platform on another Z axis now teleports/snaps Cubic to the projected block.

- [ ] **Player Visuals:** Improve animations; trigger fall "stretch" only above a velocity threshold.
- [ ] Debug sprite frame border overflow issue (borders exceed bounds despite pixel-perfect sprite sheet)


## Features to Implement

### Mechanics
- [ ] Implement **Climbing** state (Raycasts for wall detection).
- [ ] Implement **Grabbing** state (Picking up small things).
- [x] Implement **Coyote Time** for more forgiving platforming.

### Systems
- [ ] **Death & Respawn:** Logic for when Cubic falls below a certain Y level. (also add "safe?" var for blocks)
- [ ] **Level Transition:** A simple "door" thing that loads a new scene.
- [x] **Smooth Camera:** Implement a Lerp-based follow script for the Camera.
- [ ] **Camera Collision:** Prevent the Camera from clipping/going inside some blocks. (add a "clippable" var, this might be fun)

### Visuals & Polish
- [ ] Create more block varieties (Slopes, transparent glass, etc.).
- [ ] Configure a fast way to create new environments (with day/night cycles, backgrounds, shaders, gravity...)
- [ ] Add tiny dust particles when landing. (maybe i need to do those on a new sprite sheet)
- [ ] Add a gridmap template (or maybe use testing grounds's blocks as template idk)
- [ ] Actually make stretch_hard