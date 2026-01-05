shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- 基础参数 ---
uniform float radius_progress : hint_range(0.0, 1.0) = 0.0; // 扩散进度
uniform float thickness : hint_range(0.0, 0.5) = 0.1;       // 波纹厚度
uniform float force : hint_range(0.0, 0.5) = 0.05;          // 扭曲力度
uniform float softness : hint_range(0.0, 0.5) = 0.05;       // 边缘柔化

// --- 形状控制 ---
// 扇形角度限制 (度数)，例如 90.0 表示前方 90 度扇形。设为 360.0 则为全圆
uniform float sector_angle_degrees : hint_range(0.0, 360.0) = 90.0;

// 形状偏移：如果你的贴图朝向不对，可以通过这个修正 (弧度)
uniform float rotation_offset_radians = 0.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv_centered = UV - center;

	// 1. 计算距离 (Radius)
	float dist_to_center = length(uv_centered);

	// 2. 计算角度 (Angle)
	// 默认 Godot 的 0 度是向右 (Vector2(1, 0))
	float angle = atan(uv_centered.y, uv_centered.x) + rotation_offset_radians;

	// 【修复点】：直接使用内置的 PI 常量，不再重复定义
	if (angle > PI) angle -= 2.0 * PI;
	if (angle < -PI) angle += 2.0 * PI;

	// 3. 角度裁剪 (Sector Mask)
	float half_sector_rad = radians(sector_angle_degrees) / 2.0;

	// 计算角度遮罩：如果在扇形范围内则为 1.0，否则为 0.0
	float angle_mask = 1.0 - step(half_sector_rad, abs(angle));

	// 4. 圆环扩散逻辑
	float current_radius_outer = radius_progress * 0.5;
	float current_radius_inner = current_radius_outer - thickness;

	float mask_outer = smoothstep(current_radius_outer, current_radius_outer - softness, dist_to_center);
	float mask_inner = smoothstep(current_radius_inner - softness, current_radius_inner, dist_to_center);
	float ring_mask = mask_outer * mask_inner;

	// 5. 最终遮罩
	float final_mask = ring_mask * angle_mask;

	// 6. 应用扭曲
	vec2 displacement_dir = normalize(uv_centered);
	vec2 displaced_screen_uv = SCREEN_UV - displacement_dir * final_mask * force;

	COLOR = texture(SCREEN_TEXTURE, displaced_screen_uv);

	// 淡出处理
	COLOR.a *= smoothstep(1.0, 0.8, radius_progress) * angle_mask;
}