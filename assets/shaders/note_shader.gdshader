shader_type spatial;
render_mode unshaded;

global uniform float elapsed_time;
global uniform float approach_time;
global uniform float spawn_distance;
global uniform float vanish_distance;

instance uniform float note_time;
instance uniform lowp vec3 note_color;

varying float alpha;

void vertex() {
	
	float time_til_hit = note_time-elapsed_time;
	float note_lerp = time_til_hit/approach_time;
	float new_pos = spawn_distance*note_lerp;
	
	alpha = new_pos<vanish_distance ? 0.0 : 1.0;
	
	VERTEX.z+=new_pos;
}

void fragment() {
	ALBEDO = note_color;
	ALPHA = alpha;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
