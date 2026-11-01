shader_type spatial;
// Chiazza di luce dell'Occhio sul tabellone: cerchio sfumato, additivo, che pulsa piano.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform float intensita = 0.45;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = (1.0 - smoothstep(0.35, 1.0, d)) * (0.85 + 0.15 * sin(TIME * 1.6));
	ALBEDO = colore.rgb * intensita * a;
}
