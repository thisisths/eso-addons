# Changelog

## 0.5.0
- Fixed: beams were often missing or misplaced. The beam window had its own 3D render space, which the game shifts whenever its floating world origin moves (frequently in Cyrodiil), offsetting every beam.
- Fixed: the beam was centered on the target's feet, so its brighter half was underground. It now stands on the ground.
- Beams and rings update every frame (smoother while moving).
- New: range rings on the ground around the leader and each mark, colored by whether you are in range; optional ring around yourself.
- New: "Beam visible through terrain" option.
- New: `/ndgcrown beamprobe` diagnostic.
