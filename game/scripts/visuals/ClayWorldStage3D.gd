class_name ClayWorldStage3D
extends Node3D
# ===========================================================================
# NEXUS — ClayWorldStage3D
# ---------------------------------------------------------------------------
# ویترینِ سه‌بعدیِ سبک برای صفحه‌ی آغاز: چند Mesh ساده، یک دوربین ارتوگرافیک،
# نور گرم و متریالِ خمیریِ rough. هیچ متن/تصویرِ پخته‌شده‌ای در این صحنه نیست؛
# UI واقعی روی آن می‌نشیند و بازی همچنان بدون شبکه و بدون SDK بیرونی می‌ماند.
# سقفِ صحنه عمداً کم است: چند جزیره، چند کره و دو نور؛ تا روی گوشی میان‌رده
# battery/fill-rate را نخورَد. این همان «3D first, dressed after blockout» است.
# ===========================================================================

const CLAY_SHADER_PATH := "res://assets/shaders/clay_surface.gdshader"

@export var animate: bool = true
@export var theme_color: Color = Palette.AELORIA_GOLD

var _time: float = 0.0
var _floaters: Array[Node3D] = []
var _floater_origins: Array[Vector3] = []
var _floater_phases: Array[float] = []
var _floater_speeds: Array[float] = []
var _shader: Shader = null


func _ready() -> void:
	_shader = ResourceLoader.load(CLAY_SHADER_PATH) as Shader
	_build_world()
	set_process(animate)


func _process(delta: float) -> void:
	if not animate:
		return
	_time = fmod(_time + delta, TAU * 100.0)
	for i: int in _floaters.size():
		var node: Node3D = _floaters[i]
		if not is_instance_valid(node):
			continue
		var origin: Vector3 = _floater_origins[i]
		node.position = origin + Vector3(0.0,
			sin(_time * _floater_speeds[i] + _floater_phases[i]) * 0.10, 0.0)
		node.rotation.y += delta * 0.08


func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "ClayEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.DEEP_INDIGO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.CLOUD_WHITE
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env_node.environment = env
	add_child(env_node)

	var camera := Camera3D.new()
	camera.name = "ClayCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.8
	camera.position = Vector3(0.0, 3.9, 10.4)
	camera.current = true
	add_child(camera)
	# Camera باید داخل tree باشد تا basis/transform معتبر شود؛ این متد هم خطای
	# «Node not inside tree» را حذف می‌کند و هم جهت را در یک نقطه‌ی قطعی می‌سازد.
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.8, 0.0), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.name = "WarmKey"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Palette.AELORIA_GOLD
	sun.light_energy = 1.38
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "TealFill"
	fill.rotation_degrees = Vector3(-28.0, 150.0, 0.0)
	fill.light_color = Palette.SOFT_TEAL
	fill.light_energy = 0.36
	fill.shadow_enabled = false
	add_child(fill)

	_build_islands()
	_build_balance_landmark()
	_build_orbs()
	_build_clouds()


func _build_islands() -> void:
	_add_sphere("IslandBack", Vector3(-2.7, 0.10, 0.65), Vector3(2.65, 0.46, 1.50),
		Palette.STONE_GREY.darkened(0.18), 0.22, 0.0)
	_add_sphere("IslandMain", Vector3(0.0, -0.18, 0.0), Vector3(4.1, 0.63, 2.08),
		Palette.SOFT_TEAL.darkened(0.08), 0.34, 0.8)
	_add_sphere("IslandRight", Vector3(2.75, 0.22, 0.95), Vector3(2.10, 0.42, 1.22),
		Palette.GHOST_VIOLET.darkened(0.08), 0.20, 1.4)
	# لایه‌ی زیرینِ جزیره‌ی اصلی حسِ گلِ شکل‌گرفته و عمقِ واقعی می‌دهد.
	_add_sphere("IslandUnderside", Vector3(0.0, -0.74, 0.12), Vector3(2.75, 0.40, 1.42),
		Palette.DEEP_INDIGO.lightened(0.14), 0.18, 2.2)


