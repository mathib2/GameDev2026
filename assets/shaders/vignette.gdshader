shader_type canvas_item;

// Room-edge darkening. The other half of the Isaac look after the dark floor:
// it pulls the eye to the middle of the room, hides the hard rectangle where
// the wall tiles stop, and makes bright toys pop off a dim surround.
//
// Kept to plain smoothstep maths so it runs under the gl_compatibility
// renderer this project targets.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
// Where the darkening starts and where it reaches full. Both are in units of
// "half-diagonals from centre", so 1.0 is roughly the corner.
uniform float inner : hint_range(0.0, 1.5) = 0.55;
uniform float outer : hint_range(0.0, 2.0) = 1.15;
uniform vec3 tint : source_color = vec3(0.02, 0.01, 0.04);
// The room is 640x384, so circular falloff would darken the left and right
// walls far more than the top and bottom. Squashing x keeps it even.
uniform float aspect = 1.667;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= aspect;
	float d = length(p) * 2.0 / aspect;
	float v = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(tint, v);
}
