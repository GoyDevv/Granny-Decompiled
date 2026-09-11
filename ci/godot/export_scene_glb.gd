@tool
extends EditorScript

func _run() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		push_error("No SceneTree available.")
		return

	var scene_path := OS.get_environment("GRANNY_SCENE")
	if scene_path.is_empty():
		scene_path = find_scene("res://", "Scene.tscn")
	if scene_path.is_empty():
		push_error("Could not find converted Scene.tscn.")
		loop.quit(1)
		return

	print("Exporting: ", scene_path)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Failed to load scene: " + scene_path)
		loop.quit(1)
		return

	var root := packed.instantiate()
	if root == null:
		push_error("Failed to instantiate scene: " + scene_path)
		loop.quit(1)
		return

	# Let imported resources finish resolving before serializing the scene.
	await loop.process_frame
	await loop.process_frame

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.image_format = "PNG"
	var err := document.append_from_scene(root, state)
	if err != OK:
		push_error("GLTF append failed: " + error_string(err))
		root.free()
		loop.quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output"))
	var out_path := "res://output/granny_map.glb"
	err = document.write_to_filesystem(state, out_path)
	if err != OK:
		push_error("GLB write failed: " + error_string(err))
		root.free()
		loop.quit(1)
		return

	print("GLB_EXPORT_COMPLETE: ", ProjectSettings.globalize_path(out_path))
	root.free()
	loop.quit(0)

func find_scene(path: String, filename: String) -> String:
	var dir := DirAccess.open(path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			var result := find_scene(full, filename)
			if not result.is_empty():
				dir.list_dir_end()
				return result
		elif name == filename:
			dir.list_dir_end()
			return full
	dir.list_dir_end()
	return ""
