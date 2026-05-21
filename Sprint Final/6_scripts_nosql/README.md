# ShopCo — Módulo NoSQL (MongoDB)

## Decisión de modelo y proveedor

**Motor elegido:** MongoDB Atlas (M10, us-east-1 — misma región que Supabase)  
**Modelo:** Documental

### ¿Por qué MongoDB y no el modelo relacional para esto?

| Necesidad | PostgreSQL (Supabase) | MongoDB Atlas |
|---|---|---|
| Catálogo con atributos variables por categoría | Requiere EAV o JSONB | Esquema flexible nativo |
| Logs de eventos de sesión (millones/día) | Costoso en writes | Alta throughput, insert-optimizado |
| Carritos abandonados (TTL automático) | Manual con jobs | TTL index nativo |
| Búsqueda full-text en productos | pg_trgm limitado | Atlas Search (Lucene) |

---

## Arquitectura de integración

```
┌─────────────────────────────┐       ┌──────────────────────────────┐
│   PostgreSQL (Supabase)      │       │   MongoDB Atlas              │
│                              │       │                              │
│  producto.producto_id ───────┼──────►│  catalogo_productos._id      │
│  cliente.cliente_id  ───────┼──────►│  sesiones_usuario.cliente_id │
│  cliente.cliente_id  ───────┼──────►│  carritos_abandonados.       │
│  producto.producto_id ───────┼──────►│    cliente_id / items[].     │
│                              │       │    producto_id               │
└─────────────────────────────┘       └──────────────────────────────┘
       Fuente de verdad                    Catálogo / Eventos / Cache
       transaccional                       alta lectura y escritura
```

**Patrón de integración:** referencia por ID (no embedding). Los `producto_id` y `cliente_id` de MongoDB son exactamente los UUID de PostgreSQL. Las queries de negocio que cruzan ambos mundos se resuelven en la capa de aplicación (Node.js/Python) o mediante ETL.

---

## Colecciones

### 1. `catalogo_productos`
- **Propósito:** Enriquecer el catálogo base (PostgreSQL) con atributos variables, imágenes, tags y historial de precios. Evita columnas JSONB en SQL.
- **Clave de partición:** `_id` (= `producto_id` de PostgreSQL)
- **Índices:** `categoria`, `tags`, `activo + precio_venta` (compound), Atlas Search en `nombre + descripcion`

### 2. `sesiones_usuario`
- **Propósito:** Registrar eventos de navegación en tiempo real: vistas de producto, búsquedas, clics, tiempo en página.
- **Clave de partición:** `cliente_id` + `fecha` (bucketing por día)
- **Índices:** `cliente_id`, `eventos.producto_id`, `fecha` (TTL 90 días)

### 3. `carritos_abandonados`
- **Propósito:** Capturar carritos no convertidos para remarketing y análisis de fricción.
- **Clave de partición:** `cliente_id`
- **Índices:** `cliente_id`, `estado`, `fecha_abandono` (TTL 30 días para carritos recuperados)

---

## Archivos de este módulo

| Archivo | Descripción |
|---|---|
| `schema_catalogo_productos.json` | Esquema + 3 documentos de muestra |
| `schema_sesiones_usuario.json` | Esquema + 2 documentos de muestra |
| `schema_carritos_abandonados.json` | Esquema + 2 documentos de muestra |
| `queries_aggregation.js` | 5 aggregation pipelines ejecutables en mongosh |

## Cómo ejecutar

```bash
# Conectar a MongoDB Atlas
mongosh "mongodb+srv://<user>:<pass>@shopco.xxxxx.mongodb.net/shopco"

# Crear colecciones con validación de esquema
load("schema_catalogo_productos.json")
load("schema_sesiones_usuario.json")
load("schema_carritos_abandonados.json")

# Ejecutar aggregations
load("queries_aggregation.js")
```
