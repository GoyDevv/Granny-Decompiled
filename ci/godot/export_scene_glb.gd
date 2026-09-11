extends SceneTree

func _init() -> void:
	call_deferred("_export")

func _export() -> void:
	var scene_path := OS.get_environment("GRANNY_SCENE")
	if scene_path.is_empty():
		scene_path = find_scene("res://", "Scene.tscn")
	if scene_path.is_empty():
		push_error("Could not find converted Scene.tscn.")
		quit(1)
		return

	print("Exporting: ", scene_path)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Failed to load scene: " + scene_path)
		quit(1)
		return

	var root := packed.instantiate()
	if root == null:
		push_error("Failed to instantiate scene: " + scene_path)
		quit(1)
		return
	root.name = "GrannyMap"

	# Let imported resources finish resolving before serializing the scene.
	await process_frame
	await process_frame

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.image_format = "PNG"
	var err := document.append_from_scene(root, state)
	if err != OK:
		push_error("GLTF append failed: " + error_string(err))
		root.free()
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output"))
	var out_path := "res://output/granny_map.glb"
	err = document.write_to_filesystem(state, out_path)
	if err != OK:
		push_error("GLB write failed: " + error_string(err))
		root.free()
		quit(1)
		return

	print("GLB_EXPORT_COMPLETE: ", ProjectSettings.globalize_path(out_path))
	root.free()
	quit(0)

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
