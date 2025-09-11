@tool
extends EditorPlugin


const SCAN_DIR_PATH : String = "res://mods"
const MainPanel = preload("res://addons/ModZipExporter/Scenes/ModExporter.tscn")

var main_panel_instance : Node

var scan_button : Button
var export_button : Button
var open_mod_folder : Button
var project_selector : OptionButton
var mod_path_line_edit : LineEdit
var export_name_line_edit : LineEdit
var progress_label : Label
var status_label : Label
var progress_bar : ProgressBar

var open_export_folder_checkbox : CheckBox
var convert_text_resources_checkbox : CheckBox

var detected_projects_col : Array[String] = []
var files_col : Array[String] = []
var stored_zip_paths_col : Array[String] = []

var custom_resource_hash : String = ""
var compiled_remaps : Dictionary = {}

var meta_files : Array[String] = [
	"changelog.txt.yaml",
	"README.md",
	"LICENCE.md",
	"CREDITS.md"
]

# Main Scene Plugins
# Link: https://docs.godotengine.org/en/latest/tutorials/plugins/editor/making_main_screen_plugins.html

# $-----

func _enter_tree() -> void:
	info("Loading ModExporter...")

	# Setup
	main_panel_instance = MainPanel.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	_make_visible(false)

	scan_button = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/HBoxContainer/ScanButton")
	scan_button.connect("pressed", scan_for_projects)

	export_button = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ExportButton")
	export_button.connect("pressed", export_project_as_zip)
	
	open_mod_folder = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/OpenModFolderButton")
	open_mod_folder.connect("pressed", on_open_mod_folder)

	mod_path_line_edit = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ModPathLineEdit")
	export_name_line_edit = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ExportNameLineEdit")

	progress_label = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ProgressLabel")
	status_label = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/StatusLabel")

	progress_bar = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ProgressBar")

	open_export_folder_checkbox = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/OpenExportFolderCheckbox")
	convert_text_resources_checkbox = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/ConvertTextResourcesCheckbox")

	project_selector = main_panel_instance.get_node("HBox_Main/VBox_Right/HBoxContainer2/VBoxContainer/HBoxContainer/ProjectSelector")
	project_selector.item_selected.connect(
		func(index: int):
			mod_path_line_edit.text = detected_projects_col[index]
			export_name_line_edit.text = detected_projects_col[index].get_file() + ".zip")

	# First Scan
	scan_for_projects()

func _exit_tree() -> void:
	info("Unloading ModExporter...")
	if main_panel_instance:
		main_panel_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		main_panel_instance.visible = visible

func _get_plugin_name() -> String:
	return "ModExporter"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("ScriptExtend", "EditorIcons")

# $-----

func on_open_mod_folder() -> void:
	info("Opening export folder...")
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path("res://mods/%s" % export_name_line_edit.text))

func scan_for_projects() -> void:
	info("Scanning for mod projects...")
	detected_projects_col.clear()
	project_selector.clear()

	scan_recursive(SCAN_DIR_PATH)

	if project_selector.item_count > 0:
		project_selector.item_selected.emit(0)
	else:
		warning("Could not find any projects with mod.txt")

func scan_recursive(dir_path: String) -> void:
	for dir_name in DirAccess.get_directories_at(dir_path):
		if FileAccess.file_exists(dir_path.path_join(dir_name).path_join("mod.txt")):
			detected_projects_col.append(dir_path.path_join(dir_name))
			project_selector.add_item(dir_name)
			info("Found project: %s" % dir_name)
		else:
			scan_recursive(dir_path.path_join(dir_name))

func collect_files(dir_path: String):
	for dir_name in DirAccess.get_directories_at(dir_path):
		if not dir_name.ends_with(".git"):
			collect_files(dir_path.path_join(dir_name))

	for file_name in DirAccess.get_files_at(dir_path):
		# NOTE: Files listed in 'meta_files' have to be manually added
		# into the zip file.
		if (file_name in meta_files): continue

		# TODO: This line needs to be checked of rightness. Isn't it
		# supposed to ignore files ending on '.import' rather than
		# checking the directory name?
		# NOTE: I have changed this to file_name for now.
		if (file_name.ends_with(".import")): continue
		if (file_name == "mod.txt"): continue
		
		files_col.append(dir_path.path_join(file_name))

