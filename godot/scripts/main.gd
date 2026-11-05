extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/fps_player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")

var player: FPSPlayer
var enemies_left := 0
var health_label: Label
var ammo_label: Label
var status_label: Label
var hud: CanvasLayer
var joystick_origin := Vector2.ZERO
var joystick_touch := -1

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _create_environment()
    _create_arena()
    _create_player()
    _create_enemies(5)
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
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

func _make_box(parent: Node3D, position: Vector3, size: Vector3, color: Color, collision := true) -> void:
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.35
    material.roughness = 0.68
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

func _create_enemies(count: int) -> void:
    var positions := [
        Vector3(-13, 0.2, -14), Vector3(12, 0.2, -15),
        Vector3(15, 0.2, 2), Vector3(-14, 0.2, 3),
        Vector3(2, 0.2, -19)
    ]
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

    health_label = _label(root, "生命 100", Vector2(28, 24), 24, Color(0.35, 0.95, 0.85))
    ammo_label = _label(root, "弹药 30 / 120", Vector2(28, 58), 20, Color.WHITE)
    status_label = _label(root, "清理区域内的敌人", Vector2(0, 24), 22, Color(0.55, 0.88, 1.0))
    status_label.anchor_left = 0.5
    status_label.anchor_right = 0.5
    status_label.position.x = -150
    status_label.size.x = 300

    var crosshair := _label(root, "+", Vector2(0, 0), 30, Color(0.3, 0.95, 1.0))
    crosshair.anchor_left = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.position = Vector2(-9, -21)
    crosshair.size = Vector2(20, 40)

    _make_touch_button(root, "开火", Vector2(-150, -150), Vector2(112, 88), "fire")
    _make_touch_button(root, "换弹", Vector2(-270, -105), Vector2(92, 64), "reload")
    _make_touch_button(root, "跳跃", Vector2(-145, -55), Vector2(92, 64), "jump")

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
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.modulate = Color(0.35, 0.85, 1.0, 0.82)
    parent.add_child(button)
    if action == "fire":
        button.button_down.connect(func(): player.mobile_fire = true)
        button.button_up.connect(func(): player.mobile_fire = false)
    elif action == "reload":
        button.pressed.connect(player.reload)
    elif action == "jump":
        button.pressed.connect(func(): Input.action_press("jump"))

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not OS.has_feature("mobile"):
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventScreenTouch:
        var w := get_viewport().get_visible_rect().size.x
        if event.pressed and event.position.x < w * 0.36 and joystick_touch == -1:
            joystick_touch = event.index
            joystick_origin = event.position
        elif not event.pressed and event.index == joystick_touch:
            joystick_touch = -1
            player.mobile_move = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        var delta := (event.position - joystick_origin) / 70.0
        player.mobile_move = Vector2(clampf(delta.x, -1, 1), clampf(delta.y, -1, 1))

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

func _on_player_eliminated() -> void:
    _update_status("任务失败 · 玩家已阵亡")

func _update_status(value: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = value
