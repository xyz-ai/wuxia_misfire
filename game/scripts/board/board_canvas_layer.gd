extends Node2D
class_name BoardCanvasLayer

@export var draw_method: StringName


func redraw() -> void:
	queue_redraw()


func _draw() -> void:
	if draw_method == StringName():
		return
	var provider := _find_provider()
	if provider != null:
		provider.call(draw_method, self)


func _find_provider() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method(draw_method):
			return current
		current = current.get_parent()
	return null
