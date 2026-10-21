extends Control

const NOTES_PATH := "user://notes.json"
const SETTINGS_PATH := "user://notes_settings.cfg"

@export var note_item_scene: PackedScene

@onready var background: Panel = $Background
@onready var theme_button: Button = $PageMargin/Page/Header/ThemeButton
@onready var new_note_button: Button = $PageMargin/Page/Header/NewNoteButton
@onready var search_field: LineEdit = $PageMargin/Page/Workspace/Sidebar/SidebarContent/SearchField
@onready var note_list: VBoxContainer = $PageMargin/Page/Workspace/Sidebar/SidebarContent/NotesScroll/NoteList
@onready var empty_list_label: Label = $PageMargin/Page/Workspace/Sidebar/SidebarContent/NotesScroll/NoteList/EmptyListLabel
@onready var count_label: Label = $PageMargin/Page/Workspace/Sidebar/SidebarContent/ListHeading/CountLabel
@onready var pin_button: Button = $PageMargin/Page/Workspace/EditorCard/Editor/EditorToolbar/PinButton
@onready var status_label: Label = $PageMargin/Page/Workspace/EditorCard/Editor/EditorToolbar/StatusLabel
@onready var delete_note_button: Button = $PageMargin/Page/Workspace/EditorCard/Editor/EditorToolbar/DeleteButton
@onready var title_field: LineEdit = $PageMargin/Page/Workspace/EditorCard/Editor/TitleField
@onready var body_field: TextEdit = $PageMargin/Page/Workspace/EditorCard/Editor/BodyField
@onready var delete_dialog: ConfirmationDialog = $DeleteDialog
@onready var save_timer: Timer = $SaveTimer

var notes: Array[Dictionary] = []
var active_note_id := ""
var dark_mode := false


func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	_load_settings()
	_apply_theme()
	_load_notes()
	_select_note("")


func _create_note() -> void:
	_save_current_note()
	var now := Time.get_datetime_string_from_system()
	var note_id := "%s-%s" % [Time.get_ticks_usec(), randi()]
	notes.append({
		"id": note_id,
		"title": "",
		"body": "",
		"pinned": false,
		"created_at": now,
		"updated_at": now
	})
	search_field.clear()
	_save_notes()
	_select_note(note_id)
	title_field.grab_focus()


func _on_search_changed(_query: String) -> void:
	_refresh_note_list()


func _on_editor_changed(_new_text: String = "") -> void:
	if active_note_id.is_empty():
		return
	status_label.text = "Unsaved changes"
	save_timer.start()


func _save_current_note(refresh_list: bool = true) -> void:
	var note_index := _find_note_index(active_note_id)
	if note_index == -1:
		return

	var note := notes[note_index]
	var new_title := title_field.text.strip_edges()
	var new_body := body_field.text
	if note["title"] == new_title and note["body"] == new_body:
		if status_label.text == "Unsaved changes":
			status_label.text = "Saved"
		return

	note["title"] = new_title
	note["body"] = new_body
	note["updated_at"] = Time.get_datetime_string_from_system()
	notes[note_index] = note
	_sort_notes()
	var saved := _save_notes()
	if refresh_list:
		_refresh_note_list()
	status_label.text = "Saved just now" if saved else "Save failed"


func _select_note(note_id: String) -> void:
	save_timer.stop()
	if not active_note_id.is_empty():
		_save_current_note()

	active_note_id = note_id
	var note_index := _find_note_index(note_id)
	var has_note := note_index != -1
	title_field.editable = has_note
	body_field.editable = has_note
	pin_button.disabled = not has_note
	delete_note_button.disabled = not has_note
	status_label.text = ""

	title_field.set_block_signals(true)
	body_field.set_block_signals(true)
	if not has_note:
		title_field.clear()
		body_field.clear()
		pin_button.text = "☆  Pin"
		status_label.text = "Select a note"
	else:
		var note := notes[note_index]
		title_field.text = str(note["title"])
		body_field.text = str(note["body"])
		pin_button.text = "★  Pinned" if note["pinned"] else "☆  Pin"
		status_label.text = "Saved"
	title_field.set_block_signals(false)
	body_field.set_block_signals(false)
	_refresh_note_list()


