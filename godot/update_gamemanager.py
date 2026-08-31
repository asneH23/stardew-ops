import re

with open("godot/scripts/GameManager.gd", "r") as f:
    gm = f.read()

# Byt ut plant_crop
new_plant_crop = """
func plant_crop(total_xp: int) -> void:
	# Ladda den riktiga grödo-bilden istället för emoji!
	var crop = Sprite2D.new()
	crop.texture = preload("res://assets/Objects/Spring Crops.png")
	crop.region_enabled = true
	
	# Skär ut en 16x16 gröda baserat på XP (flyttar rutan längs X-axeln)
	var crop_index = (total_xp / 50) % 5
	crop.region_rect = Rect2(crop_index * 16, 0, 16, 16)
	crop.scale = Vector2(2, 2)
	
	# Plantera vid spelarens fötter
	crop.position = player.global_position + Vector2(0, 10)
	crops_node.add_child(crop)
	
	# Pop-in animation
	crop.scale = Vector2.ZERO
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(crop, "scale", Vector2(2, 2), 1.0)

# Rita ut en riktig gräsmatta av pixel-grafik när spelet startar!
func draw_pixel_grass() -> void:
	var grass_texture = preload("res://assets/Tileset/Tileset Spring.png")
	for x in range(-20, 20):
		for y in range(-20, 20):
			var tile = Sprite2D.new()
			tile.texture = grass_texture
			tile.region_enabled = true
			tile.region_rect = Rect2(0, 0, 16, 16) # Högst upp till vänster är oftast standardgräs
			tile.scale = Vector2(2, 2)
			tile.position = Vector2(x * 32, y * 32)
			tile.z_index = -10 # Längst bak
			$WorldBackground.add_child(tile)
"""

# Hitta gamla plant_crop
old_plant_crop_regex = r'func plant_crop\(total_xp: int\) -> void:.*?(?=\n\n|\Z)'
gm = re.sub(r'func plant_crop\(total_xp: int\) -> void:.*?tween_property\(crop, "scale", Vector2\(1, 1\), 1\.0\)', new_plant_crop.strip(), gm, flags=re.DOTALL)

# Lägg till anrop till draw_pixel_grass() i _ready()
gm = gm.replace(
    'api_client.state_updated.connect(_on_state_updated)',
    'draw_pixel_grass()\n\tapi_client.state_updated.connect(_on_state_updated)'
)

with open("godot/scripts/GameManager.gd", "w") as f:
    f.write(gm)
