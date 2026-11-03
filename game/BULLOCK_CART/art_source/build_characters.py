"""
Bullock-cart character art pipeline for Godot 4.
Run with:  blender --background --python build_characters.py

Outputs (in assets/characters/):
  bullock_white.glb        — ivory-white ox pair  (player default)
  bullock_brown.glb        — dark-brown ox pair   (rival Amber)
  bullock_black.glb        — near-black ox pair   (rival Indigo)
  bullock_grey.glb         — dappled grey ox pair
  bullock_amber.glb        — golden amber ox pair
  bullock_rigged.glb       — kept for backward compat (= white)
  driver_rigged.glb        — driver, blue kurta
  driver_rigged_checked.glb— driver, checked tunic
  cart_body.glb            — wooden cart with spoked wheels and yoke

All meshes are Godot-ready: Y-up, metric scale, baked PBR textures.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT  = ROOT / 'assets' / 'characters'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = {}

# ── Coordinate helpers ────────────────────────────────────────────────────
# Script uses game convention (x right, y up, z forward); V() → Blender axes.
def V(p): return Vector((p[0], -p[2], p[1]))

# ── Scene / mesh primitives ───────────────────────────────────────────────

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for a in list(bpy.data.actions): bpy.data.actions.remove(a)

def mat(name, color, rough=.7, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value  = rough
    p.inputs['Metallic'].default_value   = metallic
    m.diffuse_color = (*color, 1)
    return m

def sphere(name, center, radius, material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=V(center))
    o = bpy.context.object
    o.name = name
    o.scale = (radius[0], radius[2], radius[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material: o.data.materials.append(material)
    for face in o.data.polygons: face.use_smooth = True
    return o

def box(name, center, half, material=None):
    """Axis-aligned box. half = (hx, hy, hz) in game coords."""
    bpy.ops.mesh.primitive_cube_add(location=V(center))
    o = bpy.context.object
    o.name = name
    o.scale = (half[0], half[2], half[1])
    bpy.ops.object.transform_apply(scale=True)
    if material: o.data.materials.append(material)
    return o

def tube(name, points, radii, material, sides=12):
    pts = [V(p) for p in points]
    vertices, faces = [], []
    for i, point in enumerate(pts):
        direction = (pts[min(i+1,len(pts)-1)] - pts[max(i-1,0)]).normalized()
        ref = Vector((1,0,0)) if abs(direction.x) < .9 else Vector((0,1,0))
        a = direction.cross(ref).normalized()
        b = direction.cross(a).normalized()
        for j in range(sides):
            theta = j * math.tau / sides
            vertices.append(point + radii[i] * (math.cos(theta)*a + math.sin(theta)*b))
        if i:
            for j in range(sides):
                n = i*sides+j
                faces.append((n, i*sides+(j+1)%sides, (i-1)*sides+(j+1)%sides, n-sides))
    faces += [tuple(reversed(range(sides))), tuple((len(pts)-1)*sides+j for j in range(sides))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    for face in o.data.polygons: face.use_smooth = True
    return o

def sculpt(parts, name, material, voxel=.028):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    r = o.modifiers.new('Continuous sculpt surface', 'REMESH')
    r.mode = 'VOXEL'; r.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=r.name)
    s = o.modifiers.new('Smooth anatomical joins', 'SMOOTH')
    s.factor = .85; s.iterations = 5
    bpy.ops.object.modifier_apply(modifier=s.name)
    d = o.modifiers.new('Game topology reduction', 'DECIMATE')
    d.ratio = .55
    bpy.ops.object.modifier_apply(modifier=d.name)
    o.data.materials.clear()
    o.data.materials.append(material)
    for face in o.data.polygons: face.use_smooth = True
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

def texture_mesh(o, material, name, low, high, checked=False):
    """Bake a deterministic coat/cloth pigment texture onto a UV atlas."""
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value  = 145
    noise.inputs['Detail'].default_value = 3
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*low,  1)
    ramp.color_ramp.elements[1].color = (*high, 1)
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    shader = nodes.get('Principled BSDF')
    links.new(ramp.outputs['Color'], shader.inputs['Base Color'])
    if checked:
        chk = nodes.new('ShaderNodeTexChecker')
        chk.inputs['Scale'].default_value  = 9
        chk.inputs['Color1'].default_value = (*low,  1)
        chk.inputs['Color2'].default_value = (*high, 1)
        links.new(chk.outputs['Color'], shader.inputs['Base Color'])
    image = bpy.data.images.new(name, width=1024, height=1024)
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = image
    nodes.active = tex
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 1
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 8
    bpy.ops.object.bake(type='DIFFUSE')
    image.filepath_raw = str(OUT / (name + '.png'))
    image.file_format  = 'PNG'; image.save()
    links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    image.pack()
    fine = nodes.new('ShaderNodeTexNoise')
    fine.inputs['Scale'].default_value  = 220
    fine.inputs['Detail'].default_value = 2
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value  = .18
    bump.inputs['Distance'].default_value  = .003
    links.new(fine.outputs['Fac'],   bump.inputs['Height'])
    links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    ni = bpy.data.images.new(name+'_normal', width=1024, height=1024)
    ni.colorspace_settings.name = 'Non-Color'
    nt = nodes.new('ShaderNodeTexImage'); nt.image = ni; nodes.active = nt
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')
    ni.filepath_raw = str(OUT / (name+'_normal.png'))
    ni.file_format  = 'PNG'; ni.save(); ni.pack()
    nm = nodes.new('ShaderNodeNormalMap')
    links.new(nt.outputs['Color'],   nm.inputs['Color'])
    links.new(nm.outputs['Normal'],  shader.inputs['Normal'])

def rig(name, specs):
    data = bpy.data.armatures.new(name)
    o    = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone_name, head, tail, parent in specs:
        b = data.edit_bones.new(bone_name)
        b.head, b.tail = V(head), V(tail)
        if parent: b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return o

def bind(o, armature, weights):
    groups = {b.name: o.vertex_groups.new(name=b.name) for b in armature.data.bones}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        coord = (p.x, p.z, -p.y)
        for name, weight in weights(coord):
            if weight > 0: groups[name].add([v.index], weight, 'REPLACE')
    mod = o.modifiers.new('Skin deformation', 'ARMATURE')
    mod.object = armature
    o.parent = armature

def rigid(o, armature, bone): bind(o, armature, lambda p: [(bone, 1)])

def animate(armature, name, poses, frames=32):
    armature.animation_data_create()
    if armature.animation_data.action:
        armature.animation_data.action.use_fake_user = True
    armature.animation_data.action = None
    for frame in range(frames+1):
        theta     = frame / frames * math.tau
        pose_data = poses(theta)
        rotations, locations = pose_data if isinstance(pose_data, tuple) else (pose_data, {})
        for bone_name, angles in rotations.items():
            b = armature.pose.bones[bone_name]
            b.rotation_mode = 'XYZ'
            b.rotation_euler = angles
            b.keyframe_insert('rotation_euler', frame=frame+1)
        for bone_name, offset in locations.items():
            b = armature.pose.bones[bone_name]
            b.location = b.bone.matrix_local.to_3x3().inverted() @ V(offset)
            b.keyframe_insert('location', frame=frame+1)
    action = armature.animation_data.action
    action.name = name; action.use_fake_user = True
    for b in armature.pose.bones:
        b.rotation_euler = (0, 0, 0); b.location = (0, 0, 0)
    bpy.context.scene.frame_start  = 1
    bpy.context.scene.frame_end    = frames + 1
    bpy.context.scene.render.fps   = 30
    bpy.context.scene.frame_set(1)

def export(name, armature):
    path = OUT / (name + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source'/(name+'.blend')))
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB',
        export_animations=True,  export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_range=True,
        export_skins=True, export_yup=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    REPORT[name] = {
        'vertices':   sum(len(o.data.vertices) for o in meshes),
        'triangles':  sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
        'bones':      len(armature.data.bones),
        'bytes':      path.stat().st_size,
        'animations': [a.name for a in bpy.data.actions],
    }

def export_static(name):
    """Export entire scene as a static (no armature) GLB."""
    path = OUT / (name + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source'/(name+'.blend')))
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB',
        export_animations=False, export_skins=False, export_yup=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    REPORT[name] = {
        'vertices':   sum(len(o.data.vertices) for o in meshes),
        'triangles':  sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
        'bones':      0,
        'bytes':      path.stat().st_size,
        'animations': [],
    }

# ── Wheel builder ─────────────────────────────────────────────────────────

def build_wheel(prefix, cx, cy, cz, radius, mat_wood, mat_iron, n_spokes=10):
    """
    One spoked wooden wheel.  Axle runs along X; disk lies in the YZ plane.
    Returns list of all created objects for inclusion in scene.
    """
    N   = 30     # rim segments
    RIM = 0.026  # rim tube radius

    # Closed rim ring
    rim_pts = [(cx, cy + radius*math.cos(i*math.tau/N),
                    cz + radius*math.sin(i*math.tau/N)) for i in range(N+1)]
    rim = tube(prefix+'_rim', rim_pts, [RIM]*(N+1), mat_wood, sides=10)

    # Hub — slightly flattened sphere (squashed along X/axle direction)
    hub = sphere(prefix+'_hub', (cx, cy, cz), (0.072, 0.072, 0.042), mat_iron)

    # Spokes
    objs = [rim, hub]
    for i in range(n_spokes):
        a   = i * math.tau / n_spokes
        rpt = (cx, cy + radius*math.cos(a), cz + radius*math.sin(a))
        objs.append(tube(prefix+'_sp'+str(i), [(cx,cy,cz), rpt],
                         [0.018, 0.011], mat_wood, sides=6))

    # Iron tyre strip (thin outer ring slightly over rim)
    tyre_pts = [(cx, cy + (radius+0.008)*math.cos(i*math.tau/N),
                     cz + (radius+0.008)*math.sin(i*math.tau/N)) for i in range(N+1)]
    objs.append(tube(prefix+'_tyre', tyre_pts, [0.014]*(N+1), mat_iron, sides=8))

    return objs

# ── CART BODY ─────────────────────────────────────────────────────────────

def cart_body():
    """
    Wooden bullock cart.  Origin = ground-level centre under bed midpoint.

    Layout (game coords — x lateral, y up, z rearward):
      Wheel centres:  front z=-0.05,  rear z=1.25,  height y=0.33
      Bed top:        y=0.70
      Driver seat:    z=0.22,  y=0.78
      Yoke tip:       z=-1.85  (toward bulls)
    """
    clear()

    # ── Materials ─────────────────────────────────────────────────────────
    teak    = mat('Teak planks',        (.25,.14,.06), rough=.82)
    frame   = mat('Dark wood frame',    (.14,.08,.03), rough=.88)
    iron    = mat('Iron fittings',      (.11,.10,.09), rough=.55, metallic=.80)
    rope    = mat('Hemp rope',          (.54,.42,.27), rough=.90)
    cushion = mat('Red cloth cushion',  (.40,.045,.02),rough=.75)
    brass   = mat('Brass nail heads',   (.50,.29,.06), rough=.28, metallic=.72)
    paint   = mat('Painted side band',  (.55,.09,.04), rough=.65)   # red decorative

    # Cart geometry constants
    WR       = 0.33   # wheel radius
    WCY      = WR     # wheel centre y (sits on ground)
    FZ, RZ   = -0.05, 1.25   # front/rear axle z
    AXLE_X   = 0.70   # axle half-width (wheel outer face)
    BED_Y    = 0.68   # bed top surface y
    BED_HX   = 0.54   # bed half-width
    RAIL_X   = 0.56   # side-rail x position

    # ── Axles ─────────────────────────────────────────────────────────────
    for z, lbl in [(FZ,'front'),(RZ,'rear')]:
        tube('Axle_'+lbl, [(-AXLE_X-0.02, WCY, z),(AXLE_X+0.02, WCY, z)],
             [0.030, 0.030], iron, sides=10)

    # ── Four wheels ───────────────────────────────────────────────────────
    for z in [FZ, RZ]:
        for x in [-AXLE_X, AXLE_X]:
            lbl = ('f' if z==FZ else 'r') + ('L' if x<0 else 'R')
            build_wheel('Wh_'+lbl, x, WCY, z, WR, teak, iron)
            # Hubcap on outer face
            cx_cap = x + (0.055 if x>0 else -0.055)
            sphere('Cap_'+lbl, (cx_cap, WCY, z), (0.044,0.044,0.022), iron)

    # ── Axle saddles (blocks linking axle to bed frame) ───────────────────
    for z in [FZ, RZ]:
        for x in [-0.44, 0.44]:
            box('Saddle_'+str(z)+'_'+str(x),
                (x, (WCY + BED_Y)*0.5, z),
                (0.048, (BED_Y - WCY)*0.5 + 0.015, 0.065), frame)

    # ── Longitudinal bed rails ────────────────────────────────────────────
    for x in [-BED_HX+0.04, BED_HX-0.04]:
        tube('BRail_'+('L' if x<0 else 'R'),
             [(x, BED_Y, FZ-0.06), (x, BED_Y, RZ+0.06)],
             [0.040, 0.040], frame, sides=8)

    # ── Transverse cross-beams underneath bed ─────────────────────────────
    for z_cb in [0.10, 0.60, 1.10]:
        tube('Xbeam_'+str(z_cb),
             [(-BED_HX, BED_Y-0.04, z_cb), (BED_HX, BED_Y-0.04, z_cb)],
             [0.035, 0.035], frame, sides=8)

    # ── Bed planks (6 transverse boards) ─────────────────────────────────
    for i, z_plank in enumerate([0.08, 0.30, 0.52, 0.74, 0.96, 1.18]):
        box('Plank_'+str(i), (0, BED_Y+0.028, z_plank),
            (BED_HX, 0.024, 0.095), teak)

    # ── Decorative painted band along both sides ──────────────────────────
    for x in [-(BED_HX+0.01), (BED_HX+0.01)]:
        box('SideBand_'+('L' if x<0 else 'R'),
            (x, BED_Y+0.022, (FZ+RZ)*0.5),
            (0.012, 0.035, (RZ-FZ)*0.5+0.06), paint)

    # ── Side fence rails ──────────────────────────────────────────────────
    FENCE_Y = BED_Y + 0.22
    for x in [-RAIL_X, RAIL_X]:
        tube('SRail_'+('L' if x<0 else 'R'),
             [(x, FENCE_Y, FZ+0.06), (x, FENCE_Y, RZ-0.06)],
             [0.020, 0.020], frame, sides=8)
        # Four fence posts
        for z_post in [0.18, 0.52, 0.86, 1.18]:
            tube('Post_'+str(x)+'_'+str(z_post),
                 [(x, BED_Y+0.01, z_post), (x, FENCE_Y, z_post)],
                 [0.016, 0.016], frame, sides=6)

    # Brass nail heads along fence rail
    for x in [-RAIL_X, RAIL_X]:
        for z_nail in [0.18, 0.52, 0.86, 1.18]:
            sphere('Nail_'+str(x)+'_'+str(z_nail),
                   (x, FENCE_Y+0.005, z_nail), (0.011,0.011,0.007), brass)

    # ── Rear tail board ───────────────────────────────────────────────────
    box('TailBoard', (0, BED_Y+0.10, RZ+0.06), (BED_HX, 0.092, 0.020), frame)

    # ── Driver's seat platform ────────────────────────────────────────────
    box('Seat_platform', (0, BED_Y+0.06, 0.22), (BED_HX-0.02, 0.042, 0.22), teak)
    box('Seat_cushion',  (0, BED_Y+0.112, 0.22), (BED_HX-0.05, 0.028, 0.19), cushion)
    # Seat back rest (small vertical plank)
    box('Seat_back',     (0, BED_Y+0.17, 0.44), (BED_HX-0.05, 0.10, 0.018), frame)

    # ── Footrest bar at driver's feet ─────────────────────────────────────
    tube('Footrest',
         [(-BED_HX+0.08, BED_Y+0.01, FZ+0.16), (BED_HX-0.08, BED_Y+0.01, FZ+0.16)],
         [0.018, 0.018], iron, sides=8)

    # ── Central yoke pole (from front of cart toward bulls) ───────────────
    tube('Yoke_pole',
         [(0, BED_Y-0.04, FZ),
          (0, BED_Y-0.06, -0.55),
          (0, BED_Y-0.12, -1.05),
          (0, BED_Y-0.18, -1.42)],
         [0.040, 0.036, 0.032, 0.028], frame, sides=10)

    # Yoke crossbar at bull-neck level
    tube('Yoke_crossbar',
         [(-0.58, BED_Y-0.12, -1.48), (0, BED_Y-0.12, -1.48), (0.58, BED_Y-0.12, -1.48)],
         [0.022, 0.022, 0.022], frame, sides=8)

    # Yoke prongs (fork that straddles each bull's neck)
    for x_fork in [-0.28, 0.28]:
        tube('Prong_'+('L' if x_fork<0 else 'R'),
             [(0, BED_Y-0.18, -1.42),
              (x_fork, BED_Y-0.17, -1.60),
              (x_fork, BED_Y-0.14, -1.82)],
             [0.024, 0.021, 0.019], frame, sides=8)

    # Hemp rope lashings at crossbar–prong joints
    for x_lash in [-0.58, 0.58]:
        rope_pts = [(x_lash + math.sin(i*math.tau/12)*0.04,
                     BED_Y-0.10 + math.cos(i*math.tau/12)*0.03,
                     -1.48) for i in range(13)]
        tube('Lash_'+str(x_lash), rope_pts, [0.013]*13, rope, sides=6)

    # ── Decorative bells on yoke crossbar ────────────────────────────────
    for i in range(5):
        xb = (i-2) * 0.22
        sphere('Yoke_bell_'+str(i), (xb, BED_Y-0.19, -1.48), (0.025,0.025,0.030), brass)

    # ── Iron reinforcement brackets on axle joints ────────────────────────
    for z in [FZ, RZ]:
        for x in [-0.44, 0.44]:
            tube('Bracket_'+str(z)+'_'+str(x),
                 [(x-0.03, WCY+0.10, z), (x+0.03, WCY+0.10, z)],
                 [0.015,0.015], iron, sides=6)

    export_static('cart_body')


# ── BULLOCK (parameterised for colour variants) ───────────────────────────

# (variant_suffix, coat_lo, coat_hi, harness_rgb, bell_rgb, bell_metallic)
BULL_VARIANTS = [
    ('white',  (.59,.57,.51), (.72,.70,.64), (.30,.025,.018), (.55,.32,.07), .65),
    ('brown',  (.28,.17,.08), (.41,.26,.13), (.55,.32,.07  ), (.22,.12,.02), .70),
    ('black',  (.04,.04,.05), (.12,.10,.12), (.60,.45,.12  ), (.55,.32,.07), .65),
    ('grey',   (.41,.39,.37), (.56,.54,.51), (.30,.025,.018), (.50,.28,.05), .68),
    ('amber',  (.48,.28,.09), (.62,.38,.16), (.25,.08,.008 ), (.55,.32,.07), .65),
]

def bullock(variant='white', coat_lo=(.59,.57,.51), coat_hi=(.72,.70,.64),
            harness_rgb=(.30,.025,.018), bell_rgb=(.55,.32,.07), bell_metallic=.65):
    clear()
    coat  = mat('Coat_'+variant,            coat_lo, rough=.72)
    plain = mat('CoatDetail_'+variant,      coat_lo, rough=.75)
    dark  = mat('Muzzle nostrils hooves',   (.055,.045,.035), rough=.80)
    horn  = mat('Keratin horn',             (.31,.26,.17), rough=.45)
    eye   = mat('Dark wet eye',             (.012,.009,.006), rough=.12)
    inner = mat('Ear inner skin',           (.25,.19,.15))
    red   = mat('Woven harness_'+variant,   harness_rgb)
    gold  = mat('Brass bells_'+variant,     bell_rgb, rough=.30, metallic=bell_metallic)

    parts = []
    def skin(name, p, r): parts.append(sphere(name, p, r))
    # Body volumes
    skin('Rib cage',    ( 0,  1.02,  .05), (.34,.39,.77))
    skin('Shoulders',   ( 0,  1.12, -.48), (.32,.43,.33))
    skin('Hindquarters',( 0,  1.05,  .58), (.32,.40,.34))
    skin('Zebu hump',   ( 0,  1.40, -.40), (.22,.26,.28))
    skin('Neck',        ( 0,  1.17, -.78), (.23,.31,.38))
    skin('Skull',       ( 0,  1.29,-1.06), (.205,.25,.25))
    skin('Forehead',    ( 0,  1.40,-1.16), (.155,.18,.20))
    skin('Long face',   ( 0,  1.16,-1.27), (.16,.22,.28))
    skin('Muzzle',      ( 0,  .99, -1.43), (.18,.105,.15))
    skin('Dewlap',      ( 0,  .84,  -.78), (.075,.36,.26))

    extras = []
    specs = [('root',  (0,.80, .30),(0,1.10, .30), None),
             ('spine', (0,1.05, .50),(0,1.12,-.50),'root'),
             ('neck',  (0,1.12,-.50),(0,1.28,-.92),'spine'),
             ('head',  (0,1.28,-.92),(0,1.16,-1.40),'neck'),
             ('tail',  (0,1.22, .80),(0, .50, 1.00),'root')]

    for side, label in [(-1,'L'),(1,'R')]:
        ear = sphere('Ear_'+label, (side*.27, 1.35,-1.0), (.23,.055,.11), coat)
        ear.rotation_euler[1] = side*.23
        extras.append((ear,'head'))
        extras.append((sphere('InnerEar_'+label,  (side*.28, 1.36,-1.03),(.16,.025,.075), inner),'head'))
        extras.append((sphere('Eye_'+label,        (side*.181,1.30,-1.20),(.035,.035,.042), eye), 'head'))
        extras.append((sphere('Nostril_'+label,    (side*.095,1.03,-1.54),(.04,.023,.02), dark),  'head'))
        horn_pts = [(side*.14,1.47,-1.04),(side*.23,1.65,-1.0),
                    (side*.28,1.88,-.94), (side*.23,2.04,-.99)]
        extras.append((tube('Horn_'+label, horn_pts, [.07,.053,.034,.002], horn, 16),'head'))
        for z, leg in [(-.48,'front'),(.58,'rear')]:
            x = side*.23
            kz = z + (.12 if leg=='rear' else -.025)
            skin('Thigh_'+leg+label, (x,.83, z),     (.13,.28,.19))
            skin('Knee_'+leg+label,  (x,.51, kz),    (.085,.15,.085))
            skin('Cannon_'+leg+label,(x,.28, z+.02), (.059,.23,.065))
            upper = leg+label+'_upper'; lower = leg+label+'_lower'; hoof = leg+label+'_hoof'
            specs += [(upper,(x,1.05,z),   (x,.52,kz),    'spine'),
                      (lower,(x,.52,kz),   (x,.13,z+.02), upper),
                      (hoof, (x,.13,z+.02),(x,.08,z-.09), lower),
                      (leg+label+'_IK',(x,.13,z+.02),(x,.13,z-.10),'root')]
            for split in [-1,1]:
                extras.append((sphere('Hoof',(x+split*.038,.075,z-.015),
                                      (.037,.073,.095), dark), hoof))

    body = sculpt(parts, 'Bullock_skin_'+variant, coat, .023)
    texture_mesh(body, coat, 'bullock_coat_'+variant, coat_lo, coat_hi)

    extras.append((tube('Tail',[(0,1.23,.82),(0,.92,.95),(0,.57,1.0),(0,.32,.99)],
                         [.035,.025,.021,.015],coat),'tail'))
    extras.append((sphere('Tail_tuft',(0,.28,.99),(.065,.14,.065),dark),'tail'))
    extras.append((sphere('Muzzle_leather',(0,1.0,-1.49),(.16,.073,.07),dark),'head'))

    # Brass bells on neck harness
    for k in range(7):
        a = math.tau*k/7
        extras.append((sphere('Bell_'+str(k),
                               (math.sin(a)*.24, 1.12+math.cos(a)*.25, -.87),
                               (.035,.047,.035), gold),'neck'))
    neck_pts = [(math.sin(i*math.tau/24)*.245,
                 1.12+math.cos(i*math.tau/24)*.26, -.86) for i in range(25)]
    extras.append((tube('NeckHarness', neck_pts, [.027]*25, red),'neck'))

    arm = rig('BullockSkeleton', specs)
    for label in ['L','R']:
        for leg in ['front','rear']:
            c = arm.pose.bones[leg+label+'_lower'].constraints.new('IK')
            c.target = arm; c.subtarget = leg+label+'_IK'
            c.chain_count = 2; c.use_stretch = False

    def weights(p):
        x, y, z = p
        if z < -.85: return [('head',1)]
        if y < .86 and (abs(z+.48)<.32 or abs(z-.58)<.33) and abs(x)>.12:
            leg   = 'front' if z<0 else 'rear'
            lbl   = 'L' if x<0 else 'R'
            upper = max(0,min(1,(y-.42)/.23))
            return [(leg+lbl+'_upper',upper),(leg+lbl+'_lower',1-upper)]
        if z < -.5:
            neck = max(0,min(1,(-z-.5)/.35))
            return [('neck',neck),('spine',1-neck)]
        return [('spine',1)]

    bind(body, arm, weights)
    for o, b in extras:
        for slot in o.material_slots:
            if slot.material == coat: slot.material = plain
        rigid(o, arm, b)

    def gait(t, running):
        pose = {'head':(.06*math.sin(t*2),0,0),
                'neck':(.025*math.sin(t*2),0,0),
                'tail':(.06,.12*math.sin(t),0)}
        locs = {'spine':(0, -.085+(.018 if running else .008)*math.sin(t*2), 0)}
        stride = .34 if running else .20
        lift   = .25 if running else .09
        for lbl in ['L','R']:
            for leg in ['front','rear']:
                phase = (t/math.tau + (0 if lbl=='L' else .5) + (.5 if leg=='rear' else 0)) % 1
                if phase < .55:
                    z = -stride + 2*stride*phase/.55; y = 0
                else:
                    sw = (phase-.55)/.45
                    z  = stride*math.cos(math.pi*sw)
                    y  = lift*math.sin(math.pi*sw)
                locs[leg+lbl+'_IK'] = (0, y, z)
        return pose, locs

    animate(arm, 'Walk', lambda t: gait(t,False), frames=34)
    animate(arm, 'Run',  lambda t: gait(t,True),  frames=18)
    export('bullock_'+variant, arm)


# ── DRIVER ────────────────────────────────────────────────────────────────

def driver():
    clear()
    skin_m   = mat('Skin',               (.30,.15,.075))
    cloth    = mat('Blue cotton kurta',  (.31,.57,.65))
    plain_cl = mat('Blue short sleeves', (.31,.57,.65))
    pants_m  = mat('Cream trousers',     (.69,.64,.50))
    arm_skin = mat('Bare forearms',      (.30,.15,.075))
    turban   = mat('Red headwrap',       (.39,.035,.02))
    hair     = mat('Hair moustache',     (.035,.025,.018))
    ivory    = mat('Eyes whites',        (.65,.60,.50), rough=.40)
    pupil    = mat('Iris',               (.015,.01,.007), rough=.20)
    shoes    = mat('Leather sandals',    (.11,.065,.025))

    parts = [sphere('Chest', (0,1.64,.32),(.235,.30,.15)),
             sphere('Waist', (0,1.40,.35),(.20,.20,.16)),
             sphere('Pelvis',(0,1.19,.36),(.24,.15,.20))]
    sleeves = []
    specs   = [('hips', (0,1.16,.35),(0,1.40,.35),None),
               ('spine',(0,1.40,.35),(0,1.78,.32),'hips'),
               ('head', (0,1.78,.32),(0,2.13,.29),'spine')]
    extras  = []

    for side, label in [(-1,'L'),(1,'R')]:
        x = side*.18
        parts += [sphere('Thigh',(x,1.16,.06),(.105,.11,.29)),
                  sphere('Cuff', (x,1.00,-.18),(.09,.17,.095))]
        shoulder   = (side*.22,1.73, .32)
        elbow      = (side*.31,1.49,  .10)
        wrist      = (side*.26,1.48, -.17)
        sleeve_end = tuple(shoulder[j]+(elbow[j]-shoulder[j])*.50 for j in range(3))
        sleeves.append(tube('Sleeve_'+label, [shoulder,sleeve_end], [.11,.10], plain_cl))
        extras.append((tube('Arm_'+label,    [sleeve_end,elbow,wrist],[.078,.064,.046],arm_skin),'forearm'+label))
        extras.append((tube('Ankle_'+label,  [(x,.9,-.18),(x,.73,-.18)],[.061,.05],arm_skin),'shin'+label))
        extras.append((sphere('Palm_'+label, (side*.26,1.47,-.23),(.07,.045,.09),skin_m),'forearm'+label))
        for finger in range(4):
            extras.append((tube('Finger_'+label+str(finger),
                [(side*.22+finger*.021,1.46,-.25),(side*.22+finger*.021,1.42,-.29)],
                [.012,.010],skin_m,8),'forearm'+label))
        extras.append((sphere('Sandal_'+label,(x,.71,-.24),(.105,.045,.17),shoes),'shin'+label))
        specs += [('arm'+label,      shoulder, elbow,  'spine'),
                  ('forearm'+label,  elbow,    wrist,  'arm'+label),
                  ('thigh'+label,    (x,1.16,.35),(x,1.15,-.17),'hips'),
                  ('shin'+label,     (x,1.15,-.17),(x,.72,-.17),'thigh'+label)]

    shirt   = sculpt(parts[:2]+[sphere('Hem',(0,1.31,.34),(.235,.12,.18))],
                     'Driver_blue_kurta',cloth,.017)
    clothes = sculpt(parts[2:], 'Driver_cream_trousers',pants_m,.017)
    texture_mesh(shirt,   cloth,   'driver_cotton',   (.27,.51,.59),(.39,.64,.73))
    texture_mesh(clothes, pants_m, 'driver_trousers', (.60,.56,.44),(.76,.71,.59))

    faceparts = [sphere('Neck2', (0,1.87,.30),(.075,.11,.08)),
                 sphere('Cranium',(0,2.06,.30),(.135,.18,.13)),
                 sphere('Jaw',    (0,1.97,.25),(.105,.09,.105)),
                 sphere('Nose',   (0,2.045,.16),(.034,.058,.048))]
    for side in [-1,1]:
        faceparts += [sphere('Cheek',(side*.07,2.035,.205),(.064,.065,.045)),
                      sphere('Brow', (side*.06,2.105,.188),(.066,.025,.030)),
                      sphere('Ear2', (side*.137,2.055,.29),(.025,.058,.030))]
    face = sculpt(faceparts,'Driver_face_neck',skin_m,.009)
    texture_mesh(face, skin_m,'driver_skin',(.26,.13,.06),(.34,.18,.095))

    for side in [-1,1]:
        extras.append((sphere('EyeW',(side*.059,2.075,.177),(.033,.017,.013),ivory),'head'))
        extras.append((sphere('Iris',(side*.059,2.075,.164),(.013,.014,.009),pupil),'head'))
        extras.append((tube('Moustache',
            [(0,2.007,.142),(side*.055,2.005,.15),(side*.085,1.992,.175)],
            [.012,.018,.008],hair),'head'))
    extras.append((tube('LipLine',[( -.04,1.975,.163),(0,1.97,.15),(.04,1.975,.163)],
                         [.008,.012,.008],skin_m),'head'))

    for wrap in range(6):
        pts = [(math.sin(j*math.tau/48)*(.155-wrap*.007),
                2.20+wrap*.02+math.sin(j*math.tau/48)*.018,
                .30+math.cos(j*math.tau/48)*(.145-wrap*.006)) for j in range(49)]
        extras.append((tube('Turban_'+str(wrap), pts, [.028]*49, turban),'head'))

    extras.append((tube('Placket',[(0,1.78,.169),(0,1.43,.183)],[.012,.012],cloth),'spine'))
    for y_btn in [1.72,1.63,1.54]:
        extras.append((sphere('Button',(0,y_btn,.162),(.013,.013,.006),ivory),'spine'))

    # Reins — two ropes running forward from each hand toward bulls
    rein_m = mat('Leather reins',(.12,.065,.02),rough=.80)
    for side,label in [(-1,'L'),(1,'R')]:
        extras.append((tube('Rein_'+label,
            [(side*.26,1.47,-.23),(side*.24,1.32,-.60),(side*.22,1.16,-1.10)],
            [.008,.007,.006], rein_m),'forearm'+label))

    arm = rig('DriverSkeleton', specs)

    def wts(p):
        x, y, z = p
        if y < 1.29:
            lbl = 'L' if x<0 else 'R'
            return [('shin'+lbl,1)] if y<1.09 else [('thigh'+lbl,1)]
        return [('spine',1)]

    bind(clothes, arm, wts)
    rigid(shirt, arm, 'spine')
    rigid(face,  arm, 'head')
    for i, o in enumerate(sleeves):
        o.data.materials.clear(); o.data.materials.append(plain_cl)
        lbl = 'L' if i==0 else 'R'
        bind(o, arm, lambda p,l=lbl: [('forearm'+l,1)] if p[2]<.10 else [('arm'+l,1)])
    for o, b in extras:
        for slot in o.material_slots:
            if slot.material == cloth:   slot.material = plain_cl
            if slot.material == skin_m:  slot.material = mat('SkinDetail',(.30,.15,.075))
        rigid(o, arm, b)

    animate(arm,'Ride', lambda t:{
        'spine':   (.018*math.sin(t*2), 0, 0),
        'head':    (.022*math.sin(t), .035*math.sin(t), 0),
        'forearmL':(.028*math.sin(t), 0, 0),
        'forearmR':(.028*math.sin(t+.3), 0, 0)})
    export('driver_rigged', arm)

    # ── Second export: checked tunic variant ─────────────────────────────
    texture_mesh(shirt,   cloth,   'driver_checked_tunic',   (.38,.08,.07),(.77,.70,.61), checked=True)
    texture_mesh(clothes, pants_m, 'driver_blue_trousers',   (.20,.31,.39),(.35,.47,.55))
    for i, o in enumerate(sleeves):
        sm = mat('Checked sleeve '+str(i),(.38,.08,.07))
        o.data.materials.clear(); o.data.materials.append(sm)
        texture_mesh(o, sm,'driver_checked_sleeve_'+str(i),(.38,.08,.07),(.77,.70,.61),checked=True)
    sash_m = mat('Waist sash',(.15,.025,.018))
    sash   = tube('Sash',
                  [(math.sin(j*math.tau/40)*.239,1.40,.34+math.cos(j*math.tau/40)*.185)
                   for j in range(41)], [.036]*41, sash_m)
    rigid(sash, arm,'spine')
    export('driver_rigged_checked', arm)


# ── RUN ───────────────────────────────────────────────────────────────────

cart_body()

for suffix, lo, hi, harness, bell_col, bell_m in BULL_VARIANTS:
    bullock(suffix, lo, hi, harness, bell_col, bell_m)

# Keep legacy name pointing to white variant (existing game references it)
(OUT/'bullock_rigged.glb').unlink(missing_ok=True)
import shutil
shutil.copy(str(OUT/'bullock_white.glb'), str(OUT/'bullock_rigged.glb'))

driver()

(OUT/'model_manifest.json').write_text(json.dumps(REPORT, indent=2), encoding='utf-8')
print('CHARACTER_EXPORT_COMPLETE', json.dumps(REPORT))
