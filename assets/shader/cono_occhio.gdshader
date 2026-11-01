shader_type spatial;
// Cono di luce soffusa sotto l'Occhio di Sauron: additivo, sfumato verso il basso e sui bordi.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float intensita = 1.1;
varying float h;

void vertex() {
	h = VERTEX.y / 3.1 + 0.5;   // 0 in basso, 1 in alto
}

void fragment() {
	float bordi = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.9);
	float alto = 0.3 + 0.7 * smoothstep(0.0, 0.9, h);
	float pulsa = 0.85 + 0.15 * sin(TIME * 1.6);
	ALBEDO = colore.rgb * intensita * bordi * alto * pulsa;
}