func _refresh_note_list() -> void:
	if note_item_scene == null:
		push_error("Assign a note item scene in the NotesApp scene.")
		return

	for child in note_list.get_children():
		if child == empty_list_label:
			continue
		note_list.remove_child(child)
		child.queue_free()

	var query := search_field.text.strip_edges().to_lower()
	var visible_count := 0
	for note in notes:
		var note_title := str(note["title"])
		var note_body := str(note["body"])
		if not query.is_empty():
			var searchable_text := "%s %s" % [note_title, note_body]
			if not searchable_text.to_lower().contains(query):
				continue

		var note_button := note_item_scene.instantiate() as Button
		if note_button == null:
			push_error("The note item scene root must be a Button.")
			return
		var title_text := note_title if not note_title.is_empty() else "Untitled note"
		note_button.text = ("★  " if note["pinned"] else "") + title_text
		var preview := note_body.strip_edges().replace("\n", " ")
		if not preview.is_empty():
			note_button.text += "\n" + preview.left(72)
		note_button.custom_minimum_size.y = 58 if preview.is_empty() else 82
		note_button.pressed.connect(_select_note.bind(str(note["id"])))
		note_list.add_child(note_button)
		_style_button(note_button, "selected" if str(note["id"]) == active_note_id else "list")
		visible_count += 1

	count_label.text = str(notes.size()) if query.is_empty() else "%d / %d" % [visible_count, notes.size()]
	empty_list_label.visible = visible_count == 0
	if visible_count == 0:
		empty_list_label.text = "No matching notes" if not query.is_empty() else "No notes yet"


func _toggle_pin() -> void:
	var note_index := _find_note_index(active_note_id)
	if note_index == -1:
		return
	var note := notes[note_index]
	note["pinned"] = not note["pinned"]
	note["updated_at"] = Time.get_datetime_string_from_system()
	notes[note_index] = note
	_sort_notes()
	pin_button.text = "★  Pinned" if note["pinned"] else "☆  Pin"
	_save_notes()
	_refresh_note_list()


func _confirm_delete() -> void:
	if not active_note_id.is_empty():
		delete_dialog.popup_centered()


func _delete_note() -> void:
	var note_index := _find_note_index(active_note_id)
	if note_index == -1:
		return
	notes.remove_at(note_index)
	active_note_id = ""
	_save_notes()
	_select_note("")


func _toggle_theme() -> void:
	dark_mode = not dark_mode
	_apply_theme()
	_refresh_note_list()
	_save_settings()


func _load_notes() -> void:
	if not FileAccess.file_exists(NOTES_PATH):
		return
	var file := FileAccess.open(NOTES_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open notes file: %s" % error_string(FileAccess.get_open_error()))
		return

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_error("Unable to parse saved notes: %s" % json.get_error_message())
		return
	if not (json.data is Array):
		push_error("Saved notes data must be a JSON array.")
		return

	for value in json.data:
		if not (value is Dictionary):
			push_warning("Skipping a malformed saved note entry.")
			continue
		if not (value.get("id", null) is String):
			push_warning("Skipping a saved note without a valid ID.")
			continue
		var pinned_value: Variant = value.get("pinned", false)
		notes.append({
			"id": str(value["id"]),
			"title": str(value.get("title", "")),
			"body": str(value.get("body", "")),
			"pinned": pinned_value is bool and pinned_value,
			"created_at": str(value.get("created_at", "")),
			"updated_at": str(value.get("updated_at", ""))
		})
	_sort_notes()


func _save_notes() -> bool:
	var file := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save notes: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(notes, "\t"))
	file.flush()
	var save_error := file.get_error()
	file.close()
	if save_error != OK:
		push_error("Unable to finish saving notes: %s" % error_string(save_error))
		return false
	return true


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Unable to load notes settings: %s" % error_string(error))
		return
	var saved_dark_mode: Variant = config.get_value("appearance", "dark_mode", false)
	if saved_dark_mode is bool:
		dark_mode = saved_dark_mode
	else:
		push_error("Notes setting 'dark_mode' must be a boolean.")


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("appearance", "dark_mode", dark_mode)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Unable to save notes settings: %s" % error_string(error))


func _find_note_index(note_id: String) -> int:
	if note_id.is_empty():
		return -1
	for index in range(notes.size()):
		if str(notes[index]["id"]) == note_id:
			return index
	return -1


func _sort_notes() -> void:
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["pinned"] != b["pinned"]:
			return a["pinned"]
		return str(a["updated_at"]) > str(b["updated_at"])
	)


