extends Control

const LIGHT_THEME: Theme = preload("res://scenes/light_theme.tres")
const DARK_THEME: Theme = preload("res://scenes/dark_theme.tres")


func _on_zero_button_resized() -> void:
	var zero_container := get_parent() as Control
	if zero_container != null:
		%ZeroButton.offset_left = -zero_container.size.x




@onready var label: Label = $VBoxContainer/DisplayCard/Label
@onready var history_label: Label = $HistoryPanel/ScrollContainer/Label
@onready var scientific_grid: GridContainer = $VBoxContainer/ScientificGrid
@onready var scientific_toggle: Button = $VBoxContainer/Header/ScientificToggleButton
@onready var settings_button: Button = $VBoxContainer/Header/SettingsButton
@onready var title_label: Label = $VBoxContainer/Header/Title
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var dark_mode_toggle: CheckButton = $SettingsPanel/SettingsContent/DarkModeToggle

var temp_nums: Array = []
var fin_nums: Array = []
var history: Array = []
var use_degrees := true
var dark_mode_enabled := false


func _ready():
	label.text = "0"
	temp_nums.clear()
	fin_nums.clear()
	scientific_grid.hide()
	_load_settings()
	_apply_theme()

	load_history()        # <-- AUTO LOAD HISTORY
	update_history_display()


func array_to_string(arr: Array) -> String:
	var s := ""
	for i in arr:
		s += str(i)
	return s


func update_history_display():
	var text := ""
	for entry in history:
		text += entry + "\n"
	history_label.text = text


# --- AUTO-SAVE HISTORY ---
func save_history_to_file():
	var file := FileAccess.open("user://history.txt", FileAccess.WRITE)
	if file == null:
		push_error("Unable to open calculator history for writing.")
		return
	for entry in history:
		file.store_line(entry)
	file.close()


# --- AUTO-LOAD HISTORY ---
func load_history():
	if FileAccess.file_exists("user://history.txt"):
		var file := FileAccess.open("user://history.txt", FileAccess.READ)
		if file == null:
			push_error("Unable to open calculator history for reading.")
			return
		while file.get_position() < file.get_length():
			var line := file.get_line()
			if line != "":
				history.append(line)
		file.close()


