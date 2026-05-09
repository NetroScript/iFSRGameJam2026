shader_type canvas_item;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(0.08, 0.10, 0.14, 1.0);

uniform float grain_strength : hint_range(0.0, 0.2) = 0.025;
uniform float medium_strength : hint_range(0.0, 0.5) = 0.06;
uniform float large_strength : hint_range(0.0, 0.5) = 0.10;

uniform float grain_scale = 1.0;
uniform float medium_scale = 0.018;
uniform float large_scale = 0.004;

uniform vec3 shadow_tint : source_color = vec3(0.85, 0.90, 1.0);
uniform vec3 highlight_tint : source_color = vec3(1.08, 1.04, 0.96);

uniform bool show_grid_data = false;
uniform bool use_pheromone_texture = false;
uniform sampler2D grid_data_texture : filter_nearest, repeat_disable;
uniform vec4 grid_world_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform ivec2 grid_resolution = ivec2(1, 1);
uniform vec2 grid_cell_size = vec2(1.0, 1.0);
uniform int grid_field_count = 2;
uniform float grid_timestamp_ms = 0.0;
uniform float grid_phero_max = 30000.0;
uniform float grid_data_strength : hint_range(0.0, 1.0) = 0.70;
uniform bool grid_data_color_full_cells = false;

varying vec2 world_pos;

void vertex() {
	// World-space 2D position of this CanvasItem vertex.
	// Interpolated across the surface in fragment().
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(a, b, u.x),
		mix(c, d, u.x),
		u.y
	);
}

// 2D simplex noise by Ian McEwan, Ashima Arts style.
vec3 mod289(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
	return mod289(((x * 34.0) + 1.0) * x);
}

float simplex_noise(vec2 v) {
	const vec4 C = vec4(
		0.211324865405187,  // (3.0 - sqrt(3.0)) / 6.0
		0.366025403784439,  // 0.5 * (sqrt(3.0) - 1.0)
		-0.577350269189626, // -1.0 + 2.0 * C.x
		0.024390243902439   // 1.0 / 41.0
	);

	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);

	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;

	i = mod289(i);
	vec3 p = permute(
		permute(i.y + vec3(0.0, i1.y, 1.0))
		+ i.x + vec3(0.0, i1.x, 1.0)
	);

	vec3 m = max(
		0.5 - vec3(
			dot(x0, x0),
			dot(x12.xy, x12.xy),
			dot(x12.zw, x12.zw)
		),
		0.0
	);

	m = m * m;
	m = m * m;

	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;

	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.y = a0.y * x12.x + h.y * x12.y;
	g.z = a0.z * x12.z + h.z * x12.w;

	return 130.0 * dot(m, g);
}

// Fractal Brownian Motion using simplex noise.
float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < 5; i++) {
		total += amplitude * simplex_noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return total;
}

float read_grid_field(ivec2 cell, int field) {
	ivec2 texture_size = textureSize(grid_data_texture, 0);
	float texel_x = (float(cell.x) + 0.5) / float(texture_size.x);
	float texel_y = (float(cell.y * grid_field_count + field) + 0.5) / float(texture_size.y);
	return texture(grid_data_texture, vec2(texel_x, texel_y)).r;
}

vec3 grid_data_cell_color(ivec2 cell) {
	ivec2 clamped_cell = clamp(cell, ivec2(0), grid_resolution - ivec2(1));
	float home_phero_stamp = read_grid_field(clamped_cell, 0);
	float food_phero_stamp = read_grid_field(clamped_cell, 1);

	float home_phero = clamp((grid_phero_max - (grid_timestamp_ms - home_phero_stamp)) / grid_phero_max, 0.0, 1.0);
	float food_phero = clamp((grid_phero_max - (grid_timestamp_ms - food_phero_stamp)) / grid_phero_max, 0.0, 1.0);

	return vec3(food_phero, 0.0, home_phero);
}

vec3 grid_data_color(vec2 p, bool smooth_cells) {
	vec2 grid_uv = (p - grid_world_rect.xy) / max(grid_world_rect.zw, vec2(0.0001));
	if (grid_uv.x < 0.0 || grid_uv.y < 0.0 || grid_uv.x >= 1.0 || grid_uv.y >= 1.0) {
		return vec3(0.0);
	}

	vec2 grid_pos = grid_uv * vec2(grid_resolution);
	if (!smooth_cells) {
		return grid_data_cell_color(ivec2(floor(grid_pos)));
	}

	vec2 centered_grid_pos = grid_pos - vec2(0.5);
	ivec2 cell_min = ivec2(floor(centered_grid_pos));
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(centered_grid_pos));

	vec3 top = mix(
		grid_data_cell_color(cell_min),
		grid_data_cell_color(cell_min + ivec2(1, 0)),
		blend.x
	);
	vec3 bottom = mix(
		grid_data_cell_color(cell_min + ivec2(0, 1)),
		grid_data_cell_color(cell_min + ivec2(1, 1)),
		blend.x
	);
	return mix(top, bottom, blend.y);
}

float grid_data_realistic_alpha(vec2 p, vec3 grid_color) {
	float strength = max(grid_color.r, grid_color.b);
	float large_variation = fbm(p * 0.012);
	float medium_variation = value_noise(p * 0.045);
	float fine_variation = hash21(floor(p * 0.18));
	float deposit_mask = smoothstep(
		0.16,
		0.84,
		large_variation * 0.55 + medium_variation * 0.35 + fine_variation * 0.10
	);
	return clamp(strength * grid_data_strength * mix(0.35, 1.35, deposit_mask), 0.0, 1.0);
}

void fragment() {
	vec2 p = world_pos;

	// Fine, pixel-locked grain.
	float grain = hash21(floor(p * grain_scale));
	grain = grain - 0.5;

	// Medium cloudy variation.
	float medium = value_noise(p * medium_scale);
	medium = medium - 0.5;

	// Large simplex/fBm structures.
	float large = fbm(p * large_scale);

	// Optional soft contrast shaping for larger structures.
	large = tanh(large * 1.4);

	float combined =
		grain * grain_strength +
		medium * medium_strength +
		large * large_strength;

	// Slight color temperature shift:
	// darker areas become cooler, lighter areas become warmer.
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(-0.15, 0.15, combined));

	vec3 color = base_color.rgb * tint + combined;
	if (show_grid_data && use_pheromone_texture) {
		vec3 grid_color = grid_data_color(p, !grid_data_color_full_cells);
		float grid_alpha;
		if (grid_data_color_full_cells) {
			grid_alpha = clamp(max(max(grid_color.r, grid_color.g), grid_color.b) * grid_data_strength, 0.0, 1.0);
		} else {
			grid_alpha = grid_data_realistic_alpha(p, grid_color);
		}
		color = mix(color, grid_color, grid_alpha);
	}

	COLOR = vec4(clamp(color, 0.0, 1.0), base_color.a);
}