func _style_button(button: Button, style_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	match style_name:
		"accent":
			style.bg_color = Color(0.29, 0.42, 0.84, 1) if not dark_mode else Color(0.38, 0.52, 0.95, 1)
			button.add_theme_color_override("font_color", Color.WHITE)
		"danger":
			style.bg_color = Color(0.98, 0.91, 0.91, 1) if not dark_mode else Color(0.34, 0.19, 0.22, 1)
			button.add_theme_color_override("font_color", Color(0.7, 0.22, 0.22, 1) if not dark_mode else Color(1, 0.68, 0.68, 1))
		"selected":
			style.bg_color = Color(0.88, 0.91, 0.99, 1) if not dark_mode else Color(0.2, 0.27, 0.4, 1)
			button.add_theme_color_override("font_color", Color(0.16, 0.22, 0.36, 1) if not dark_mode else Color(0.9, 0.93, 1, 1))
		"list":
			style.bg_color = Color(0.95, 0.96, 0.98, 1) if not dark_mode else Color(0.14, 0.17, 0.23, 1)
			button.add_theme_color_override("font_color", Color(0.25, 0.29, 0.38, 1) if not dark_mode else Color(0.79, 0.82, 0.88, 1))

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.08)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed.bg_color.darkened(0.06)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", style)


func _apply_theme() -> void:
	var background_color := Color(0.95, 0.96, 0.98, 1) if not dark_mode else Color(0.07, 0.085, 0.12, 1)
	var card_color := Color(1, 1, 1, 1) if not dark_mode else Color(0.105, 0.13, 0.18, 1)
	var field_color := Color(0.97, 0.98, 0.99, 1) if not dark_mode else Color(0.08, 0.1, 0.14, 1)
	var primary_color := Color(0.14, 0.17, 0.23, 1) if not dark_mode else Color(0.91, 0.93, 0.97, 1)
	var secondary_color := Color(0.43, 0.47, 0.55, 1) if not dark_mode else Color(0.62, 0.67, 0.76, 1)
	var border_color := Color(0.88, 0.9, 0.93, 1) if not dark_mode else Color(0.2, 0.24, 0.32, 1)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = card_color
	card_style.border_color = border_color
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(18)
	card_style.content_margin_left = 18.0
	card_style.content_margin_top = 18.0
	card_style.content_margin_right = 18.0
	card_style.content_margin_bottom = 18.0

	var field_style := StyleBoxFlat.new()
	field_style.bg_color = field_color
	field_style.border_color = border_color
	field_style.set_border_width_all(1)
	field_style.set_corner_radius_all(10)
	field_style.content_margin_left = 12.0
	field_style.content_margin_top = 10.0
	field_style.content_margin_right = 12.0
	field_style.content_margin_bottom = 10.0

	var app_theme := Theme.new()
	app_theme.default_font_size = 16
	app_theme.set_color("font_color", "Label", primary_color)
	app_theme.set_color("font_color", "LineEdit", primary_color)
	app_theme.set_color("font_color", "TextEdit", primary_color)
	app_theme.set_color("font_placeholder_color", "LineEdit", secondary_color)
	app_theme.set_color("font_placeholder_color", "TextEdit", secondary_color)
	app_theme.set_color("font_color", "Button", primary_color)
	app_theme.set_color("font_hover_color", "Button", primary_color)
	app_theme.set_color("font_pressed_color", "Button", primary_color)
	app_theme.set_stylebox("panel", "Panel", card_style)
	app_theme.set_stylebox("panel", "PanelContainer", card_style)
	var button_style := field_style.duplicate() as StyleBoxFlat
	button_style.bg_color = card_color
	app_theme.set_stylebox("normal", "Button", button_style)
	var button_hover := button_style.duplicate() as StyleBoxFlat
	button_hover.bg_color = field_color
	app_theme.set_stylebox("hover", "Button", button_hover)
	app_theme.set_stylebox("pressed", "Button", button_hover)
	app_theme.set_stylebox("focus", "Button", button_style)
	app_theme.set_stylebox("normal", "LineEdit", field_style)
	app_theme.set_stylebox("focus", "LineEdit", field_style)
	app_theme.set_stylebox("normal", "TextEdit", field_style)
	app_theme.set_stylebox("focus", "TextEdit", field_style)
	theme = app_theme

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = background_color
	background.add_theme_stylebox_override("panel", background_style)
	for control in [search_field, title_field, body_field]:
		control.add_theme_color_override("font_color", primary_color)
		control.add_theme_color_override("font_placeholder_color", secondary_color)

	theme_button.text = "☀  Light mode" if dark_mode else "☾  Dark mode"
	_style_button(theme_button, "list")
	_style_button(new_note_button, "accent")
	_style_button(delete_note_button, "danger")
	_style_button(pin_button, "list")


func _on_tree_exiting() -> void:
	save_timer.stop()
	_save_current_note(false)
	_save_notes()
