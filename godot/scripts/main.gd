extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/fps_player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const AUDIO_SCRIPT = preload("res://scripts/audio_manager.gd")

var player: FPSPlayer
var audio: NeonAudio
var enemies_left := 0
var health_label: Label
var ammo_label: Label
var status_label: Label
var hud: CanvasLayer
var overlay_layer: CanvasLayer
var overlay_root: Control
var joystick_origin := Vector2.ZERO
var joystick_touch := -1
var game_ended := false
var settings := {"music": true, "sfx": true, "volume": 0.75, "sensitivity": 0.004}

func _ready() -> void:
    _load_settings()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    audio = AUDIO_SCRIPT.new()
    audio.name = "NeonAudio"
    add_child(audio)
    audio.set_music_enabled(settings.music)
    audio.set_sfx_enabled(settings.sfx)
    audio.set_master_volume(settings.volume)
    _create_environment()
    _create_arena()
    _create_player()
    _create_enemies(3)
    _create_hud()
    _update_status("清理区域内的敌人")

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://settings.cfg") == OK:
        settings.music = config.get_value("audio", "music", true)
        settings.sfx = config.get_value("audio", "sfx", true)
        settings.volume = config.get_value("audio", "volume", 0.75)
        settings.sensitivity = config.get_value("controls", "sensitivity", 0.004)

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "music", settings.music)
    config.set_value("audio", "sfx", settings.sfx)
    config.set_value("audio", "volume", settings.volume)
    config.set_value("controls", "sensitivity", settings.sensitivity)
    config.save("user://settings.cfg")

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
    material.roughness = 0.72
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
    player.touch_sensitivity = settings.sensitivity
    add_child(player)
    player.health_changed.connect(_on_health_changed)
    player.ammo_changed.connect(_on_ammo_changed)
    player.eliminated.connect(_on_player_eliminated)

func _create_enemies(count: int) -> void:
    var positions := [Vector3(-13, 0.2, -14), Vector3(12, 0.2, -15), Vector3(15, 0.2, 2)]
    for i in range(count):
        var enemy: NeonEnemy = ENEMY_SCRIPT.new()
        enemy.position = positions[i % positions.size()]
        enemy.target = player
        add_child(enemy)
        enemy.died.connect(_on_enemy_died)
        enemies_left += 1

func _create_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(root)
    health_label = _label(root, "生命 100", Vector2(24, 18), 22, Color(0.35, 0.95, 0.85))
    ammo_label = _label(root, "弹药 30 / 120", Vector2(24, 48), 19, Color.WHITE)
    status_label = _label(root, "清理区域内的敌人", Vector2.ZERO, 20, Color(0.55, 0.88, 1.0))
    status_label.anchor_left = 0.5
    status_label.anchor_right = 0.5
    status_label.position = Vector2(-170, 18)
    status_label.size = Vector2(340, 32)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var crosshair := _label(root, "+", Vector2.ZERO, 30, Color(0.3, 0.95, 1.0))
    crosshair.anchor_left = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.position = Vector2(-9, -21)
    crosshair.size = Vector2(20, 40)
    _make_touch_button(root, "开火", Vector2(-142, -142), Vector2(112, 88), "fire")
    _make_touch_button(root, "换弹", Vector2(-260, -100), Vector2(92, 64), "reload")
    _make_touch_button(root, "跳跃", Vector2(-142, -48), Vector2(92, 64), "jump")
    var pause_button := Button.new()
    pause_button.text = "Ⅱ"
    pause_button.anchor_left = 1.0
    pause_button.anchor_right = 1.0
    pause_button.position = Vector2(-72, 18)
    pause_button.size = Vector2(54, 48)
    pause_button.pressed.connect(_show_pause_menu)
    root.add_child(pause_button)
    _create_overlay()

func _create_overlay() -> void:
    overlay_layer = CanvasLayer.new()
    overlay_layer.layer = 10
    overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(overlay_layer)
    overlay_root = Control.new()
    overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.visible = false
    overlay_layer.add_child(overlay_root)

func _label(parent: Control, value: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = pos
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _make_touch_button(parent: Control, caption: String, offset: Vector2, button_size: Vector2, action: String) -> void:
    var button := Button.new()
    button.text = caption
    button.size = button_size
    button.anchor_left = 1.0
    button.anchor_top = 1.0
    button.anchor_right = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 21)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.modulate = Color(0.35, 0.85, 1.0, 0.82)
    parent.add_child(button)
    if action == "fire":
        button.button_down.connect(func(): player.mobile_fire = true)
        button.button_up.connect(func(): player.mobile_fire = false)
    elif action == "reload":
        button.pressed.connect(func(): player.reload(); audio.play_effect("reload"))
    elif action == "jump":
        button.pressed.connect(player.request_jump)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if get_tree().paused:
            _resume_game()
        else:
            _show_pause_menu()
    if event is InputEventScreenTouch:
        var w := get_viewport().get_visible_rect().size.x
        if event.pressed and event.position.x < w * 0.34 and joystick_touch == -1 and not get_tree().paused:
            joystick_touch = event.index
            joystick_origin = event.position
        elif not event.pressed and event.index == joystick_touch:
            joystick_touch = -1
            if is_instance_valid(player):
                player.mobile_move = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch and is_instance_valid(player):
        var drag_delta: Vector2 = (event.position - joystick_origin) / 62.0
        player.mobile_move = Vector2(clampf(drag_delta.x, -1, 1), clampf(drag_delta.y, -1, 1))

