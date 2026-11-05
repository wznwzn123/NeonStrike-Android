extends CharacterBody3D
class_name NeonEnemy

signal died

@export var max_health := 100
@export var move_speed := 2.15
@export var attack_range := 2.15
@export var attack_damage := 5
@export var attack_interval := 1.65

var health := 100
var target: Node3D
var attack_timer := 0.0
var gravity := 18.0
var body_mesh: MeshInstance3D

func _ready() -> void:
    health = max_health
    _build_enemy()

func _build_enemy() -> void:
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.75
    collision.shape = capsule
    collision.position.y = 0.88
    add_child(collision)
    body_mesh = MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.4
    mesh.height = 1.7
    body_mesh.mesh = mesh
    body_mesh.position.y = 0.88
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.55, 0.08, 0.14)
    material.metallic = 0.45
    material.roughness = 0.48
    material.emission_enabled = true
    material.emission = Color(0.16, 0.012, 0.025)
    body_mesh.material_override = material
    add_child(body_mesh)
    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.16
    core_mesh.height = 0.32
    core.mesh = core_mesh
    core.position = Vector3(0, 1.0, -0.34)
    var core_mat := StandardMaterial3D.new()
    core_mat.albedo_color = Color(1.0, 0.12, 0.2)
    core_mat.emission_enabled = true
    core_mat.emission = Color(0.8, 0.02, 0.05)
    core.material_override = core_mat
    add_child(core)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(target) or not target.is_inside_tree():
        velocity = Vector3.ZERO
        return
    if get_tree().paused:
        return
    attack_timer = maxf(0.0, attack_timer - delta)
    var to_target := target.global_position - global_position
    to_target.y = 0.0
    var distance := to_target.length()
    if distance > attack_range:
        var direction := to_target.normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        if direction.length() > 0.1:
            look_at(global_position + direction, Vector3.UP)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
        if attack_timer <= 0.0 and target.has_method("take_damage"):
            target.take_damage(attack_damage)
            attack_timer = attack_interval
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    move_and_slide()

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health = maxi(0, health - amount)
    if health <= 0:
        died.emit()
        queue_free()
