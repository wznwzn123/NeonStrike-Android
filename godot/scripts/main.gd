extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/fps_player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")

var player: FPSPlayer
var enemies: Array[NeonEnemy] = []
var enemies_left := 0
var health_label: Label
var ammo_label: Label
var status_label: Label
var hud: CanvasLayer
var joystick_origin := Vector2.ZERO
var joystick_touch := -1
var pause_layer: Control
var settings_layer: Control
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var master_volume := 0.65
var game_paused := false
var game_over := false

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _create_environment()
    _create_arena()
    _create_player()
    _create_enemies(3)
    _create_audio()
    _create_hud()
    _update_status("清理区域内的敌人")

func _create_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.018, 0.028, 0.048)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.52, 0.68)
    environment.ambient_light_energy = 0.65
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.0
    sun.shadow_enabled = false
    add_child(sun)

func _make_box(parent: Node3D, position: Vector3, size: Vector3, color: Color, collision := true) -> void:
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.25
    material.roughness = 0.75
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    if collision:
        var body := StaticBody3D.new()
        body.position = position
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        parent.add_child(body)

func _create_arena() -> void:
    _make_box(self, Vector3(0, -0.3, 0), Vector3(48, 0.6, 48), Color(0.075, 0.095, 0.12))
    var wall_color := Color(0.12, 0.16, 0.21)
    _make_box(self, Vector3(0, 2.0, -24), Vector3(48, 4, 0.7), wall_color)
    _make_box(self, Vector3(0, 2.0, 24), Vector3(48, 4, 0.7), wall_color)
    _make_box(self, Vector3(-24, 2.0, 0), Vector3(0.7, 4, 48), wall_color)
    _make_box(self, Vector3(24, 2.0, 0), Vector3(0.7, 4, 48), wall_color)
    var cover := Color(0.19, 0.24, 0.29)
    _make_box(self, Vector3(-8, 0.85, -5), Vector3(5, 1.7, 1.2), cover)
    _make_box(self, Vector3(7, 0.85, -9), Vector3(1.3, 1.7, 5), cover)
    _make_box(self, Vector3(0, 0.75, 5), Vector3(6, 1.5, 1.1), cover)
    _make_box(self, Vector3(12, 0.8, 8), Vector3(3.2, 1.6, 1.2), cover)
    _make_box(self, Vector3(-13, 0.8, 10), Vector3(1.2, 1.6, 4.5), cover)

func _create_player() -> void:
    player = PLAYER_SCRIPT.new()
    player.position = Vector3(0, 0.2, 17)
    add_child(player)
    player.health_changed.connect(_on_health_changed)
    player.ammo_changed.connect(_on_ammo_changed)
    player.eliminated.connect(_on_player_eliminated)
    player.shot_fired.connect(_play_shot)
    player.reload_finished.connect(_play_reload)

func _create_enemies(count: int) -> void:
    var positions := [
        Vector3(-13, 0.2, -14), Vector3(12, 0.2, -15), Vector3(15, 0.2, 2)
    ]
    for i in range(count):
        var enemy: NeonEnemy = ENEMY_SCRIPT.new()
        enemy.position = positions[i % positions.size()]
        enemy.target = player
        add_child(enemy)
        enemy.died.connect(_on_enemy_died)
        enemies.append(enemy)
        enemies_left += 1

func _create_audio() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.name = "AmbientMusic"
    music_player.volume_db = -24.0
    music_player.stream = _make_tone(92.0, 2.0, 0.035, true)
    add_child(music_player)
    music_player.play()
    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SoundEffects"
    add_child(sfx_player)