func button_pressed(character: String):
	# Numbers
	if character.is_valid_int():
		temp_nums.append(character)
		label.text = array_to_string(temp_nums)
		return

	# Decimal
	if character == ".":
		if not array_to_string(temp_nums).contains("."):
			if temp_nums.is_empty():
				temp_nums.append("0")
			temp_nums.append(character)
		label.text = array_to_string(temp_nums)
		return

	# Percent
	if character == "%":
		apply_unary_operation("percent")
		return

	if character == "+/-":
		apply_unary_operation("sign")
		return

	if character in ["sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "square", "ln", "log", "abs", "reciprocal"]:
		apply_unary_operation(character)
		return

	if character == "π":
		set_current_value(PI)
		return

	if character == "e":
		set_current_value(exp(1.0))
		return

	if character == "DEG/RAD":
		use_degrees = not use_degrees
		_update_scientific_toggle_text()
		return

	# Operators
	if character in ["+", "-", "/", "x", "^"]:
		if temp_nums.is_empty():
			return
		fin_nums.append(array_to_string(temp_nums))
		fin_nums.append(character)
		temp_nums.clear()
		label.text = character
		return

	# Equals
	if character == "=":
		if temp_nums.is_empty() or fin_nums.is_empty():
			return
		fin_nums.append(array_to_string(temp_nums))
		var expression_string := array_to_string(fin_nums)
		temp_nums.clear()

		var expression := Expression.new()
		expression_string = expression_string.replace("x", "*").replace("^", "**")
		if expression.parse(expression_string) != OK:
			label.text = "Error"
			fin_nums.clear()
			return
		var result = expression.execute()
		if expression.has_execute_failed() or not (result is int or result is float) or is_nan(float(result)) or is_inf(float(result)):
			label.text = "Error"
			fin_nums.clear()
			return

		label.text = str(result)

		# --- SAVE TO HISTORY ---
		var history_entry := expression_string + " = " + str(result)
		history.append(history_entry)
		update_history_display()
		save_history_to_file()     # <-- AUTO SAVE

		fin_nums.clear()
		temp_nums = str(result).split("")
		return

	if character == "SCIENTIFIC":
		scientific_grid.visible = not scientific_grid.visible
		_update_scientific_toggle_text()
		return

	if character == "SETTINGS":
		settings_panel.visible = not settings_panel.visible
		settings_button.text = "Close" if settings_panel.visible else "Settings"
		return

	# Clear current input
	if character == "C":
		temp_nums.clear()
		fin_nums.clear()
		label.text = "0"
		return

	# Clear history button (optional)
	if character == "HC":
		history.clear()
		update_history_display()
		save_history_to_file()
		return

	# Manual save button (optional)
	if character == "HS":
		save_history_to_file()
		return


func _update_scientific_toggle_text() -> void:
	var action := "Hide scientific" if scientific_grid.visible else "Scientific"
	var angle_mode := "DEG" if use_degrees else "RAD"
	scientific_toggle.text = "%s · %s" % [action, angle_mode]


func _on_dark_mode_toggled(enabled: bool) -> void:
	dark_mode_enabled = enabled
	_apply_theme()
	_save_settings()


func _apply_theme() -> void:
	theme = DARK_THEME if dark_mode_enabled else LIGHT_THEME
	title_label.add_theme_color_override(
		"font_color",
		Color(0.68, 0.74, 0.86, 1) if dark_mode_enabled else Color(0.34, 0.4, 0.53, 1)
	)
	dark_mode_toggle.set_block_signals(true)
	dark_mode_toggle.button_pressed = dark_mode_enabled
	dark_mode_toggle.set_block_signals(false)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load("user://settings.cfg")
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Unable to load calculator settings: %s" % error_string(error))
		return
	var saved_dark_mode: Variant = config.get_value("appearance", "dark_mode", false)
	if saved_dark_mode is bool:
		dark_mode_enabled = saved_dark_mode
	else:
		push_error("Calculator setting 'dark_mode' must be a boolean.")


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("appearance", "dark_mode", dark_mode_enabled)
	var error := config.save("user://settings.cfg")
	if error != OK:
		push_error("Unable to save calculator settings: %s" % error_string(error))


func set_current_value(value: float) -> void:
	temp_nums = str(value).split("")
	label.text = str(value)


func apply_unary_operation(operation: String) -> void:
	if temp_nums.is_empty():
		return

	var value := float(array_to_string(temp_nums))
	var angle := deg_to_rad(value) if use_degrees else value
	var result: float
	match operation:
		"percent":
			result = value / 100.0
		"sign":
			result = -value
		"sin":
			result = sin(angle)
		"cos":
			result = cos(angle)
		"tan":
			if is_equal_approx(abs(cos(angle)), 0.0):
				label.text = "Error"
				temp_nums.clear()
				return
			result = tan(angle)
		"asin":
			if abs(value) > 1.0:
				label.text = "Error"
				temp_nums.clear()
				return
			result = rad_to_deg(asin(value)) if use_degrees else asin(value)
		"acos":
			if abs(value) > 1.0:
				label.text = "Error"
				temp_nums.clear()
				return
			result = rad_to_deg(acos(value)) if use_degrees else acos(value)
		"atan":
			result = rad_to_deg(atan(value)) if use_degrees else atan(value)
		"sqrt":
			if value < 0.0:
				label.text = "Error"
				temp_nums.clear()
				return
			result = sqrt(value)
		"square":
			result = value * value
		"ln":
			if value <= 0.0:
				label.text = "Error"
				temp_nums.clear()
				return
			result = log(value)
		"log":
			if value <= 0.0:
				label.text = "Error"
				temp_nums.clear()
				return
			result = log(value) / log(10.0)
		"abs":
			result = abs(value)
		"reciprocal":
			if is_zero_approx(value):
				label.text = "Error"
				temp_nums.clear()
				return
			result = 1.0 / value
		_:
			return

	if is_nan(result) or is_inf(result):
		label.text = "Error"
		temp_nums.clear()
		return
	set_current_value(result)
