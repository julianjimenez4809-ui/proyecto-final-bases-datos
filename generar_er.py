"""
Genera el diagrama ER de ShopCo como SVG usando solo stdlib de Python.
Ejecutar: python3 generar_er.py
Salida:   Sprint Final/3_modelo_er/er_shopco.svg
"""

ENTITIES = {
    "CATEGORIA": {
        "color": "#1a3a5c",
        "fields": [
            ("categoria_id",      "UUID",    "PK"),
            ("nombre",            "VARCHAR", "UK"),
            ("descripcion",       "TEXT",    ""),
            ("categoria_padre_id","UUID",    "FK"),
        ]
    },
    "CLIENTE": {
        "color": "#1a3a5c",
        "fields": [
            ("cliente_id",    "UUID",        "PK"),
            ("nombre",        "VARCHAR",     ""),
            ("apellido",      "VARCHAR",     ""),
            ("email",         "VARCHAR",     "UK"),
            ("telefono",      "VARCHAR",     ""),
            ("fecha_registro","TIMESTAMPTZ", ""),
            ("activo",        "BOOLEAN",     ""),
        ]
    },
    "DIRECCION": {
        "color": "#1a3a5c",
        "fields": [
            ("direccion_id", "UUID",    "PK"),
            ("cliente_id",   "UUID",    "FK"),
            ("calle",        "VARCHAR", ""),
            ("ciudad",       "VARCHAR", ""),
            ("departamento", "VARCHAR", ""),
            ("es_principal", "BOOLEAN", ""),
        ]
    },
    "PRODUCTO": {
        "color": "#1a5c2a",
        "fields": [
            ("producto_id",   "UUID",    "PK"),
            ("sku",           "VARCHAR", "UK"),
            ("nombre",        "VARCHAR", ""),
            ("precio_costo",  "NUMERIC", ""),
            ("precio_venta",  "NUMERIC", ""),
            ("categoria_id",  "UUID",    "FK"),
            ("activo",        "BOOLEAN", ""),
        ]
    },
    "INVENTARIO": {
        "color": "#1a5c2a",
        "fields": [
            ("inventario_id",      "UUID",        "PK"),
            ("producto_id",        "UUID",        "FK,UK"),
            ("stock",              "INTEGER",     ""),
            ("stock_minimo",       "INTEGER",     ""),
            ("ubicacion",          "VARCHAR",     ""),
            ("ultima_actualizacion","TIMESTAMPTZ",""),
        ]
    },
    "PEDIDO": {
        "color": "#5c1a1a",
        "fields": [
            ("pedido_id",          "UUID",        "PK"),
            ("cliente_id",         "UUID",        "FK"),
            ("direccion_id",       "UUID",        "FK"),
            ("estado",             "VARCHAR",     "CHECK"),
            ("fecha_pedido",       "TIMESTAMPTZ", ""),
            ("fecha_actualizacion","TIMESTAMPTZ", ""),
        ]
    },
    "DETALLE_PEDIDO": {
        "color": "#5c1a1a",
        "fields": [
            ("detalle_id",     "UUID",    "PK"),
            ("pedido_id",      "UUID",    "FK"),
            ("producto_id",    "UUID",    "FK"),
            ("cantidad",       "INTEGER", "CHECK"),
            ("precio_unitario","NUMERIC", ""),
            ("descuento",      "NUMERIC", "CHECK"),
        ]
    },
    "PAGO": {
        "color": "#5c3a1a",
        "fields": [
            ("pago_id",            "UUID",        "PK"),
            ("pedido_id",          "UUID",        "FK,UK"),
            ("metodo",             "VARCHAR",     "CHECK"),
            ("estado",             "VARCHAR",     "CHECK"),
            ("monto",              "NUMERIC",     "CHECK"),
            ("referencia_externa", "VARCHAR",     ""),
            ("fecha_pago",         "TIMESTAMPTZ", ""),
        ]
    },
    "ENVIO": {
        "color": "#5c3a1a",
        "fields": [
            ("envio_id",              "UUID",    "PK"),
            ("pedido_id",             "UUID",    "FK,UK"),
            ("transportista",         "VARCHAR", ""),
            ("numero_guia",           "VARCHAR", ""),
            ("estado",                "VARCHAR", "CHECK"),
            ("fecha_entrega_estimada","DATE",    ""),
            ("fecha_entrega_real",    "TIMESTAMP",""),
        ]
    },
    "RESENA": {
        "color": "#3a1a5c",
        "fields": [
            ("resena_id",  "UUID",     "PK"),
            ("cliente_id", "UUID",     "FK"),
            ("producto_id","UUID",     "FK"),
            ("pedido_id",  "UUID",     "FK"),
            ("calificacion","SMALLINT","CHECK"),
            ("comentario", "TEXT",     ""),
            ("fecha_resena","TIMESTAMPTZ",""),
        ]
    },
}

