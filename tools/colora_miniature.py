import trimesh, numpy as np, os
OUT = '/home/claude/Fellowship/assets/modelli'
PELLE = (225, 185, 150)
def carica(nome):
    m = trimesh.load('out/%s.stl' % nome)
    if not (m.extents[1] > m.extents[2] * 1.2):
        m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi/2, [1,0,0]))
    m.apply_translation([-m.bounds.mean(0)[0], -m.bounds[0][1], -m.bounds.mean(0)[2]])
    m.apply_scale(1.0 / m.extents[1])
    return m
def cima_base(m):
    v = m.vertices; y = v[:,1]
    def larg(a, b):
        s = v[(y >= a) & (y < b)]
        return 0 if len(s) < 5 else max(np.ptp(s[:,0]), np.ptp(s[:,2]))
    l0 = larg(0, 0.02)
    if l0 < 0.35:    # niente basetta (piedi)
        return 0.0
    for k in range(1, 40):
        if larg(k * 0.01, k * 0.01 + 0.02) < l0 * 0.7:
            return k * 0.01 + 0.01
    return 0.05
def colora(m, p):
    v = m.vertices; y = v[:,1]; n = m.vertex_normals
    b = p.get('base_y', cima_base(m))
    h = (y - b) / max(0.01, 1 - b)
    cx, cz = np.median(v[h > 0.3][:, [0, 2]], axis=0) if (h > 0.3).sum() > 10 else (0, 0)
    r = np.hypot(v[:,0] - cx, v[:,2] - cz)
    col = np.zeros((len(v), 3)); 
    def put(mask, c): col[mask] = np.array(c) / 255.0
    put(np.ones(len(v), bool), p['tunica'])
    put(h < p.get('h_gambe', 0.42), p.get('gambe', p['tunica']))
    put(h < p.get('h_stivali', 0.08), p.get('stivali', (70, 55, 40)))
    if 'mantello' in p:
        put((v[:,2] - cz < -0.03) & (h > p.get('h_stivali', 0.08)) & (h < p.get('h_testa', 0.84)), p['mantello'])
    testa = h > p.get('h_testa', 0.84)
    put(testa, p.get('capelli', (90, 60, 35)))
    put(testa & (n[:,2] > 0.3) & (h < p.get('h_testa', 0.84) + p.get('viso', 0.08)), p.get('pelle', PELLE))
    if 'arma' in p:
        put((r > p['arma'][0]) & (h > 0.02), p['arma'][1])
    for extra in p.get('fasce', []):     # (h0, h1, colore)
        put((h >= extra[0]) & (h < extra[1]), extra[2])
    put(y < b, p.get('basetta', (52, 58, 44)))
    ao = np.clip(0.72 + 0.28 * n[:,1], 0.5, 1.0)
    col = col * ao[:,None]
    m.visual = trimesh.visual.ColorVisuals(m, vertex_colors=(np.c_[col, np.ones(len(v))] * 255).astype(np.uint8))
    return m
