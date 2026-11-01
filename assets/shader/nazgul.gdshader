shader_type spatial;
// Bestia alata del Nazgûl: le ali battono ruotando attorno all'asse del corpo.
uniform vec4 colore : source_color = vec4(0.13, 0.12, 0.14, 1.0);
uniform float fase = 0.0;
uniform float velocita = 3.2;
uniform float ampiezza = 0.45;
uniform float zs = -0.25;     // linea delle spalle (asse z)
uniform float ys = 0.36;
uniform float mostra_peso = 0.0;
varying float peso;

void vertex() {
	vec3 v = VERTEX;
	float d = v.z - zs;
	float lato = sign(d);
	// solo le ali: lontano dalle spalle, davanti alla coda
	float w;
	if (d > 0.0) {
		// ala alzata (lato +z)
		w = smoothstep(0.12, 0.55, d) * (1.0 - smoothstep(0.05, 0.3, v.x)) * smoothstep(0.08, 0.2, v.y + 0.25);
	} else {
		// ala abbassata (lato -z), oltre la coda
		w = 0.6 * smoothstep(0.3, 0.5, -d) * smoothstep(-0.1, 0.15, v.x);
	}
	peso = w;
	float a = sin(TIME * velocita + fase) * ampiezza * w * lato;
	vec2 p = vec2(v.z - zs, v.y - ys);
	float c = cos(a), s = sin(a);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	v.z = p.x + zs;
	v.y = p.y + ys;
	VERTEX = v;
}

void fragment() {
	ALBEDO = mix(colore.rgb, vec3(1.0, 0.1, 0.1), peso * mostra_peso);
	METALLIC = 0.35;
	ROUGHNESS = 0.45;
	RIM = 0.4;
}
