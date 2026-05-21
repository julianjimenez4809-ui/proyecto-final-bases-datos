# Bases de Datos — ShopCo E-Commerce
**Motor:** PostgreSQL 17 · Supabase (shopco-ecommerce, us-east-1)  
**Exportado:** 21 de mayo de 2026

Esta carpeta contiene los datos reales exportados desde Supabase, organizados en dos grupos: las tablas del modelo relacional y los resultados de los queries de análisis de negocio.

---

## Estructura

```
7_bases_datos/
├── index.md                        ← este archivo
├── bd_version_inicial.md           ← AS-IS: BD problemática antes de la optimización
├── bd_version_evolucionada.md      ← TO-BE: cambios introducidos por la optimización
│
├── tablas/                         ← datos reales de cada tabla (9 CSVs)
│   ├── categoria.csv
│   ├── cliente.csv
│   ├── producto.csv
│   ├── inventario.csv
│   ├── pedido.csv
│   ├── detalle_pedido.csv
│   ├── pago.csv
│   ├── envio.csv
│   └── resena.csv
│
└── queries/                        ← resultados reales de los 6 queries de análisis (6 CSVs)
    ├── q1_revenue_por_categoria.csv
    ├── q2_ranking_clientes.csv
    ├── q3_performance_productos.csv
    ├── q4_transportistas.csv
    ├── q5_conversion_pagos.csv
    └── q6_resenas_productos.csv
```

---

## Tablas del modelo relacional

### categoria.csv — 9 registros
Jerarquía de dos niveles. Las 5 categorías raíz no tienen `categoria_padre_id`. Las 4 subcategorías referencian a su padre.

| Campo | Tipo | Descripción |
|---|---|---|
| categoria_id | UUID (PK) | Identificador único |
| nombre | VARCHAR | Nombre único de la categoría |
| descripcion | TEXT | Descripción del grupo |
| categoria_padre_id | UUID (FK nullable) | Referencia al padre; vacío = categoría raíz |

---

### cliente.csv — 8 registros
Compradores registrados en la plataforma. El `email` es único — garantizado por `uq_cliente_email`. `activo = false` implementa soft delete sin borrar historial.

| Campo | Tipo | Descripción |
|---|---|---|
| cliente_id | UUID (PK) | Identificador único |
| nombre / apellido | VARCHAR | Nombre completo |
| email | VARCHAR (UNIQUE) | Clave natural de identificación |
| telefono | VARCHAR | Opcional (nullable) |
| fecha_registro | DATE | Fecha de creación de cuenta |
| activo | BOOLEAN | false = cuenta desactivada |

---

### producto.csv — 10 registros
Catálogo activo. El campo `margen_pct` es calculado: `(precio_venta - precio_costo) / precio_venta * 100`. El constraint `ck_precio_venta_mayor_costo` garantiza que siempre sea positivo.

| Campo | Tipo | Descripción |
|---|---|---|
| producto_id | UUID (PK) | Identificador único |
| sku | VARCHAR (UNIQUE) | Código de referencia del producto |
| precio_costo | NUMERIC | Costo de adquisición |
| precio_venta | NUMERIC | Precio al público (≥ precio_costo) |
| margen_pct | NUMERIC | Margen bruto porcentual (calculado) |
| categoria_id | UUID (FK) | Referencia a categoria |

---

### inventario.csv — 10 registros
Relación 1-a-1 con producto. El `stock` de ELEC-SM-001 muestra `44` (decrementado desde `48` por el stored procedure `sp_procesar_pedido` ejecutado el 21 de mayo). `ultima_actualizacion` registra cuándo cambió por última vez.

| Campo | Tipo | Descripción |
|---|---|---|
| inventario_id | UUID (PK) | Identificador único |
| sku | VARCHAR | SKU del producto (para legibilidad) |
| stock | INTEGER (≥ 0) | Unidades disponibles en bodega |
| stock_minimo | INTEGER (≥ 0) | Umbral de alerta de reabastecimiento |
| ubicacion | VARCHAR | Bodega y estante |
| ultima_actualizacion | DATE | Última modificación del stock |

---

### pedido.csv — 10 registros seed + 1 generado por SP
El pedido `33eb6cc2-...` fue creado el 21 de mayo por `sp_procesar_pedido` directamente en producción — evidencia del stored procedure funcionando en Supabase. La columna `notas` lo marca con `[sp_procesar_pedido]`.

| Estado | Cantidad | Descripción |
|---|---|---|
| entregado | 4 | Ciclo completo completado |
| enviado | 1 | En tránsito con transportista |
| procesando | 3 | Pago confirmado, preparando despacho |
| pendiente | 3 | Esperando aprobación de pago |

---

### detalle_pedido.csv — 12 registros
Líneas de cada pedido. `subtotal = cantidad × precio_unitario × (1 - descuento/100)`. El `precio_unitario` es el precio histórico capturado al momento de la venta — no cambia si el producto sube de precio después.

---

### pago.csv — 10 registros seed + 1 generado por SP
7 pagos aprobados · 3 pendientes · 0 rechazados. PSE es el método con mayor revenue capturado ($9.798.000). El pago del pedido generado por SP está en estado `pendiente` — aguarda procesamiento de la pasarela Nequi.

---

### envio.csv — 6 registros
Solo los pedidos despachados tienen envío. 4 entregados, 1 en tránsito, 1 preparando. Servientrega tiene 100 % de tasa de entrega con promedio de 2 días.

---

### resena.csv — 5 registros
Todas vinculadas a compras reales verificadas (constraint `uq_resena_cliente_producto_pedido`). Calificación promedio: **4,8 / 5**. Valentina Ríos es la única cliente con múltiples reseñas (3 de 5 son suyas).

---

## Resultados de queries de análisis

### q1_revenue_por_categoria.csv
Revenue total agrupado por categoría principal. Electrónica genera el **80 %** del revenue total con solo 7 unidades vendidas vs 10 de Ropa y Moda.

### q2_ranking_clientes.csv
Clientes ordenados por gasto acumulado con segmento calculado por `fn_cliente_segmento()`. Valentina Ríos (Platinum) concentra el **41 %** del revenue total.

### q3_performance_productos.csv
Todos los productos del catálogo con revenue, margen, calificación y stock actual. Permite identificar oportunidades: Lenovo IdeaPad (31,8 % margen, 30 unidades, 0 reseñas) y Bicicleta MTB (mayor margen 36,8 %, stock crítico de 4).

### q4_transportistas.csv
Desempeño logístico por transportista. Servientrega lidera con 100 % de tasa de entrega y 2 días promedio.

### q5_conversion_pagos.csv
Tasa de aprobación y revenue capturado por método de pago. PSE es el método más confiable (100 %) y el de mayor revenue ($9,8M).

### q6_resenas_productos.csv
Satisfacción del cliente por producto. 4 productos con calificación perfecta 5/5. La Camiseta Polo Ralph Lauren tiene 4/5 — única con oportunidad de mejora en descripción o expectativas.

---

## Resumen de datos

| Tabla | Registros | Nota |
|---|---|---|
| categoria | 9 | 5 raíz + 4 subcategorías |
| cliente | 8 | Todos activos |
| producto | 10 | Todos activos |
| inventario | 10 | 1:1 con producto |
| pedido | 10 | + 1 generado por SP |
| detalle_pedido | 12 | 12 líneas en 11 pedidos |
| pago | 10 | + 1 generado por SP |
| envio | 6 | Solo pedidos despachados |
| resena | 5 | Promedio 4.8/5 |
| **Total registros** | **~92** | |
