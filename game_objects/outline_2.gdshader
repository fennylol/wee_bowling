// https://godotshaders.com/shader/the-simplest-outline-shader-via-material/
shader_type spatial;
render_mode blend_mix, cull_front, unshaded;

uniform vec4 color : source_color = vec4(1,0,0,1);
uniform float width : hint_range(0.0, 0.1, 0.001) = 0.0125;

void vertex() {
	VERTEX += normalize(VERTEX) * width;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
