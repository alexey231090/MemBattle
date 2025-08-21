shader_type spatial;
render_mode unshaded, blend_add;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.0, 1.0); // Оранжевый цвет
uniform float intensity : hint_range(0.0, 2.0) = 1.5;
uniform float pulse_speed : hint_range(1.0, 10.0) = 5.0;
uniform float trail_length : hint_range(0.1, 2.0) = 0.8;
uniform float head_size : hint_range(0.1, 1.0) = 0.3;

void fragment() {
    // Пульсация для эффекта энергии
    float pulse = sin(TIME * pulse_speed) * 0.2 + 0.8;

    // Создаем эффект хвоста, который сужается к задней части
    float uv_y = UV.y; // Используем Y координату для создания хвоста
    float trail = 1.0 - smoothstep(0.0, 1.0, uv_y);
    trail = pow(trail, trail_length);

    // Создаем яркую головную часть выстрела
    float head = 1.0 - smoothstep(0.0, head_size, uv_y);

    // Комбинируем хвост и голову
    float combined = max(trail, head * pulse);

    // Добавляем немного шума для более органичного вида
    float noise = texture(noise_texture, UV * 15.0 + TIME * 1.0).r * 0.1;

    vec3 emission = color.rgb * intensity * (combined + noise);
    EMISSION = emission;
    ALBEDO = color.rgb;
    ALPHA = color.a * combined;
}