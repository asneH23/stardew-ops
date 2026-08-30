import re

with open("godot/scenes/Main.tscn", "r") as f:
    content = f.read()

if "res://scripts/Player.gd" not in content:
    content = content.replace(
        '[ext_resource type="Script" path="res://scripts/ApiClient.gd" id="2_apiclient"]',
        '[ext_resource type="Script" path="res://scripts/ApiClient.gd" id="2_apiclient"]\n[ext_resource type="Script" path="res://scripts/Player.gd" id="3_player"]'
    )

player_node = """[node name="WorldBackground" type="ColorRect" parent="."]
offset_right = 1200.0
offset_bottom = 800.0
color = Color(0.3, 0.55, 0.25, 1.0)

[node name="Instruction" type="Label" parent="."]
offset_left = 350.0
offset_top = 20.0
theme_override_font_sizes/font_size = 20
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 4
text = "Tryck på 'TAB' för att öppna/stänga MLOps Quest Board"

[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(600, 400)
script = ExtResource("3_player")

[node name="ColorRect" type="ColorRect" parent="Player"]
offset_left = -16.0
offset_top = -16.0
offset_right = 16.0
offset_bottom = 16.0
color = Color(0.2, 0.4, 0.8, 1)

[node name="Label" type="Label" parent="Player/ColorRect"]
offset_top = -2.0
offset_right = 32.0
offset_bottom = 30.0
theme_override_font_sizes/font_size = 20
text = "👨‍🌾"
horizontal_alignment = 1

[node name="UI" type="CanvasLayer" parent="."]"""

content = re.sub(r'\[node name="UI" type="CanvasLayer" parent="\."\]', player_node, content)

content = content.replace(
    '[node name="UI" type="CanvasLayer" parent="."]',
    '[node name="UI" type="CanvasLayer" parent="."]\nvisible = false'
)
content = content.replace(
    'color = Color(0.06, 0.1, 0.06, 1)',
    'color = Color(0.06, 0.1, 0.06, 0.95)'
)

with open("godot/scenes/Main.tscn", "w") as f:
    f.write(content)
