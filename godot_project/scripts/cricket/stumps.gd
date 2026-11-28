class_name Stumps
extends Node3D
## Three stumps + two bails. Held still until the wicket is broken, then
## they become free physics bodies (Jolt) and fly / topple realistically.

const STUMP_R := 0.0175
const BAIL_LEN := 0.11

var stumps: Array[RigidBody3D] = []
var bails: Array[RigidBody3D] = []
var broken := false


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("f3e6c8")
	wood.roughness = 0.45
	var band := StandardMaterial3D.new()
	band.albedo_color = Color("1a98c9")
	for x in CricketField.STUMP_X:
		var rb := _body(0.3)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = STUMP_R
		cyl.height = CricketField.STUMP_H
		cs.shape = cyl
		cs.position.y = CricketField.STUMP_H * 0.5
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = STUMP_R
		cm.bottom_radius = STUMP_R
		cm.height = CricketField.STUMP_H
		cm.radial_segments = 16
		mi.mesh = cm
		mi.material_override = wood
		mi.position.y = CricketField.STUMP_H * 0.5
		rb.add_child(mi)
		var deco := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = STUMP_R + 0.001
		dm.bottom_radius = STUMP_R + 0.001
		dm.height = 0.12
		deco.mesh = dm
		deco.material_override = band
		deco.position.y = CricketField.STUMP_H - 0.2
		rb.add_child(deco)
		rb.set_meta("home", Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
		add_child(rb)
		stumps.append(rb)
	for k in 2:
		var bx: float = (CricketField.STUMP_X[k] + CricketField.STUMP_X[k + 1]) * 0.5
		var rb := _body(0.06)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.008
		cyl.height = BAIL_LEN
		cs.shape = cyl
		cs.rotation.z = PI * 0.5
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		cm.height = BAIL_LEN
		mi.mesh = cm
		mi.material_override = wood
		mi.rotation.z = PI * 0.5
		rb.add_child(mi)
		rb.set_meta("home", Transform3D(Basis.IDENTITY, Vector3(bx, CricketField.STUMP_H + 0.009, 0)))
		add_child(rb)
		bails.append(rb)
	reset()


func _body(m: float) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = m
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.35
	rb.physics_material_override = pm
	return rb


func reset() -> void:
	broken = false
	for b in stumps + bails:
		b.freeze = true
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.transform = b.get_meta("home")


## World-space stump axes (bottom points) for ball collision tests.
func stump_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in CricketField.STUMP_X:
		out.append(global_transform * Vector3(x, 0, 0))
	return out


## Break the wicket: hit point and the velocity of whatever hit it.
func break_wicket(hit: Vector3, vel: Vector3, mass := 0.16) -> void:
	if broken:
		return
	broken = true
	for b in stumps + bails:
		b.freeze = false
	var impulse := vel * mass * 1.4
	var nearest: RigidBody3D = stumps[0]
	for s in stumps:
		if s.global_position.distance_to(hit) < nearest.global_position.distance_to(hit):
			nearest = s
	nearest.apply_impulse(impulse, hit - nearest.global_position)
	for s in stumps:
		if s != nearest:
			s.apply_impulse(impulse * 0.25, hit - s.global_position)
	for b in bails:
		var up := Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.1), 0) * clampf(vel.length() * 0.012, 0.03, 0.18)
		b.apply_impulse(impulse * 0.12 + up)
		b.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	Sfx.pin_hit(clampf(vel.length() / 25.0, 0.4, 1.0))