func _make_tone(frequency: float, duration: float, amplitude: float, looping: bool = false) -> AudioStreamWAV:
    const sample_rate := 22050
    var sample_count := int(sample_rate * duration)
    var bytes := PackedByteArray()
    bytes.resize(sample_count * 2)
    for i in range(sample_count):
        var t := float(i) / sample_rate
        var envelope := 1.0
        if not looping:
            envelope = minf(1.0, t * 35.0) * pow(maxf(0.0, 1.0 - t / duration), 1.8)
        var wave := sin(TAU * frequency * t) * amplitude * envelope
        bytes.encode_s16(i * 2, int(clampf(wave, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = bytes
    if looping:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = sample_count
    return stream

func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
    if sfx_player == null:
        return
    sfx_player.stop()
    sfx_player.stream = _make_tone(frequency, duration, amplitude)
    sfx_player.play()

func _play_shot() -> void:
    _play_tone(145.0, 0.12, 0.24)

func _play_reload() -> void:
    _play_tone(620.0, 0.18, 0.12)

func _create_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(root)
    health_label = _label(root, "生命 100", Vector2(28, 24), 24, Color(0.35, 0.95, 0.85))
    ammo_label = _label(root, "弹药 30 / 120", Vector2(28, 58), 20, Color.WHITE)
    status_label = _label(root, "清理区域内的敌人", Vector2.ZERO, 22, Color(0.55, 0.88, 1.0))
    status_label.anchor_left = 0.5
    status_label.anchor_right = 0.5
    status_label.position = Vector2(-160, 24)
    status_label.size.x = 320
    var crosshair := _label(root, "+", Vector2.ZERO, 30, Color(0.3, 0.95, 1.0))
    crosshair.anchor_left = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.position = Vector2(-9, -21)
    crosshair.size = Vector2(20, 40)
    _make_touch_button(root, "开火", Vector2(-150, -150), Vector2(112, 88), "fire")
    _make_touch_button(root, "换弹", Vector2(-270, -105), Vector2(92, 64), "reload")
    _make_touch_button(root, "跳跃", Vector2(-145, -55), Vector2(92, 64), "jump")
    var pause_button := _make_touch_button(root, "暂停", Vector2(-125, 24), Vector2(100, 58), "pause")
    pause_button.anchor_top = 0.0
    pause_button.anchor_bottom = 0.0
    pause_button.position.y = 24
    _build_pause_menu(root)

func _label(parent: Control, value: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = pos
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _make_touch_button(parent: Control, caption: String, offset: Vector2, button_size: Vector2, action: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.size = button_size
    button.anchor_left = 1.0
    button.anchor_top = 1.0
    button.anchor_right = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.modulate = Color(0.35, 0.85, 1.0, 0.88)
    parent.add_child(button)
    if action == "fire":
        button.button_down.connect(func(): player.mobile_fire = true)
        button.button_up.connect(func(): player.mobile_fire = false)
    elif action == "reload":
        button.pressed.connect(player.reload)
    elif action == "jump":
        button.pressed.connect(player.request_jump)
    elif action == "pause":
        button.pressed.connect(_show_pause_menu)
    return button

func _build_pause_menu(root: Control) -> void:
    pause_layer = Control.new()
    pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_layer.visible = false
    pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(pause_layer)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.025, 0.045, 0.88)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_layer.add_child(shade)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-210, -190)
    panel.size = Vector2(420, 380)
    pause_layer.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)
    var heading := Label.new()
    heading.text = "NEON STRIKE"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 28)
    column.add_child(heading)
    var resume := Button.new()
    resume.text = "继续游戏"
    resume.pressed.connect(_resume_game)
    column.add_child(resume)
    var settings := Button.new()
    settings.text = "设置"
    settings.pressed.connect(_show_settings)
    column.add_child(settings)
    var restart := Button.new()
    restart.text = "重新开始"
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    column.add_child(restart)
    var exit_button := Button.new()
    exit_button.text = "返回标题（重启本局）"
    exit_button.pressed.connect(func(): get_tree().reload_current_scene())
    column.add_child(exit_button)
    settings_layer = Control.new()
    settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_layer.visible = false
    settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_layer.add_child(settings_layer)
    var settings_shade := ColorRect.new()
    settings_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_shade.color = Color(0.01, 0.02, 0.04, 0.96)
    settings_layer.add_child(settings_shade)
    var settings_panel := PanelContainer.new()
    settings_panel.set_anchors_preset(Control.PRESET_CENTER)
    settings_panel.position = Vector2(-230, -190)
    settings_panel.size = Vector2(460, 380)
    settings_layer.add_child(settings_panel)
    var settings_column := VBoxContainer.new()
    settings_column.add_theme_constant_override("separation", 18)
    settings_panel.add_child(settings_column)
    var settings_title := Label.new()
    settings_title.text = "游戏设置"
    settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    settings_title.add_theme_font_size_override("font_size", 26)
    settings_column.add_child(settings_title)
    var volume_label := Label.new()
    volume_label.text = "主音量"
    settings_column.add_child(volume_label)
    var volume_slider := HSlider.new()
    volume_slider.min_value = 0.0
    volume_slider.max_value = 1.0
    volume_slider.step = 0.05
    volume_slider.value = master_volume
    volume_slider.value_changed.connect(_set_volume)
    settings_column.add_child(volume_slider)
    var sensitivity_label := Label.new()
    sensitivity_label.text = "触屏视角灵敏度"
    settings_column.add_child(sensitivity_label)
    var sensitivity_slider := HSlider.new()
    sensitivity_slider.min_value = 0.001
    sensitivity_slider.max_value = 0.009
    sensitivity_slider.step = 0.0005
    sensitivity_slider.value = player.touch_sensitivity
    sensitivity_slider.value_changed.connect(func(value: float): player.touch_sensitivity = value)
    settings_column.add_child(sensitivity_slider)
    var quality := CheckButton.new()
    quality.text = "开启阴影（较耗性能）"
    quality.button_pressed = false
    quality.toggled.connect(_set_shadows)
    settings_column.add_child(quality)
    var back := Button.new()
    back.text = "返回暂停菜单"
    back.pressed.connect(func(): settings_layer.visible = false)
    settings_column.add_child(back)

func _set_volume(value: float) -> void:
    master_volume = value
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))

