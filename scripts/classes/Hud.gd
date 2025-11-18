extends Node3D
class_name Hud

const info_right_base: String = """ 
HITS
{0}
 
 
 

MISSES
{1}"""

@onready var viewport_right: SubViewport = %InfoRightViewport
@onready var text_right: RichTextLabel = %InfoRightText

func _ready() -> void:
	self.position=Vector3(0,0,SSCS.settings.grid_distance)

func update_info_right(hits: int, misses: int) -> void:
	text_right.text = info_right_base.format([hits,misses])
	viewport_right.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	viewport_right.render_target_update_mode = SubViewport.UPDATE_ONCE
