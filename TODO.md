## First things first...
- [ ] Remake the camera inside the player.gd
- [ ] **Instead of the camera rotating, the map itself should rotate**
- [ ] Add things on game.gd that could make the development easier
- [ ] Fix orientation.gd
- [ ] Add a script for world params

## Testing
- [ ] Add a better testing map that test player movement too


# Player
- [ ] Add 2D on 3D player movement
- [ ] Make a "Dynamic Animation" System using sprite sheets

- [ ] Add Jumping
- [ ] Add Falling damage & respawn
- [ ] Add climbable jumping (maybe)
- [ ] Prototype "Hyperjump" (Basically a dash)

## Mechanics
- [ ] Add Bits and Bytes (colectables) for testing
- [ ] Add Climbables

## Camera/World Rotation (FEZ-like)
- [x] Prototype: rotate world around player using hyprcam.gd (Q/E)
- [ ] Refactor hyprcam: pivot modes (MAP_CENTER/PLAYER/CUSTOM)
- [ ] Add snap rotation (e.g., 90°) with tween and input lock during animation
- [ ] Add camera_reset action to realign to 0° or nearest step
- [ ] Allow excluding nodes from rotation (e.g., WorldEnvironment/UI3D)
- [ ] Gamepad right stick integration (analog rotation with deadzone/sensitivity)

## Level workflow
- [ ] Create map template scene: Resources/Levels/Templates/MapTemplate.tscn (Level/Tiles/Props/Interactables/Colliders/Environment)
- [ ] Simple MapLoader.gd to swap maps at runtime, preserving player
- [ ] Convention check: keep Level (map root) and Cubic (player) names consistent or make autoload configurable

## Engine
- [ ] Find a way to make .xm .it .mod files work as dynamic music inside it as nodes
- [ ] Make a "Block" (or tilemap) Editor for the maps using or making a new program that does that