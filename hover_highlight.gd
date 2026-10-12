extends ColorRect
var game: Node2D
func _ready() -> void:
	game=get_parent()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float mask = 1.0 - smoothstep(0.50, 1.0, dot(p, p));
 vec3 original = texture(scene, SCREEN_UV).rgb;
 vec3 lit = min(original * 1.45 + vec3(0.025, 0.055, 0.065), vec3(1.0));
 COLOR = vec4(lit, mask * 0.75);
}
"""
	var effect=ShaderMaterial.new()
	effect.shader=shader
	material=effect
	visible=false
func _process(_delta: float) -> void:
	visible=false
	if game.menu: return
	var target=game.clicked_target(game.get_global_mouse_position())
	if target.is_empty() or target.get("id")=="console": return
	var bounds: Rect2=target.rect
	position=bounds.position-Vector2(game.camera_x,0)
	size=bounds.size
	visible=true