P = {
 'aragorn': ('Aragorn_0', dict(tunica=(85,80,70), gambe=(70,60,50), stivali=(55,40,30), mantello=(62,68,56), capelli=(55,40,30), arma=(0.22,(165,165,175)))),
 'arwen': ('Arwen_0', dict(tunica=(105,55,85), gambe=(105,55,85), stivali=(105,55,85), mantello=(85,45,75), capelli=(40,30,25), h_testa=0.86)),
 'boromir': ('Boromir_0', dict(tunica=(125,40,35), gambe=(70,55,45), stivali=(60,45,35), mantello=(75,58,42), capelli=(115,78,45), arma=(0.24,(150,140,120)))),
 'eomer': ('eomer_0', dict(tunica=(130,120,100), gambe=(130,120,100), stivali=(130,120,100), h_gambe=0.0, h_stivali=0.0, mantello=(50,85,50), capelli=(150,110,60), h_testa=0.9, viso=0.05, fasce=[(0.0,0.58,(105,70,42)), (0.0,0.12,(70,48,30))])),
 'eowyn': ('party_187', dict(tunica=(120,95,70), gambe=(90,70,55), stivali=(60,45,35), mantello=(110,90,65), capelli=(215,185,120), arma=(0.26,(170,170,180)))),
 'faramir': ('FARAMIR_0', dict(tunica=(75,85,60), gambe=(80,65,50), stivali=(60,45,35), mantello=(70,82,55), capelli=(100,70,45), arma=(0.3,(165,165,175)))),
 'galadriel': ('GALADRIEL2_0', dict(tunica=(232,232,226), gambe=(232,232,226), stivali=(232,232,226), mantello=(220,222,215), capelli=(232,205,140), h_testa=0.86)),
 'gandalf': ('Gandalf_0', dict(tunica=(130,130,135), gambe=(120,120,125), h_gambe=0.25, stivali=(70,55,45), h_stivali=0.06, mantello=(100,100,108), capelli=(205,205,205), h_testa=0.8, arma=(0.3,(110,80,50)))),
 'gandalf_bianco': ('Gandalf_0', dict(tunica=(238,238,236), gambe=(232,232,230), h_gambe=0.25, stivali=(200,200,195), h_stivali=0.06, mantello=(228,228,226), capelli=(245,245,245), h_testa=0.8, arma=(0.3,(215,205,180)))),
 'gimli': ('Gimli_0', dict(tunica=(110,80,50), gambe=(90,60,40), stivali=(60,42,30), mantello=(100,62,36), capelli=(150,70,35), h_testa=0.78, arma=(0.32,(165,165,175)), fasce=[(0.55,0.78,(150,70,35))])),
 'legolas': ('Legolas_0', dict(tunica=(95,120,70), gambe=(110,95,70), h_gambe=0.45, stivali=(80,60,40), h_stivali=0.12, mantello=(70,95,60), capelli=(230,210,140), h_testa=0.86, arma=(0.2,(140,105,60)))),
 'gollum': ('gollum2_0', dict(tunica=(175,170,145), gambe=(175,170,145), stivali=(175,170,145), capelli=(150,145,125), h_testa=0.9, basetta=(95,92,85))),
 'frodo_m': ('Hobbits_1', dict(tunica=(160,135,95), gambe=(110,90,60), h_gambe=0.35, stivali=PELLE, h_stivali=0.07, mantello=(80,90,62), capelli=(70,45,25), h_testa=0.72, viso=0.12)),
 'sam_m': ('Hobbits_0', dict(tunica=(190,170,130), gambe=(130,100,60), h_gambe=0.35, stivali=PELLE, h_stivali=0.07, mantello=(110,90,60), capelli=(130,90,50), h_testa=0.72, viso=0.12, arma=(0.3,(70,70,75)))),
 'merry_m': ('Hobbits_2', dict(tunica=(110,90,50), gambe=(95,80,50), h_gambe=0.35, stivali=PELLE, h_stivali=0.07, mantello=(70,85,55), capelli=(140,100,60), h_testa=0.72, viso=0.12)),
 'pipino_m': ('Hobbits_3', dict(tunica=(170,140,90), gambe=(100,80,55), h_gambe=0.35, stivali=PELLE, h_stivali=0.07, mantello=(60,80,60), capelli=(110,70,40), h_testa=0.72, viso=0.12)),
}
fatti = {}
for pid, (src, pal) in P.items():
    m = colora(carica(src), pal)
    fatti[pid] = m
    if not pid.endswith('_m'):
        m.export(os.path.join(OUT, 'pg_%s.glb' % pid)); print(pid, len(m.faces))
def coppia(a, b, nome):
    A = fatti[a].copy(); B = fatti[b].copy()
    A.apply_translation([-A.extents[0] * 0.55, 0, 0]); B.apply_translation([B.extents[0] * 0.55, 0, 0.05])
    C = trimesh.util.concatenate([A, B])
    C.apply_translation([-C.bounds.mean(0)[0], 0, -C.bounds.mean(0)[2]])
    C.export(os.path.join(OUT, 'pg_%s.glb' % nome)); print(nome, len(C.faces))
coppia('frodo_m', 'sam_m', 'frodo')
coppia('merry_m', 'pipino_m', 'pipino')