func _set_shadows(enabled: bool) -> void:
    for child in get_children():
        if child is DirectionalLight3D:
            child.shadow_enabled = enabled

func _show_pause_menu() -> void:
    if game_over:
        return
    game_paused = true
    player.mobile_fire = false
    player.set_process(false)
    player.set_physics_process(false)
    for enemy in enemies:
        if is_instance_valid(enemy):
            enemy.set_physics_process(false)
    pause_layer.visible = true
    settings_layer.visible = false

func _show_settings() -> void:
    settings_layer.visible = true

func _resume_game() -> void:
    pause_layer.visible = false
    settings_layer.visible = false
    game_paused = false
    if not game_over:
        player.set_process(true)
        player.set_physics_process(true)
        for enemy in enemies:
            if is_instance_valid(enemy):
                enemy.set_physics_process(true)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not OS.has_feature("mobile"):
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if game_paused:
            _resume_game()
        else:
            _show_pause_menu()
    if event is InputEventScreenTouch:
        var w := get_viewport().get_visible_rect().size.x
        if event.pressed and event.position.x < w * 0.36 and joystick_touch == -1:
            joystick_touch = event.index
            joystick_origin = event.position
        elif not event.pressed and event.index == joystick_touch:
            joystick_touch = -1
            player.mobile_move = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        var drag_delta: Vector2 = (event.position - joystick_origin) / 70.0
        player.mobile_move = Vector2(clampf(drag_delta.x, -1, 1), clampf(drag_delta.y, -1, 1))

func _on_health_changed(value: int) -> void:
    if is_instance_valid(health_label):
        health_label.text = "生命 %d" % value

func _on_ammo_changed(current: int, reserve: int) -> void:
    if is_instance_valid(ammo_label):
        ammo_label.text = "弹药 %d / %d" % [current, reserve]

func _on_enemy_died() -> void:
    enemies_left -= 1
    if enemies_left <= 0:
        _update_status("区域已清理 · 任务完成")
        _show_end_menu("任务完成")

func _on_player_eliminated() -> void:
    game_over = true
    player.mobile_fire = false
    for enemy in enemies:
        if is_instance_valid(enemy):
            enemy.set_physics_process(false)
    _update_status("任务失败 · 玩家已阵亡")
    _show_end_menu("任务失败")

func _show_end_menu(title_text: String) -> void:
    game_over = true
    player.set_process(false)
    player.set_physics_process(false)
    pause_layer.visible = true
    settings_layer.visible = false
    var panel := pause_layer.get_child(1).get_child(0) as PanelContainer
    var column := panel.get_child(0) as VBoxContainer
    var heading := column.get_child(0) as Label
    heading.text = title_text
    (column.get_child(1) as Button).text = "重新开始"
    (column.get_child(1) as Button).pressed.disconnect(_resume_game)
    (column.get_child(1) as Button).pressed.connect(func(): get_tree().reload_current_scene())

func _update_status(value: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = value
