from pathlib import Path
from collections import Counter
import math

out = Path(__file__).resolve().parent
points = [(0,0,0),(40,0,0),(40,40,0),(0,40,0),
          (0,0,40),(40,0,40),(40,40,40),(0,40,40)]
# Counterclockwise when viewed from outside the solid.
faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),
         (1,2,6,5),(2,3,7,6),(3,0,4,7)]
entities = []
def entity(value):
    entities.append(value)
    return f'#{len(entities)}'
def refs(values):
    return '(' + ','.join(values) + ')'

app = entity("APPLICATION_CONTEXT('configuration controlled 3d designs of mechanical parts and assemblies')")
entity(f"APPLICATION_PROTOCOL_DEFINITION('international standard','config_control_design',1994,{app})")
pc = entity(f"PRODUCT_CONTEXT('',{app},'mechanical')")
product = entity(f"PRODUCT('Cube 40 mm','Cube 40 mm','Solid cube, 40 x 40 x 40 mm',({pc}))")
formation = entity(f"PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE('1','',{product},.NOT_KNOWN.)")
pdc = entity(f"PRODUCT_DEFINITION_CONTEXT('part definition',{app},'design')")
pd = entity(f"PRODUCT_DEFINITION('design','',{formation},{pdc})")
pds = entity(f"PRODUCT_DEFINITION_SHAPE('','',{pd})")
length = entity('(LENGTH_UNIT() NAMED_UNIT(*) SI_UNIT(.MILLI.,.METRE.))')
angle = entity('(NAMED_UNIT(*) PLANE_ANGLE_UNIT() SI_UNIT($,.RADIAN.))')
solid_angle = entity('(NAMED_UNIT(*) SI_UNIT($,.STERADIAN.) SOLID_ANGLE_UNIT())')
uncertainty = entity(f"UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(1.E-7),{length},'distance_accuracy_value','')")
context = entity(f"(GEOMETRIC_REPRESENTATION_CONTEXT(3) GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT(({uncertainty})) GLOBAL_UNIT_ASSIGNED_CONTEXT(({length},{angle},{solid_angle})) REPRESENTATION_CONTEXT('','3D'))")
vertices = [entity("CARTESIAN_POINT('',(" + ','.join(f'{v:.1f}' for v in p) + '))') for p in points]
step_faces = []
for face in faces:
    loop = entity(f"POLY_LOOP('',{refs([vertices[i] for i in face])})")
    bound = entity(f"FACE_OUTER_BOUND('',{loop},.T.)")
    step_faces.append(entity(f"FACE('',({bound}))"))
shell = entity(f"CLOSED_SHELL('',{refs(step_faces)})")
brep = entity(f"FACETED_BREP('Cube 40 mm',{shell})")
rep = entity(f"FACETED_BREP_SHAPE_REPRESENTATION('Cube 40 mm',({brep}),{context})")
entity(f'SHAPE_DEFINITION_REPRESENTATION({pds},{rep})')
header = """ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('Solid cube 40 x 40 x 40 mm'),'2;1');
FILE_NAME('cube_40mm.step','2026-11-16T00:00:00',(''),(''),'Python STEP writer','', '');
FILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));
ENDSEC;
DATA;
"""
(out / 'cube_40mm.step').write_text(header + '\n'.join(f'#{i}={e};' for i,e in enumerate(entities,1)) + '\nENDSEC;\nEND-ISO-10303-21;\n', encoding='ascii')

def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
triangles = [(f[0],f[i],f[i+1]) for f in faces for i in (1,2)]
edges = Counter((t[i],t[(i+1)%3]) for t in triangles for i in range(3))
assert all(edges[(b,a)] == count == 1 for (a,b),count in edges.items())
volume = sum(sum(x*y for x,y in zip(points[a],cross(points[b],points[c]))) / 6 for a,b,c in triangles)
assert math.isclose(volume,64000)
assert [max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)] == [40,40,40]
stl = ['solid cube_40mm']
for a,b,c in triangles:
    normal = cross(sub(points[b],points[a]), sub(points[c],points[a]))
    magnitude = math.sqrt(sum(x*x for x in normal))
    stl += ['  facet normal ' + ' '.join(str(x/magnitude) for x in normal), '    outer loop']
    stl += ['      vertex ' + ' '.join(map(str,points[i])) for i in (a,b,c)]
    stl += ['    endloop','  endfacet']
stl += ['endsolid cube_40mm']
(out / 'cube_40mm.stl').write_text('\n'.join(stl)+'\n',encoding='ascii')
print('Created cube_40mm.step and cube_40mm.stl')
print('Verified: 40 x 40 x 40 mm; closed manifold; outward faces; volume 64000 mm^3.')