# Stores an array of bytes as a file in a given ZIP file at the 
# given file path and remembers the file been stored already.
func store_buffer_in_zip(zip: ZIPPacker, file_path: String, buffer: PackedByteArray):
	file_path = file_path.trim_prefix("res://")
	if file_path in stored_zip_paths_col:
		return
	
	zip.start_file(file_path)
	zip.write_file(buffer)
	zip.close_file()

	stored_zip_paths_col.append(file_path)

# Stores any file in a given ZIP file at the given file path and
# remembers the file been stored already.
func store_file_in_zip(zip: ZIPPacker, file_path: String, dest_path: String = ""):
	file_path = file_path.trim_prefix("res://")
	if file_path in stored_zip_paths_col:
		return

	if dest_path.is_empty():
		dest_path = file_path

	zip.start_file(dest_path)
	var file_access = FileAccess.open("res://%s" % file_path, FileAccess.ModeFlags.READ)
	# TODO: This needs to be handled better
	if file_access == null:
		error("Could not open file: 'res://%s' " %  file_path)
		zip.close_file()
		zip.close()
		return

	zip.write_file(file_access.get_buffer(file_access.get_length()))
	file_access.close()
	zip.close_file()

	stored_zip_paths_col.append(file_path)

func add_mod_file_to_zip(zip: ZIPPacker, file_path: String) -> void:
	var file_name : String = file_path.get_file()
	var file_dir : String = file_path.trim_suffix(file_name)

	# Check if the file is an imported godot resource (e.g., *.png -> *.s3tc.ctex) then store all the
	# dest files and then the import config in the given zip.
	var import_path : String = file_dir.path_join("%s.import" % file_name)
	if FileAccess.file_exists(import_path):
		var import_file_access = FileAccess.open(import_path, FileAccess.ModeFlags.READ)
		var import_config : ConfigFile = ConfigFile.new()
		import_config.parse(import_file_access.get_as_text())
		import_file_access.close()

		# Store dest files
		if import_config.has_section("deps") and import_config.has_section_key("deps", "dest_files"):
			for dest_file_path in import_config.get_value("deps", "dest_files", null):
				store_file_in_zip(zip, dest_file_path)
		
		# Store the .import file (contains import settings and dest file paths)
		var remap_config : ConfigFile = ConfigFile.new()
		for key in import_config.get_section_keys("remap"):
			if key == "generator_parameters": continue
			remap_config.set_value("remap", key, import_config.get_value("remap", key))
		store_buffer_in_zip(zip, import_path, remap_config.encode_to_text().to_utf8_buffer())
	
	# Else check if file is a godot text resoruce
	else:
		if file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
			# Convert the text resoruce into binary, stores the binary version to disk and in zip
			# TODO: make the conversion to binary optional (checkbox)
			var binary_name = file_name.trim_suffix(".tres").trim_suffix(".tscn") + (".scn" if file_name.ends_with(".tscn") else ".res")
			var binary_file_path = "res://.godot/exported/%s/export-%s-%s" % [custom_resource_hash, file_path.md5_text(), binary_name]
			var file_resource : Resource = ResourceLoader.load(file_path)
			ResourceSaver.save(file_resource, binary_file_path)
			store_file_in_zip(zip, binary_file_path)

			# Store remap (this redirects to the binary version of this resource)
			var remap_config : ConfigFile = ConfigFile.new()
			remap_config.set_value("remap", "path", binary_file_path)
			compiled_remaps[file_path] = binary_file_path
			store_buffer_in_zip(zip, file_dir.path_join("%s.remap" % file_name), remap_config.encode_to_text().to_utf8_buffer())

	# Else Else store file as raw
		else:
			store_file_in_zip(zip, file_path)

