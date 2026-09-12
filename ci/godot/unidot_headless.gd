@tool
extends SceneTree

const IMPORTER := preload("res://addons/unidot_importer/package_import_dialog.gd")
const UNITY_ASSETS := "res://UnitySource/Assets"
const TIMEOUT_MS := 20 * 60 * 1000

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var importer = IMPORTER.new()
	var fbx2gltf := OS.get_environment("FBX2GLTF_PATH")
	if not fbx2gltf.is_empty():
		# Unidot reads this editor setting when importing FBX assets.
		var settings := EditorInterface.get_editor_settings()
		settings.set_setting("filesystem/import/fbx/fbx2gltf_path", fbx2gltf)

	importer._show_importer_common()
	importer._selected_package(ProjectSettings.globalize_path(UNITY_ASSETS))

	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while (importer._meta_work_count == 0 or importer.main_dialog_tree == null) and Time.get_ticks_msec() < deadline:
		await process_frame

	if importer.main_dialog_tree == null:
		push_error("Unidot did not initialize its asset tree.")
		quit(1)
		return

	# Preserve as much of the Unity project as Unidot can represent.
	importer.asset_database.use_text_resources = true
	importer.asset_database.use_text_scenes = true
	importer.asset_database.enable_unidot_keys = true
	importer.asset_database.add_unsupported_components = true
	importer.asset_database.auto_select_dependencies = true
	# Use the explicit FBX -> glTF path instead of relying on the importer default.
	# This is important for skinned characters and complex environment meshes.
	importer.asset_database.convert_fbx_to_gltf = true

	while importer._meta_work_count > 0 and Time.get_ticks_msec() < deadline:
		await process_frame

	if importer._meta_work_count > 0:
		push_error("Unidot metadata preprocessing timed out.")
		quit(1)
		return

	var root: TreeItem = importer.main_dialog_tree.get_root()
	if root == null:
		push_error("Unidot asset tree has no root.")
		quit(1)
		return

	importer._check_recursively(root, true, true)
	importer._asset_tree_window_confirmed()

	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	while not importer.import_finished and Time.get_ticks_msec() < deadline:
		if not importer.paused:
			importer.do_import_step()
		await process_frame

	if not importer.import_finished:
		push_error("Unidot import timed out.")
		quit(1)
		return

	print("UNIDOT_IMPORT_COMPLETE")
	quit(0)