func _build_balance_landmark() -> void:
	var post := _add_cylinder("BalancePost", Vector3(0.0, 0.40, 0.0),
		Vector3(0.27, 1.30, 0.27), Palette.STONE_GREY, 0.028, 0.2)
	var cap := _add_sphere("BalanceCap", Vector3(0.0, 1.72, 0.0), Vector3(0.46, 0.20, 0.46),
		Palette.AELORIA_GOLD, 0.02, 0.0)
	var beam := _add_box("BalanceBeam", Vector3(0.0, 1.75, 0.0),
		Vector3(3.5, 0.16, 0.24), Palette.AELORIA_GOLD, 0.02)
	# نخ‌های آویز؛ بار اصلی روی جزئیات کم‌تعداد و خوانا است.
	for x: float in [-1.22, 1.22]:
		_add_cylinder("Rope", Vector3(x, 1.22, 0.0), Vector3(0.035, 0.75, 0.035),
			Palette.CLOUD_WHITE, 0.0, 0.0)
		_add_sphere("Dish", Vector3(x, 0.72, 0.0), Vector3(0.84, 0.10, 0.58),
			Palette.WARM_CORAL if x > 0.0 else Palette.SOFT_TEAL, 0.03, 0.0)
	if post != null:
		post.rotation.z = 0.0
	if cap != null:
		cap.rotation.z = 0.0
	if beam != null:
		beam.rotation.z = 0.0


func _build_orbs() -> void:
	var specs: Array[Dictionary] = [
		{"pos": Vector3(-1.65, 1.05, 0.0), "scale": 0.34, "color": Palette.SOFT_TEAL, "phase": 0.2},
		{"pos": Vector3(-0.82, 1.16, -0.12), "scale": 0.42, "color": Palette.AELORIA_GOLD, "phase": 1.0},
		{"pos": Vector3(0.86, 1.15, -0.10), "scale": 0.50, "color": Palette.AELORIA_GOLD, "phase": 1.8},
		{"pos": Vector3(1.72, 1.04, 0.02), "scale": 0.30, "color": Palette.GHOST_VIOLET, "phase": 2.5},
	]
	for spec: Dictionary in specs:
		var orb := _add_sphere("LearningOrb", spec["pos"] as Vector3,
			Vector3.ONE * float(spec["scale"]), spec["color"] as Color, 0.035,
			float(spec["phase"]))
		if orb != null:
			orb.set_meta("learnable_orb", true)


func _build_clouds() -> void:
	for i: int in 3:
		var cloud := _add_sphere("Cloud", Vector3(-3.6 + float(i) * 3.1,
			3.6 + float(i % 2) * 0.34, -0.9), Vector3(0.95, 0.18, 0.42),
			Palette.CLOUD_WHITE, 0.01, float(i) * 1.4)
		if cloud != null:
			cloud.modulate = Color(1.0, 1.0, 1.0, 0.20)


func _material(color: Color, wobble: float) -> Material:
	if _shader != null:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = _shader
		shader_material.set_shader_parameter("base_color", color)
		shader_material.set_shader_parameter("wobble_strength", wobble)
		shader_material.set_shader_parameter("roughness_value", 0.78)
		return shader_material
	var standard := StandardMaterial3D.new()
	standard.albedo_color = color
	standard.roughness = 0.78
	standard.metallic = 0.0
	return standard


func _add_sphere(name: String, at: Vector3, scale_value: Vector3, color: Color,
		wobble: float, phase: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = at
	node.scale = scale_value
	node.material_override = _material(color, wobble)
	add_child(node)
	_register_floater(node, phase)
	return node


func _add_cylinder(name: String, at: Vector3, scale_value: Vector3, color: Color,
		wobble: float, phase: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.08
	mesh.height = 2.0
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = at
	node.scale = scale_value
	node.material_override = _material(color, wobble)
	add_child(node)
	_register_floater(node, phase)
	return node


func _add_box(name: String, at: Vector3, size: Vector3, color: Color,
		wobble: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color, wobble)
	add_child(node)
	return node


func _register_floater(node: Node3D, phase: float) -> void:
	_floaters.append(node)
	_floater_origins.append(node.position)
	_floater_phases.append(phase)
	_floater_speeds.append(0.72 + fmod(absf(phase), 1.0) * 0.24)
