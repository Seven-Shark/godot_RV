shader_type canvas_item;

// 告诉 Godot 我们需要读取屏幕背景纹理
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- 可调参数 (Uniforms) ---
// 震荡波的当前半径进度 (0.0 = 中心, 1.0 = 边缘) - 我们将在代码里用 Tween 动画控制这个值
uniform float radius_progress : hint_range(0.0, 1.0) = 0.0;

// 震荡波环的厚度 (0.0 - 0.5)
uniform float thickness : hint_range(0.0, 0.5) = 0.1;

// 扭曲力度 (值越大，背景扭曲越严重)
uniform float force : hint_range(0.0, 0.5) = 0.05;

// 边缘柔化程度
uniform float softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	// 1. 计算当前像素到 ColorRect 中心的距离 (UV坐标系，中心是 vec2(0.5, 0.5))
	vec2 center = vec2(0.5, 0.5);
	float dist_to_center = distance(UV, center);

	// 2. 创建圆环面罩 (Ring Mask)
	// 我们利用 smoothstep 创建两个圆，一个大一个小，相减得到一个圆环
	// 随着 radius_progress 从 0 到 1，这个圆环会向外扩散
	float current_radius_outer = radius_progress * (0.5 + thickness); // 外圈半径
	float current_radius_inner = current_radius_outer - thickness;    // 内圈半径

	// 使用 smoothstep 进行边缘柔化，计算当前像素是否在圆环内
	float mask_outer = smoothstep(current_radius_outer, current_radius_outer - softness, dist_to_center);
	float mask_inner = smoothstep(current_radius_inner - softness, current_radius_inner, dist_to_center);

	// 最终的圆环强度 (0.0 表示不在圆环上，1.0 表示在圆环中心)
	float ring_mask = mask_outer * mask_inner;

	// 3. 计算扭曲向量
	// 计算从中心指向当前像素的方向向量
	vec2 displacement_dir = normalize(UV - center);

	// 最终偏移量 = 方向 * 圆环强度 * 总力度
	// 我们要偏移的是屏幕纹理的 UV (SCREEN_UV)
	vec2 displaced_screen_uv = SCREEN_UV - displacement_dir * ring_mask * force;

	// 4. 读取偏移后的屏幕颜色并输出
	COLOR = texture(SCREEN_TEXTURE, displaced_screen_uv);

	// 可选：随着扩散淡出整个效果，防止边缘出现硬切口
	// 如果进度接近 1.0，则降低整体透明度
	COLOR.a *= smoothstep(1.0, 0.8, radius_progress);
}