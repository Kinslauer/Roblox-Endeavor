# Pistol arm poses by inverse kinematics

The Conduit body joint offsets (dumped from a real server) and the HeldWeapons.HandgunGrip matrix in Python.
`python3 poses.py` prints the arm angles used in ../anims.py (Pistol_Ready, Aim_Pistol, Reload_Pistol, Cover_Idle,
Intro_Draw, Intro_Rack) and draws poses.png. `grid.py` searched the low ready for the straightest wrist.
Note: solve.py also holds an old numerical solver (unused); ik.py is the analytic one.
