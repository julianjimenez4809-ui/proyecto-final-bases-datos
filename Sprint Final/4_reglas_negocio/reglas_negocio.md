# Biblioteca de Reglas de Negocio — ShopCo E-Commerce

Todas las reglas están implementadas como constraints en PostgreSQL (Supabase) y son verificables en tiempo de ejecución. Cada regla incluye el nombre exacto del constraint en la base de datos.

---

## CHECKs — Integridad de valores

| ID | Regla | Tabla | Columna | Constraint | Cláusula SQL | Impacto si se viola |
|---|---|---|---|---|---|---|
| RN-001 | **Margen de ganancia garantizado** | `producto` | `precio_venta / precio_costo` | `ck_precio_venta_mayor_costo` | `precio_venta >= precio_costo` | Venta a pérdida / error contable |
| RN-002 | **Stock no puede ser negativo** | `inventario` | `stock` | `ck_stock_no_negativo` | `stock >= 0` | Despacho de unidades inexistentes |
| RN-003 | **Stock mínimo válido** | `inventario` | `stock_minimo` | `ck_stock_minimo_positivo` | `stock_minimo >= 0` | Alertas de reabastecimiento inválidas |
| RN-004 | **Precio de costo no negativo** | `producto` | `precio_costo` | `producto_precio_costo_check` | `precio_costo >= 0` | Error contable en costo de inventario |
| RN-005 | **Monto de pago mayor a cero** | `pago` | `monto` | `pago_monto_check` | `monto > 0` | Registro de transacciones inválidas |
| RN-006 | **Cantidad de ítem mayor a cero** | `detalle_pedido` | `cantidad` | `detalle_pedido_cantidad_check` | `cantidad > 0` | Ítems fantasma / error de facturación |
| RN-007 | **Descuento entre 0 % y 100 %** | `detalle_pedido` | `descuento` | `detalle_pedido_descuento_check` | `descuento >= 0 AND descuento <= 100` | Cobros incorrectos o precio negativo |
| RN-008 | **Calificación de reseña entre 1 y 5** | `resena` | `calificacion` | `resena_calificacion_check` | `calificacion >= 1 AND calificacion <= 5` | Contaminación de métricas de calidad |

---

## ENUMs — Estados y valores permitidos

| ID | Regla | Tabla | Columna | Constraint | Valores válidos | Default |
|---|---|---|---|---|---|---|
| RN-009 | **Estados válidos de pedido** | `pedido` | `estado` | `pedido_estado_check` | `pendiente` · `procesando` · `enviado` · `entregado` · `cancelado` | `pendiente` |
| RN-010 | **Métodos de pago habilitados** | `pago` | `metodo` | `pago_metodo_check` | `tarjeta` · `pse` · `efectivo` · `nequi` · `daviplata` | — |
| RN-011 | **Estados válidos de pago** | `pago` | `estado` | `pago_estado_check` | `pendiente` · `aprobado` · `rechazado` · `reembolsado` | `pendiente` |
| RN-012 | **Estados válidos de envío** | `envio` | `estado` | `envio_estado_check` | `preparando` · `en_transito` · `entregado` · `devuelto` | `preparando` |

---

## UNIQUEs — Unicidad de entidades

| ID | Regla | Tabla | Columna(s) | Constraint | Impacto si se viola |
|---|---|---|---|---|---|
| RN-013 | **Email de cliente único** | `cliente` | `email` | `uq_cliente_email` | Duplicación de cuentas / fraude de identidad |
| RN-014 | **SKU de producto único** | `producto` | `sku` | `uq_producto_sku` | Confusión en despacho / error de inventario |
| RN-015 | **Un pago por pedido** | `pago` | `pedido_id` | `uq_pago_pedido` | Doble cobro al cliente |
| RN-016 | **Un envío por pedido** | `envio` | `pedido_id` | `uq_envio_pedido` | Duplicación de guías de transporte |
| RN-017 | **Un inventario por producto** | `inventario` | `producto_id` | `uq_inventario_producto` | Ambigüedad en el stock real del producto |
| RN-018 | **Una reseña por compra de producto** | `resena` | `(cliente_id, producto_id, pedido_id)` | `uq_resena_cliente_producto_pedido` | Manipulación de calificaciones |
| RN-019 | **Nombre de categoría único** | `categoria` | `nombre` | `uq_categoria_nombre` | Categorías duplicadas en el catálogo |

---

## FOREIGN KEYs — Integridad referencial

| ID | Regla | Tabla origen | Columna | Referencia | Impacto si se viola |
|---|---|---|---|---|---|
| RN-020 | **Dirección pertenece al cliente** | `direccion` | `cliente_id` | `cliente(cliente_id)` | Envío a dirección de otro cliente |
| RN-021 | **Pedido requiere cliente y dirección válidos** | `pedido` | `cliente_id`, `direccion_id` | `cliente`, `direccion` | Pedido sin destinatario identificable |
| RN-022 | **Detalle vinculado a pedido y producto reales** | `detalle_pedido` | `pedido_id`, `producto_id` | `pedido`, `producto` | Línea de pedido huérfana |
| RN-023 | **Reseña vinculada a compra verificada** | `resena` | `pedido_id`, `producto_id`, `cliente_id` | `pedido`, `producto`, `cliente` | Reseña sin compra real que la respalde |
| RN-024 | **Categoría puede tener padre** | `categoria` | `categoria_padre_id` | `categoria(categoria_id)` | Jerarquía circular o referencia rota |

---

## Resumen

| Tipo | Cantidad |
|---|---|
| CHECK (valores) | 8 |
| ENUM (estados) | 4 |
| UNIQUE (unicidad) | 7 |
| FOREIGN KEY (integridad referencial) | 5 |
| **Total** | **24 reglas** |

> Todas las reglas son verificables ejecutando en Supabase:
> ```sql
> SELECT constraint_name, constraint_type, check_clause
> FROM information_schema.table_constraints tc
> LEFT JOIN information_schema.check_constraints cc USING (constraint_name)
> WHERE tc.table_schema = 'public'
> ORDER BY table_name, constraint_type;
> ```
