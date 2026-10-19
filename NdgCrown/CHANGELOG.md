# Changelog

## 1.1.0
- New: extension support. Extension addons such as NdgUrge (the "Stop Zerging" warning) use NdgCrown's leader tracking and add their settings as a submenu to NdgCrown's settings panel.
- `/ndgcrown` also lists the installed extensions and whether they are active.

## 1.0.1
- The author is now shown as @Nidhoeggr in the add-on list and the settings panel.
- Updated for the current game version (API 101051, next PTS 101052), so the addon is no longer listed as "Out of date".

## 0.5.0
- Fixed: beams were often missing or misplaced. The beam window had its own 3D render space, which the game shifts whenever its floating world origin moves (frequently in Cyrodiil), offsetting every beam.
- Fixed: the beam was centered on the target's feet, so its brighter half was underground. It now stands on the ground.
- Beams and rings update every frame (smoother while moving).
- New: range rings on the ground around the leader and each mark, colored by whether you are in range; optional ring around yourself.
- New: "Beam visible through terrain" option.
- New: `/ndgcrown beamprobe` diagnostic.
