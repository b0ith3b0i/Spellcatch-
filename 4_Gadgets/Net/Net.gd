extends Area3D

func _ready() -> void:
	# Connect the signal that triggers when an Area3D enters this zone
	area_entered.connect(_on_area_entered)

func _on_area_entered(other_area: Area3D) -> void:
	# Check if the target has a specific function to handle being caught
	if other_area.has_method("get_caught"):
		other_area.get_caught()
		play_capture_effects()

func play_capture_effects() -> void:
	# Add any visual or audio juice here (vibration, spark particles, sound)
	print("(NET CODE) Getchu!")
