shader_type spatial;

varying float visibility;

uniform vec3 albedo: source_color;

uniform vec4 max_tint_color: source_color = vec4(0.0, 0.0, 0.0, 0.867);

uniform float metallic: hint_range(0.0, 1.0) = 0.5;

void vertex() {
	visibility = INSTANCE_CUSTOM.x;
}

void fragment() {
	float blend = max_tint_color.a * (1.0 - visibility);
	
	ALBEDO = albedo * (1.0 - blend) + max_tint_color.rgb * (blend);
	METALLIC = metallic;
}
