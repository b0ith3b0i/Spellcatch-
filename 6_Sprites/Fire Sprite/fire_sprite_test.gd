extends Area3D

# Ensures the sprite can't be caught twice if hit rapidly
var is_captured: bool = false

func _ready() -> void:
	print("Fire Sprite dummy active!")

# This is the exact function name your net script looks for
func get_caught() -> void:
	if is_captured:
		return
		
	is_captured = true
	print("(SPRITE CODE) Getchu'!")
	
	start_capture_sequence()

func start_capture_sequence() -> void:
	# Disable collisions immediately so it can't be hit again
	$CollisionShape3D.disabled = true
	
	# Create a smooth animation: the sprite spins, shrinks, and vanishes
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees:y", 360.0, 0.4)
	
	# Wait for the animation to finish, then delete it from the world
	await tween.finished
	print("Sent back to the Crystal!")
	queue_free()
