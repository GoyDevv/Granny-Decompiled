@tool
extends EditorScript

const IMPORTER := preload("res://addons/unidot_importer/package_import_dialog.gd")
const UNITY_ASSETS := "res://UnitySource/Assets"
const TIMEOUT_MS := 20 * 60 * 1000

func _run() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		push_error("No SceneTree available.")
		return

	var importer = IMPORTER.new()
	importer._show_importer_common()
	importer._selected_package(ProjectSettings.globalize_path(UNITY_ASSETS))

	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while (importer._meta_work_count == 0 or importer.main_dialog_tree == null) and Time.get_ticks_msec() < deadline:
		await loop.process_frame

	if importer.main_dialog_tree == null:
		push_error("Unidot did not initialize its asset tree.")
		loop.quit(1)
		return

	# Make the CI import maximally complete and editable.
	importer.asset_database.use_text_resources = true
	importer.asset_database.use_text_scenes = true
	importer.asset_database.enable_unidot_keys = true
	importer.asset_database.add_unsupported_components = true
	importer.asset_database.auto_select_dependencies = true

	while importer._meta_work_count > 0 and Time.get_ticks_msec() < deadline:
		await loop.process_frame

	if importer._meta_work_count > 0:
		push_error("Unidot metadata preprocessing timed out.")
		loop.quit(1)
		return

	var root: TreeItem = importer.main_dialog_tree.get_root()
	if root == null:
		push_error("Unidot asset tree has no root.")
		loop.quit(1)
		return

	# Select everything and include dependencies.
	importer._check_recursively(root, true, true)
	importer._asset_tree_window_confirmed()

	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	while not importer.import_finished and Time.get_ticks_msec() < deadline:
		if not importer.paused:
			importer.do_import_step()
		await loop.process_frame

	if not importer.import_finished:
		push_error("Unidot import timed out.")
		loop.quit(1)
		return

	print("UNIDOT_IMPORT_COMPLETE")
	loop.quit(0)
