# Base de Datos — Versión Evolucionada
**Fecha de exportación:** 21 de mayo de 2026  
**Motor:** PostgreSQL 17 — Supabase (shopco-ecommerce, us-east-1)  
**Estado:** Producción activa — incluye transacciones reales, vistas, funciones y SP ejecutados

---

## Cambios respecto a la versión inicial

| Elemento | Cambio | Mecanismo |
|---|---|---|
| `inventario` ELEC-SM-001 | stock: 48 → 44 (-4 unidades vendidas) | `sp_procesar_pedido` |
| `inventario` ELEC-LP-002 | stock: 9 → 8 (-1 unidad vendida) | `sp_procesar_pedido` |
| `pedido` | 10 → **11 pedidos** (+1 via stored procedure) | `sp_procesar_pedido` |
| `pago` | 10 → **11 pagos** (+1 Nequi pendiente $1.199.000) | `sp_procesar_pedido` |
| `detalle_pedido` | +1 línea (Samsung A54 × 1 para Valentina Ríos) | `sp_procesar_pedido` |
| Vistas creadas | `vista_pedidos_completos`, `vista_inventario_critico`, `vista_performance_productos` | `06_vistas.sql` |
| Funciones creadas | `fn_calcular_total_pedido`, `fn_margen_producto`, `fn_cliente_segmento` | `08_funcion.sql` |
| Stored procedure creado | `sp_procesar_pedido` | `07_stored_procedure.sql` |
| Índices creados | 8 índices en tablas de alta consulta | `01_ddl.sql` |

---

## inventario (10 registros — estado actual)

| sku | producto | stock_inicial | stock_actual | diferencia | alerta |
|---|---|---|---|---|---|
| DEP-001 | Bicicleta MTB Trek Marlin | 5 | **4** | -1 | ⚠️ Cerca del mínimo (2) |
| ELEC-LP-001 | Lenovo IdeaPad 3 | 30 | **30** | 0 | ✅ OK |
| ELEC-LP-002 | MacBook Air M2 | 9 | **8** | -1 | ✅ OK |
| ELEC-SM-001 | Samsung Galaxy A54 | 48 | **44** | -4 | ✅ OK |
| ELEC-SM-002 | iPhone 14 128GB | 12 | **12** | 0 | ✅ OK |
| HOGAR-001 | Licuadora Oster Pro | 60 | **60** | 0 | ✅ OK |
| ROPA-CAL-001 | Tenis Nike Air Max 270 | 35 | **35** | 0 | ✅ OK |
| ROPA-CAL-002 | Tenis Adidas Ultraboost 22 | 22 | **22** | 0 | ✅ OK |
| ROPA-CAM-001 | Camiseta Polo Ralph Lauren | 120 | **120** | 0 | ✅ OK |
| ROPA-CAM-002 | Camiseta Nike Dri-FIT | 95 | **95** | 0 | ✅ OK |

---

## pedido (11 registros — estado actual)

| # | cliente | ciudad | estado | fecha | origen |
|---|---|---|---|---|---|
| 1 | Valentina Ríos | Bogotá | entregado | mar 17, 2026 | seed |
| 2 | Laura Vargas | Pereira | entregado | abr 01, 2026 | seed |
| 3 | Valentina Ríos | Bogotá | entregado | abr 16, 2026 | seed |
| 4 | Sebastián Morales | Medellín | entregado | abr 21, 2026 | seed |
| 5 | Daniela Castro | Cali | enviado | may 11, 2026 | seed |
| 6 | Nicolás Pérez | Bogotá | procesando | may 13, 2026 | seed |
| 7 | Andrés Gutiérrez | Barranquilla | procesando | may 14, 2026 | seed |
| 8 | Camila Herrera | Bogotá | pendiente | may 15, 2026 | seed |
| 9 | Felipe Mendoza | Bogotá | pendiente | may 15, 2026 | seed |
| 10 | Sebastián Morales | Medellín | pendiente | may 16, 2026 | seed |
| **11** | **Valentina Ríos** | **Bogotá** | **procesando** | **may 21, 2026** | **sp_procesar_pedido** ✨ |