func export_project_as_zip(ignore_mod_txt: bool = false) -> void:
	status_label.modulate = Color.WHITE

	var mod_path = mod_path_line_edit.text
	var zip_file_name = export_name_line_edit.text
	info("[color=GREEN]Exporting Project '%s' as '%s'...[/color]" % [mod_path, zip_file_name])

	# Check for 'mod.txt'
	# NOTE: This part differs from the original implementation. Before this function
	# did not care for an existing 'mod.txt'. It now warns the user in absense of said
	# file and stops the export. This validation can also be toggled in order to be used
	# for when simple export is needed.
	var mod_config_path = mod_path.path_join("mod.txt")
	var mod_override_config_path = mod_path.path_join("override.cfg")
	if not FileAccess.file_exists(mod_config_path) and not ignore_mod_txt:
		status_label.modulate = Color.YELLOW
		status_label.text = "Status: Could not export project because of missing 'mod.txt'"
		warning("Could not export project: could not find '%s'" % mod_config_path)
		return
	
	compiled_remaps.clear()
	stored_zip_paths_col.clear()
	custom_resource_hash = DirAccess.get_directories_at("res://.godot/exported")[0]

	info("Collecting Files...")
	files_col.clear()
	collect_files(mod_path)

	# Create ZIP
	var zip_file : ZIPPacker = ZIPPacker.new()
	zip_file.open("res://mods/%s" % zip_file_name)

	# TODO: Get a better understanding what this is for
	var global_class_list = ProjectSettings.get_global_class_list()
	var mod_class_list : Array[Dictionary] = []

	info("Storing Collected Files...")
	# Write collected files
	var file_index = 1
	for mod_file_path in files_col:
		status_label .text = "Status: Exporting %s..." % mod_file_path
		progress_label.text = "%d/%d" % [file_index, files_col.size()]
		progress_bar.min_value = 0
		progress_bar.step = 1
		progress_bar.max_value = files_col.size()
		progress_bar.value = file_index
		await get_tree().create_timer(0.01).timeout

		for global_class in global_class_list:
			if global_class.path == mod_file_path:
				mod_class_list.append(global_class)
				break
		
		# Store Mod Files
		if mod_file_path != mod_config_path:
			add_mod_file_to_zip(zip_file, mod_file_path)

		# Store 'override.cfg'
		elif mod_file_path == mod_override_config_path:
			store_file_in_zip(zip_file, mod_file_path, "override.cfg")
		
		file_index += 1

	# Store mod class list
	if not mod_class_list.is_empty():
		status_label.text = "Status: Writing class list..."
		await get_tree().create_timer(0.01).timeout
		
		var class_list_config : ConfigFile = ConfigFile.new()
		class_list_config.set_value("", "list", mod_class_list)
		store_buffer_in_zip(zip_file, ".godot/global_script_class_cache.cfg", class_list_config.encode_to_text().to_utf8_buffer())

	info("Writing Mod TXT...")
	# Write mod.txt
	status_label.text = "Status: Writing mod.txt..."
	await get_tree().create_timer(0.01).timeout
	if FileAccess.file_exists(mod_config_path):
		var mod_config_file : ConfigFile = ConfigFile.new()
		mod_config_file.load(mod_config_path)

		# Store the remaps defined in the mod.txt's remaps section
		if mod_config_file.has_section("remaps"):
			for remap_key in mod_config_file.get_section_keys("remaps"):
				var remap_config : ConfigFile = ConfigFile.new()
				var override_value = mod_config_file.get_value("remaps", remap_key)
				# Get the compiled file from 'add_mod_file_to_zip' or use the 'mod.txt' version
				override_value = compiled_remaps.get(override_value, override_value)
				remap_config.set_value("remap", "path", override_value)
				store_buffer_in_zip(zip_file, "%s.remap" % remap_key, remap_config.encode_to_text().to_utf8_buffer())

			# Remove the remaps section because it is not needed to be store in the mod zip
			mod_config_file.erase_section("remaps")

		# Store the 'mod.txt'
		store_buffer_in_zip(zip_file, "mod.txt", mod_config_file.encode_to_text().to_utf8_buffer())

	# Store files listed in 'meta_files' manually
	status_label.text = "Status: Meta Files..."
	for meta_file in meta_files:
		if (FileAccess.file_exists(mod_path.path_join(meta_file))):
			info("Storing meta file '%s'..." % meta_file)
			store_file_in_zip(zip_file, mod_path.path_join(meta_file), meta_file)

	# Close ZIP
	zip_file.close()
	status_label.text = "Status: Done!"
	status_label.modulate = Color.LIME
	info("[color=GREEN]Done![/color]")

	if open_export_folder_checkbox.button_pressed:
		info("Opening export folder...")
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path("res://mods/%s" % zip_file_name))

# $-----

func info(text: String) -> void:
	print_rich("[color=#33aabb][INFO: ModExporter] %s[/color]" % text)

func warning(text: String) -> void:
	print_rich("[color=YELLOW][WARNING: ModExporter] %s[/color]" % text)

func error(text: String) -> void:
	print_rich("[color=RED][ERROR: ModExporter] %s[/color]" % text)