func _show_pause_menu() -> void:
    if game_ended:
        return
    get_tree().paused = true
    _show_panel("游戏暂停", "继续战斗", true)

func _show_game_over(won: bool) -> void:
    game_ended = true
    get_tree().paused = true
    _show_panel("任务完成" if won else "任务失败", "重新开始", false)

func _show_panel(heading: String, primary_text: String, can_resume: bool) -> void:
    for child in overlay_root.get_children():
        child.queue_free()
    overlay_root.visible = true
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.025, 0.045, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.add_child(shade)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -210
    panel.offset_top = -190
    panel.offset_right = 210
    panel.offset_bottom = 190
    overlay_root.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)
    var title := Label.new()
    title.text = heading
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    column.add_child(title)
    var primary_action: Callable = Callable(self, "_resume_game")
    if not can_resume:
        primary_action = Callable(self, "_restart_game")
    _add_menu_button(column, primary_text, primary_action)
    if can_resume:
        _add_menu_button(column, "设置", _show_settings)
        _add_menu_button(column, "返回游戏", _resume_game)
    else:
        _add_menu_button(column, "设置", _show_settings)
        _add_menu_button(column, "退出到标题", _restart_game)

func _add_menu_button(parent: VBoxContainer, caption: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 48)
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(callback)
    parent.add_child(button)

func _show_settings() -> void:
    for child in overlay_root.get_children():
        child.queue_free()
    overlay_root.visible = true
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.025, 0.045, 0.9)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.add_child(shade)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -230
    panel.offset_top = -215
    panel.offset_right = 230
    panel.offset_bottom = 215
    overlay_root.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)
    var title := Label.new()
    title.text = "设置"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    column.add_child(title)
    var music_toggle := CheckButton.new()
    music_toggle.text = "背景音乐"
    music_toggle.button_pressed = settings.music
    music_toggle.toggled.connect(func(value: bool):
        settings.music = value
        audio.set_music_enabled(value)
        _save_settings()
    )
    column.add_child(music_toggle)
    var sfx_toggle := CheckButton.new()
    sfx_toggle.text = "音效"
    sfx_toggle.button_pressed = settings.sfx
    sfx_toggle.toggled.connect(func(value: bool):
        settings.sfx = value
        audio.set_sfx_enabled(value)
        _save_settings()
    )
    column.add_child(sfx_toggle)
    var volume_label := Label.new()
    volume_label.text = "总音量"
    column.add_child(volume_label)
    var volume := HSlider.new()
    volume.min_value = 0.0
    volume.max_value = 1.0
    volume.step = 0.05
    volume.value = settings.volume
    volume.value_changed.connect(func(value: float):
        settings.volume = value
        audio.set_master_volume(value)
        _save_settings()
    )
    column.add_child(volume)
    var sensitivity_label := Label.new()
    sensitivity_label.text = "触控视角灵敏度"
    column.add_child(sensitivity_label)
    var sensitivity := HSlider.new()
    sensitivity.min_value = 0.001
    sensitivity.max_value = 0.009
    sensitivity.step = 0.0005
    sensitivity.value = settings.sensitivity
    sensitivity.value_changed.connect(func(value: float):
        settings.sensitivity = value
        player.touch_sensitivity = value
        _save_settings()
    )
    column.add_child(sensitivity)
    _add_menu_button(column, "返回", _return_from_settings)

func _return_from_settings() -> void:
    if game_ended:
        _show_panel("任务失败" if player.health <= 0 else "任务完成", "重新开始", false)
    else:
        _show_panel("游戏暂停", "继续战斗", true)

func _resume_game() -> void:
    overlay_root.visible = false
    get_tree().paused = false
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart_game() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_health_changed(value: int) -> void:
    if is_instance_valid(health_label):
        health_label.text = "生命 %d" % value

func _on_ammo_changed(current: int, reserve: int) -> void:
    if is_instance_valid(ammo_label):
        ammo_label.text = "弹药 %d / %d" % [current, reserve]

func _on_enemy_died() -> void:
    enemies_left -= 1
    if enemies_left <= 0 and not game_ended:
        _update_status("区域已清理 · 任务完成")
        _show_game_over(true)

func _on_player_eliminated() -> void:
    if game_ended:
        return
    _update_status("任务失败 · 玩家已阵亡")
    _show_game_over(false)

func _update_status(value: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = value
