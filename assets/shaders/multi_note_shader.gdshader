shader_type spatial;
render_mode unshaded;

global uniform float elapsed_time;
global uniform float approach_time;
global uniform float spawn_distance;
global uniform float vanish_distance;

varying flat lowp int alpha;
varying lowp vec3 color;

void vertex() {
	color = INSTANCE_CUSTOM.rgb;
	
	float time_til_hit = INSTANCE_CUSTOM.a-elapsed_time;
	float note_lerp = time_til_hit/approach_time;
	float new_pos = spawn_distance*note_lerp;
	
	alpha = new_pos<vanish_distance ? 1 : 0;
	
	VERTEX.z+=new_pos;
}

void fragment() {
	ALBEDO = color;
	if (alpha==1) {
		ALPHA = 0.0;
	}
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