---

## pago (11 registros — estado actual)

| cliente | método | estado | monto | origen |
|---|---|---|---|---|
| Valentina Ríos | PSE | aprobado | $5.999.000 | seed |
| Laura Vargas | tarjeta | aprobado | $1.899.000 | seed |
| Valentina Ríos | tarjeta | aprobado | $1.558.000 | seed |
| Sebastián Morales | PSE | aprobado | $3.799.000 | seed |
| Daniela Castro | Nequi | aprobado | $2.494.700 | seed |
| Nicolás Pérez | Nequi | aprobado | $2.278.100 | seed |
| Andrés Gutiérrez | tarjeta | aprobado | $449.000 | seed |
| Camila Herrera | Daviplata | pendiente | $508.150 | seed |
| Felipe Mendoza | tarjeta | pendiente | $567.000 | seed |
| Sebastián Morales | tarjeta | pendiente | $567.000 | seed |
| **Valentina Ríos** | **Nequi** | **pendiente** | **$1.199.000** | **sp_procesar_pedido** ✨ |

---

## Objetos de base de datos creados en la evolución

### Vistas

| Vista | Descripción | Query de uso |
|---|---|---|
| `vista_pedidos_completos` | Une pedido + cliente + dirección + pago + envío en una sola fila | `SELECT * FROM vista_pedidos_completos` |
| `vista_inventario_critico` | Productos con stock ≤ stock_mínimo | `SELECT * FROM vista_inventario_critico` |
| `vista_performance_productos` | Revenue + margen + calificación por producto | `SELECT * FROM vista_performance_productos ORDER BY revenue_total DESC` |

### Funciones

| Función | Entrada | Retorna | Ejemplo |
|---|---|---|---|
| `fn_calcular_total_pedido(uuid)` | `pedido_id` | `NUMERIC` — total con descuentos | `SELECT fn_calcular_total_pedido('55555555-...-0001')` → $1.558.100 |
| `fn_margen_producto(uuid)` | `producto_id` | Tabla (sku, nombre, costos, margen %) | `SELECT * FROM fn_margen_producto('44444444-...-0001')` → 29,11 % |
| `fn_cliente_segmento(uuid)` | `cliente_id` | `TEXT` — Bronze/Silver/Gold/Platinum | `SELECT fn_cliente_segmento('22222222-...-0001')` → 'Platinum' |

### Stored Procedure

| Procedure | Descripción |
|---|---|
| `sp_procesar_pedido(cliente_id, direccion_id, items JSONB, metodo)` | Valida stock, crea pedido + detalle + pago atómicamente, descuenta inventario. Lanza excepción si stock insuficiente o cliente inactivo. |

### Índices de soporte

| Índice | Tabla | Columna | Beneficio |
|---|---|---|---|
| `idx_pedido_cliente` | `pedido` | `cliente_id` | Acelera historial de cliente |
| `idx_pedido_estado` | `pedido` | `estado` | Filtros operativos por estado |
| `idx_detalle_pedido` | `detalle_pedido` | `pedido_id` | JOIN con pedido |
| `idx_detalle_producto` | `detalle_pedido` | `producto_id` | JOIN con producto |
| `idx_pago_estado` | `pago` | `estado` | Filtros de pagos pendientes |
| `idx_envio_estado` | `envio` | `estado` | Seguimiento logístico |
| `idx_resena_producto` | `resena` | `producto_id` | Calificaciones por producto |
| `idx_producto_categoria` | `producto` | `categoria_id` | Navegación de catálogo |

---

## Métricas de la BD evolucionada

| Métrica | Valor |
|---|---|
| Total tablas | 10 |
| Total registros (todas las tablas) | ~111 |
| Total vistas | 3 |
| Total funciones | 3 |
| Total stored procedures | 1 |
| Total índices creados | 8 |
| Total reglas de negocio (constraints) | 24 |
| Revenue total aprobado | $18.476.800 COP |
| Clientes activos | 8 |
| Pedidos procesados | 11 |
