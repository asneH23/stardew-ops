import re

# 1. Lägg till en kamera på Spelaren i Main.tscn
with open("godot/scenes/Main.tscn", "r") as f:
    tscn = f.read()

# Hitta Player-noden och lägg till Camera2D och en Crops-container
if 'type="Camera2D"' not in tscn:
    tscn = tscn.replace(
        '[node name="ColorRect" type="ColorRect" parent="Player"]',
        '[node name="Camera2D" type="Camera2D" parent="Player"]\nzoom = Vector2(1.5, 1.5)\n\n[node name="ColorRect" type="ColorRect" parent="Player"]'
    )
    
    # Infoga en container för alla grödor (Crops) bakom spelaren
    tscn = tscn.replace(
        '[node name="Player" type="CharacterBody2D" parent="."]',
        '[node name="Crops" type="Node2D" parent="."]\n\n[node name="Player" type="CharacterBody2D" parent="."]'
    )

with open("godot/scenes/Main.tscn", "w") as f:
    f.write(tscn)


# 2. Uppdatera GameManager.gd för att plantera
with open("godot/scripts/GameManager.gd", "r") as f:
    gm = f.read()

if "func plant_crop" not in gm:
    # Lägg till referenser
    gm = gm.replace(
        '@onready var status_label: Label = $StatusLabel',
        '@onready var status_label: Label = $StatusLabel\n@onready var player: CharacterBody2D = $"../Player"\n@onready var crops_node: Node2D = $"../Crops"'
    )
    
    # Anropa plant_crop
    gm = gm.replace(
        'spawn_floating_xp(gained)',
        'spawn_floating_xp(gained)\n\t\tplant_crop(total_xp)'
    )
    
    # Lägg till plant_crop-funktionen
    plant_func = """
func plant_crop(total_xp: int) -> void:
	var emojis = ["🌲", "🎃", "🌻", "🍎", "🌽", "🍄"]
	# Välj emoji baserat på total XP (lite variation)
	var emoji = emojis[(total_xp / 50) % emojis.size()]
	
	var crop = Label.new()
	crop.text = emoji
	crop.add_theme_font_size_override("font_size", 40)
	# Plantera den exakt där spelaren står (justera lite för mitten)
	crop.position = player.global_position - Vector2(20, 20)
	
	# Lägg till i världen
	crops_node.add_child(crop)
	
	# Cool pop-in animation
	crop.scale = Vector2.ZERO
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(crop, "scale", Vector2(1, 1), 1.0)
"""
    gm += plant_func

with open("godot/scripts/GameManager.gd", "w") as f:
    f.write(gm)
