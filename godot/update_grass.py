import re

with open("godot/scenes/Main.tscn", "r") as f:
    tscn = f.read()

# Lägg till en stor gräsmatta-ColorRect i bakgrunden
grass_node = """[node name="WorldBackground" type="ColorRect" parent="."]
offset_left = -1000.0
offset_top = -1000.0
offset_right = 2000.0
offset_bottom = 2000.0
color = Color(0.36, 0.65, 0.35, 1)

[node name="FarmMap" type="TileMapLayer" parent="."]"""

tscn = tscn.replace('[node name="FarmMap" type="TileMapLayer" parent="."]', grass_node)

with open("godot/scenes/Main.tscn", "w") as f:
    f.write(tscn)
