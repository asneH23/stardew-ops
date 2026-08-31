import re

with open("godot/scenes/Main.tscn", "r") as f:
    tscn = f.read()

# 1. Byt ut ColorRect och Label mot en riktig Sprite för karaktären
tscn = tscn.replace(
    '[node name="ColorRect" type="ColorRect" parent="Player"]\noffset_left = -16.0\noffset_top = -16.0\noffset_right = 16.0\noffset_bottom = 16.0\ncolor = Color(0.2, 0.4, 0.8, 1)\n\n[node name="Label" type="Label" parent="Player/ColorRect"]\noffset_top = -2.0\noffset_right = 32.0\noffset_bottom = 30.0\ntheme_override_font_sizes/font_size = 20\ntext = "👨‍🌾"\nhorizontal_alignment = 1',
    '[node name="Sprite2D" type="Sprite2D" parent="Player"]\ntexture = ExtResource("4_player_sprite")\nhframes = 4\nscale = Vector2(2, 2)'
)

# Lägg till external resource för spelar-spriten i toppen av filen
if "4_player_sprite" not in tscn:
    tscn = tscn.replace(
        '[ext_resource type="Script" path="res://scripts/Player.gd" id="3_player"]',
        '[ext_resource type="Script" path="res://scripts/Player.gd" id="3_player"]\n[ext_resource type="Texture2D" uid="uid://char_idle" path="res://assets/Character/Idle.png" id="4_player_sprite"]'
    )

# 2. Lägg till en TileMapLayer istället för "WorldBackground"
if "TileMapLayer" not in tscn:
    tscn = tscn.replace(
        '[node name="WorldBackground" type="ColorRect" parent="."]',
        '[node name="FarmMap" type="TileMapLayer" parent="."]'
    )
    # Ta bort ColorRect-raderna
    tscn = re.sub(r'offset_right = 1200\.0\noffset_bottom = 800\.0\ncolor = Color\(0\.3, 0\.55, 0\.25, 1\)', '', tscn)

with open("godot/scenes/Main.tscn", "w") as f:
    f.write(tscn)