# Posiciones (x, y) de cada entidad — diseño manual en cuadrícula
POSITIONS = {
    "CATEGORIA":     (40,  50),
    "PRODUCTO":      (400, 50),
    "INVENTARIO":    (760, 50),
    "CLIENTE":       (40,  370),
    "DIRECCION":     (40,  660),
    "PEDIDO":        (400, 370),
    "DETALLE_PEDIDO":(400, 660),
    "PAGO":          (760, 370),
    "ENVIO":         (760, 660),
    "RESENA":        (1100,430),
}

# Relaciones: (origen, destino, label_origen, label_destino)
RELATIONS = [
    ("CATEGORIA",     "CATEGORIA",      "0..N",  "0..1",  "es padre de"),
    ("CATEGORIA",     "PRODUCTO",       "1",     "N",     "clasifica"),
    ("CLIENTE",       "DIRECCION",      "1",     "N",     "tiene"),
    ("CLIENTE",       "PEDIDO",         "1",     "N",     "realiza"),
    ("CLIENTE",       "RESENA",         "1",     "N",     "escribe"),
    ("DIRECCION",     "PEDIDO",         "1",     "N",     "destino de"),
    ("PRODUCTO",      "INVENTARIO",     "1",     "1",     "stock en"),
    ("PRODUCTO",      "DETALLE_PEDIDO", "1",     "N",     "incluido en"),
    ("PRODUCTO",      "RESENA",         "1",     "N",     "recibe"),
    ("PEDIDO",        "DETALLE_PEDIDO", "1",     "N",     "contiene"),
    ("PEDIDO",        "PAGO",           "1",     "1",     "pagado con"),
    ("PEDIDO",        "ENVIO",          "1",     "0..1",  "despachado en"),
    ("PEDIDO",        "RESENA",         "1",     "N",     "origina"),
]

BOX_W    = 300
HEADER_H = 34
ROW_H    = 22
PAD_X    = 10
CANVAS_W = 1460
CANVAS_H = 1020

def box_height(entity_name):
    return HEADER_H + len(ENTITIES[entity_name]["fields"]) * ROW_H + 8

def box_center(entity_name):
    x, y = POSITIONS[entity_name]
    h = box_height(entity_name)
    return x + BOX_W // 2, y + h // 2

def clamp_to_border(entity_name, tx, ty):
    """Calcula el punto en el borde de la caja más cercano a (tx, ty)."""
    x, y = POSITIONS[entity_name]
    h = box_height(entity_name)
    cx, cy = x + BOX_W // 2, y + h // 2
    dx, dy = tx - cx, ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    if dx == 0:
        return cx, (y if dy < 0 else y + h)
    if dy == 0:
        return (x if dx < 0 else x + BOX_W), cy
    # Intersección con los 4 bordes
    scale_x = (BOX_W / 2) / abs(dx)
    scale_y = (h / 2) / abs(dy)
    scale = min(scale_x, scale_y)
    return int(cx + dx * scale), int(cy + dy * scale)

def badge_color(tag):
    if "PK" in tag:  return "#e8b84b"
    if "FK" in tag:  return "#5ba4f5"
    if "UK" in tag:  return "#69db7c"
    if "CHECK" in tag: return "#f08c00"
    return None

def render_entity(name, x, y):
    ent = ENTITIES[name]
    h   = box_height(name)
    lines = []
    # Sombra
    lines.append(f'<rect x="{x+4}" y="{y+4}" width="{BOX_W}" height="{h}" rx="6" fill="#00000033"/>')
    # Cuerpo
    lines.append(f'<rect x="{x}" y="{y}" width="{BOX_W}" height="{h}" rx="6" fill="#f8f9fa" stroke="#ced4da" stroke-width="1.5"/>')
    # Header
    lines.append(f'<rect x="{x}" y="{y}" width="{BOX_W}" height="{HEADER_H}" rx="6" fill="{ent["color"]}"/>')
    lines.append(f'<rect x="{x}" y="{y+HEADER_H-6}" width="{BOX_W}" height="6" fill="{ent["color"]}"/>')
    lines.append(f'<text x="{x+BOX_W//2}" y="{y+HEADER_H-10}" text-anchor="middle" font-family="monospace" font-size="13" font-weight="bold" fill="white">{name}</text>')
    # Campos
    for i, (fname, ftype, tag) in enumerate(ent["fields"]):
        fy = y + HEADER_H + 6 + i * ROW_H
        # Separador
        if i > 0:
            lines.append(f'<line x1="{x+6}" y1="{fy}" x2="{x+BOX_W-6}" y2="{fy}" stroke="#dee2e6" stroke-width="0.8"/>')
        # Badge
        bc = badge_color(tag)
        bx = x + PAD_X
        if bc:
            tag_short = tag.split(",")[0]  # solo primer tag para el badge
            lines.append(f'<rect x="{bx}" y="{fy+4}" width="26" height="14" rx="3" fill="{bc}"/>')
            lines.append(f'<text x="{bx+13}" y="{fy+14}" text-anchor="middle" font-family="monospace" font-size="8" font-weight="bold" fill="white">{tag_short}</text>')
            bx += 32
        # Nombre del campo
        lines.append(f'<text x="{bx}" y="{fy+15}" font-family="monospace" font-size="11" fill="#212529">{fname}</text>')
        # Tipo
        lines.append(f'<text x="{x+BOX_W-PAD_X}" y="{fy+15}" text-anchor="end" font-family="monospace" font-size="10" fill="#6c757d">{ftype}</text>')
    return "\n".join(lines)

