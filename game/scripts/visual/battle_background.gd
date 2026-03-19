extends Sprite2D
class_name BattleBackground

@export var background_texture: Texture2D
@export var camera_path: NodePath

var _last_viewport_size := Vector2.ZERO
var _last_camera_position := Vector2.INF
var _last_camera_zoom := Vector2.INF


func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = -100
	_refresh_layout()


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var camera := get_node_or_null(camera_path) as Camera2D
	var camera_position := camera.global_position if camera != null else viewport_size * 0.5
	var camera_zoom := camera.zoom if camera != null else Vector2.ONE
	if viewport_size != _last_viewport_size or camera_position != _last_camera_position or camera_zoom != _last_camera_zoom:
		_refresh_layout()


func _refresh_layout() -> void:
	texture = background_texture
	if texture == null:
		visible = false
		return

	visible = true
	var viewport_size := get_viewport_rect().size
	var camera := get_node_or_null(camera_path) as Camera2D
	var camera_position := camera.global_position if camera != null else viewport_size * 0.5
	var camera_zoom := camera.zoom if camera != null else Vector2.ONE
	var visible_world_size := viewport_size * camera_zoom
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var scale_factor := maxf(
		visible_world_size.x / maxf(texture_size.x, 1.0),
		visible_world_size.y / maxf(texture_size.y, 1.0)
	)

	global_position = camera_position
	scale = Vector2.ONE * scale_factor

	_last_viewport_size = viewport_size
	_last_camera_position = camera_position
	_last_camera_zoom = camera_zoom
