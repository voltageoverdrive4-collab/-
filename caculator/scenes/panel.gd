extends Panel

var dragging := false
var drag_offset := 0.0

# Adjust these to match your UI
var min_y := -260       # closed, with the drawer handle visible
var max_y := 0           # fully shown

func _ready():
	global_position.y = min_y

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = true
			drag_offset = event.position.y
		elif not event.pressed:
			dragging = false

			# Snap open/closed
			if global_position.y > min_y / 2:
				open_panel()
			else:
				close_panel()

	if event is InputEventMouseMotion and dragging:
		var new_y = global_position.y + event.relative.y
		new_y = clamp(new_y, min_y, max_y)
		global_position.y = new_y

func open_panel():
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", max_y, 0.2)

func close_panel():
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", min_y, 0.2)



func _on_HistoryToggleButton_pressed():
	var panel := get_node("../HistoryPanel")

	if panel.global_position.y < 0:
		panel.open_panel()
	else:
		panel.close_panel()