def render_relation(src, dst, lbl_src, lbl_dst, label):
    if src == dst:
        # Auto-referencia (CATEGORIA)
        x, y = POSITIONS[src]
        rx, ry = x + BOX_W, y + HEADER_H + 20
        return (
            f'<path d="M {rx} {ry} C {rx+60} {ry-20} {rx+60} {ry+40} {rx} {ry+30}" '
            f'fill="none" stroke="#868e96" stroke-width="1.5" marker-end="url(#arrow)"/>'
            f'<text x="{rx+70}" y="{ry+10}" font-family="sans-serif" font-size="10" fill="#495057">{label}</text>'
        )
    cx1, cy1 = box_center(src)
    cx2, cy2 = box_center(dst)
    p1x, p1y = clamp_to_border(src, cx2, cy2)
    p2x, p2y = clamp_to_border(dst, cx1, cy1)
    # Punto medio para la etiqueta
    mx, my = (p1x + p2x) // 2, (p1y + p2y) // 2
    lines = [
        f'<line x1="{p1x}" y1="{p1y}" x2="{p2x}" y2="{p2y}" stroke="#868e96" stroke-width="1.5" marker-end="url(#arrow)"/>',
        f'<rect x="{mx-28}" y="{my-10}" width="56" height="14" rx="3" fill="white" opacity="0.85"/>',
        f'<text x="{mx}" y="{my+1}" text-anchor="middle" font-family="sans-serif" font-size="9" fill="#343a40">{label}</text>',
        # Cardinalidades
        f'<text x="{p1x+int((p2x-p1x)*0.1)}" y="{p1y+int((p2y-p1y)*0.1)-5}" font-family="monospace" font-size="10" font-weight="bold" fill="{ENTITIES[src]["color"]}">{lbl_src}</text>',
        f'<text x="{p2x-int((p2x-p1x)*0.1)}" y="{p2y-int((p2y-p1y)*0.1)-5}" font-family="monospace" font-size="10" font-weight="bold" fill="{ENTITIES[dst]["color"]}">{lbl_dst}</text>',
    ]
    return "\n".join(lines)

# ── Generar SVG ──────────────────────────────────────────────────────────────
parts = []
parts.append(f'''<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_W}" height="{CANVAS_H}" viewBox="0 0 {CANVAS_W} {CANVAS_H}">
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="#868e96"/>
  </marker>
</defs>
<!-- Fondo -->
<rect width="{CANVAS_W}" height="{CANVAS_H}" fill="#f1f3f5"/>
<!-- Título -->
<text x="{CANVAS_W//2}" y="30" text-anchor="middle" font-family="sans-serif" font-size="18" font-weight="bold" fill="#212529">Modelo Entidad-Relación — ShopCo E-Commerce</text>
<text x="{CANVAS_W//2}" y="50" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#6c757d">PostgreSQL 17 · Supabase · 10 tablas · 3FN · 24 constraints</text>

<!-- Leyenda -->
<rect x="20" y="{CANVAS_H-70}" width="420" height="55" rx="6" fill="white" stroke="#ced4da" stroke-width="1"/>
<text x="30" y="{CANVAS_H-52}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#343a40">Leyenda badges:</text>
<rect x="30" y="{CANVAS_H-44}" width="22" height="12" rx="2" fill="#e8b84b"/>
<text x="56" y="{CANVAS_H-34}" font-family="monospace" font-size="10" fill="#343a40">PK — Primary Key</text>
<rect x="160" y="{CANVAS_H-44}" width="22" height="12" rx="2" fill="#5ba4f5"/>
<text x="186" y="{CANVAS_H-34}" font-family="monospace" font-size="10" fill="#343a40">FK — Foreign Key</text>
<rect x="290" y="{CANVAS_H-44}" width="22" height="12" rx="2" fill="#69db7c"/>
<text x="316" y="{CANVAS_H-34}" font-family="monospace" font-size="10" fill="#343a40">UK — Unique</text>
<rect x="30" y="{CANVAS_H-24}" width="22" height="12" rx="2" fill="#f08c00"/>
<text x="56" y="{CANVAS_H-14}" font-family="monospace" font-size="10" fill="#343a40">CHECK — Constraint de valor</text>
''')

# Relaciones primero (debajo de las entidades)
parts.append("<!-- Relaciones -->")
for src, dst, lbl_s, lbl_d, lbl in RELATIONS:
    parts.append(render_relation(src, dst, lbl_s, lbl_d, lbl))

# Entidades encima
parts.append("<!-- Entidades -->")
for name, (x, y) in POSITIONS.items():
    parts.append(render_entity(name, x, y))

parts.append("</svg>")

svg_content = "\n".join(parts)
out_path = "Sprint Final/3_modelo_er/er_shopco.svg"
with open(out_path, "w", encoding="utf-8") as f:
    f.write(svg_content)

print(f"✓ SVG generado: {out_path}")
print(f"  Tamaño: {len(svg_content):,} bytes")
