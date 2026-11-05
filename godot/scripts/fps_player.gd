extends CharacterBody3D
class_name FPSPlayer

signal health_changed(value: int)
signal ammo_changed(current: int, reserve: int)
signal eliminated

@export var move_speed := 5.4
@export var mouse_sensitivity := 0.0022
@export var touch_sensitivity := 0.004
@export var max_health := 100
@export var magazine_size := 30
@export var fire_rate := 0.16
@export var damage := 45
@export var reload_seconds := 1.35

var health := 100
var ammo := 30
var reserve_ammo := 120
var is_reloading := false
var fire_cooldown := 0.0
var look_delta := Vector2.ZERO
var mobile_move := Vector2.ZERO
var mobile_fire := false
var jump_requested := false
var gravity := 18.0
var camera: Camera3D
var muzzle: MeshInstance3D
var eliminated_state := false
var audio: Node

func _ready() -> void:
    health = max_health
    ammo = magazine_size
    audio = get_parent().get_node_or_null("NeonAudio")
    _build_body()
    _build_input()
    ammo_changed.emit(ammo, reserve_ammo)
    health_changed.emit(health)

func _build_body() -> void:
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.58, 0)
    camera.fov = 82.0
    camera.current = true
    add_child(camera)
    var gun := MeshInstance3D.new()
    var gun_mesh := BoxMesh.new()
    gun_mesh.size = Vector3(0.18, 0.16, 0.62)
    gun.mesh = gun_mesh
    gun.position = Vector3(0.28, -0.24, -0.48)
    var gun_mat := StandardMaterial3D.new()
    gun_mat.albedo_color = Color(0.08, 0.13, 0.18)
    gun_mat.metallic = 0.8
    gun_mat.roughness = 0.28
    gun.material_override = gun_mat
    camera.add_child(gun)
    muzzle = MeshInstance3D.new()
    var flash := SphereMesh.new()
    flash.radius = 0.055
    flash.height = 0.11
    muzzle.mesh = flash
    muzzle.position = Vector3(0.28, -0.24, -0.82)
    var flash_mat := StandardMaterial3D.new()
    flash_mat.albedo_color = Color(0.2, 0.9, 1.0)
    flash_mat.emission_enabled = true
    flash_mat.emission = Color(0.1, 0.75, 1.0)
    muzzle.material_override = flash_mat
    muzzle.visible = false
    camera.add_child(muzzle)

func _build_input() -> void:
    _add_action("move_forward", [KEY_W, KEY_UP])
    _add_action("move_back", [KEY_S, KEY_DOWN])
    _add_action("move_left", [KEY_A, KEY_LEFT])
    _add_action("move_right", [KEY_D, KEY_RIGHT])
    _add_action("fire", [])
    var mouse_fire := InputEventMouseButton.new()
    mouse_fire.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("fire", mouse_fire)
    _add_action("reload", [KEY_R])
    _add_action("jump", [KEY_SPACE])

func _add_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for keycode in keys:
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
    if eliminated_state or get_tree().paused:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        look_delta -= event.relative * mouse_sensitivity
    elif event is InputEventScreenDrag:
        var width := get_viewport().get_visible_rect().size.x
        if event.position.x > width * 0.38:
            look_delta -= event.relative * touch_sensitivity
    elif event is InputEventScreenTouch and event.pressed:
        if event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
            look_delta = Vector2.ZERO

func _process(delta: float) -> void:
    if eliminated_state:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    muzzle.visible = fire_cooldown > fire_rate * 0.58
    if Input.is_action_just_pressed("reload"):
        reload()
    if (Input.is_action_pressed("fire") or mobile_fire) and fire_cooldown <= 0.0:
        shoot()

func _physics_process(delta: float) -> void:
    if eliminated_state:
        return
    rotate_y(look_delta.x)
    camera.rotation.x = clampf(camera.rotation.x + look_delta.y, deg_to_rad(-78), deg_to_rad(78))
    look_delta = Vector2.ZERO
    var input_dir := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
    )
    if mobile_move.length() > 0.08:
        input_dir = mobile_move
    input_dir = input_dir.limit_length(1.0)
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump") or jump_requested:
        velocity.y = 5.2
        jump_requested = false
    velocity.x = move_toward(velocity.x, direction.x * move_speed, 22.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * move_speed, 22.0 * delta)
    move_and_slide()

func request_jump() -> void:
    if not eliminated_state:
        jump_requested = true

func shoot() -> void:
    if eliminated_state or is_reloading or get_tree().paused:
        return
    if ammo <= 0:
        reload()
        return
    ammo -= 1
    fire_cooldown = fire_rate
    ammo_changed.emit(ammo, reserve_ammo)
    if is_instance_valid(audio):
        audio.play_effect("fire")
    var query := PhysicsRayQueryParameters3D.create(
        camera.global_position,
        camera.global_position - camera.global_basis.z * 90.0
    )
    query.exclude = [get_rid()]
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var target: Object = hit.collider
        if target.has_method("take_damage"):
            target.take_damage(damage)
            if is_instance_valid(audio):
                audio.play_effect("hit")

func reload() -> void:
    if eliminated_state or is_reloading or ammo == magazine_size or reserve_ammo <= 0:
        return
    is_reloading = true
    if is_instance_valid(audio):
        audio.play_effect("reload")
    await get_tree().create_timer(reload_seconds).timeout
    if not is_inside_tree() or eliminated_state:
        return
    var needed := magazine_size - ammo
    var loaded := mini(needed, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded
    is_reloading = false
    ammo_changed.emit(ammo, reserve_ammo)

func take_damage(amount: int) -> void:
    if eliminated_state or get_tree().paused:
        return
    health = maxi(0, health - amount)
    if is_instance_valid(audio):
        audio.play_effect("hurt")
    health_changed.emit(health)
    if health <= 0:
        eliminated_state = true
        mobile_fire = false
        mobile_move = Vector2.ZERO
        eliminated.emit()
        set_physics_process(false)
        set_process(false)
