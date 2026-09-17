@tool
extends SceneTree

const IMPORTER := preload("res://addons/unidot_importer/package_import_dialog.gd")
const UNITY_ASSETS := "res://UnitySource/Assets"
const TIMEOUT_MS := 20 * 60 * 1000

func _wait_for_filesystem_scan(deadline: int) -> bool:
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan_sources()
	while fs.is_scanning() and Time.get_ticks_msec() < deadline:
		await process_frame
	return not fs.is_scanning()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS

	# Do not let the importer race Godot's initial filesystem scan. This is
	# especially important for projects with thousands of Unity assets and lots
	# of GUID-linked textures/materials.
	if not await _wait_for_filesystem_scan(deadline):
		push_error("Godot filesystem scan timed out before Unidot initialization.")
		quit(1)
		return

	var importer = IMPORTER.new()
	var fbx2gltf := OS.get_environment("FBX2GLTF_PATH")
	if not fbx2gltf.is_empty():
		var settings := EditorInterface.get_editor_settings()
		settings.set_setting("filesystem/import/fbx/fbx2gltf_path", fbx2gltf)

	importer._show_importer_common()
	importer._selected_package(ProjectSettings.globalize_path(UNITY_ASSETS))

	while (importer._meta_work_count == 0 or importer.main_dialog_tree == null) and Time.get_ticks_msec() < deadline:
		await process_frame

	if importer.main_dialog_tree == null:
		push_error("Unidot did not initialize its asset tree.")
		quit(1)
		return

	# Explicitly keep text resources/scenes so Unity GUID references remain
	# inspectable after import. Dependency auto-selection is enabled because
	# Unidot itself documents missing texture dependencies as a known limitation.
	importer.asset_database.use_text_resources = true
	importer.asset_database.use_text_scenes = true
	importer.asset_database.enable_unidot_keys = true
	importer.asset_database.add_unsupported_components = true
	importer.asset_database.auto_select_dependencies = true
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

	# Select the complete tree recursively so that the importer sees every
	# source asset, not only the gameplay scene and its first-level references.
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

	# Force a second filesystem scan so downstream Godot importers see newly
	# generated .tres/.tscn/.gltf resources before the workflow packages them.
	if not await _wait_for_filesystem_scan(Time.get_ticks_msec() + TIMEOUT_MS):
		push_error("Godot filesystem scan timed out after Unidot conversion.")
		quit(1)
		return

	print("UNIDOT_IMPORT_COMPLETE")
	quit(0)
