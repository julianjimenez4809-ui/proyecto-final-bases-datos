-- =============================================================
-- ShopCo E-Commerce — Vistas (Views)
-- =============================================================

-- -------------------------------------------------------------
-- V1. Vista de pedidos completos
--     Une toda la información operativa de un pedido
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vista_pedidos_completos AS
SELECT
    p.pedido_id,
    p.fecha_pedido,
    p.estado                                   AS estado_pedido,
    c.nombre || ' ' || c.apellido              AS cliente,
    c.email,
    d.ciudad || ', ' || d.departamento         AS ciudad_destino,
    pa.metodo                                  AS metodo_pago,
    pa.estado                                  AS estado_pago,
    pa.monto                                   AS monto_pagado,
    e.transportista,
    e.numero_guia,
    e.estado                                   AS estado_envio,
    e.fecha_entrega_estimada,
    e.fecha_entrega_real,
    COUNT(dp.detalle_id)                       AS num_items,
    SUM(dp.cantidad)                           AS total_unidades,
    SUM(dp.cantidad * dp.precio_unitario
        * (1 - dp.descuento / 100.0))          AS total_calculado
FROM pedido p
INNER JOIN cliente        c  ON p.cliente_id   = c.cliente_id
INNER JOIN direccion      d  ON p.direccion_id = d.direccion_id
INNER JOIN detalle_pedido dp ON p.pedido_id    = dp.pedido_id
LEFT  JOIN pago           pa ON p.pedido_id    = pa.pedido_id
LEFT  JOIN envio          e  ON p.pedido_id    = e.pedido_id
GROUP BY
    p.pedido_id, p.fecha_pedido, p.estado,
    c.nombre, c.apellido, c.email,
    d.ciudad, d.departamento,
    pa.metodo, pa.estado, pa.monto,
    e.transportista, e.numero_guia, e.estado,
    e.fecha_entrega_estimada, e.fecha_entrega_real;

-- -------------------------------------------------------------
-- V2. Vista de inventario crítico
--     Productos cuyo stock está por debajo del mínimo
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vista_inventario_critico AS
SELECT
    pr.sku,
    pr.nombre                              AS producto,
    COALESCE(cat_padre.nombre, cat.nombre) AS categoria,
    i.stock,
    i.stock_minimo,
    (i.stock_minimo - i.stock)             AS unidades_faltantes,
    i.ubicacion,
    i.ultima_actualizacion,
    CASE
        WHEN i.stock = 0          THEN 'SIN STOCK'
        WHEN i.stock < i.stock_minimo THEN 'CRÍTICO'
        ELSE 'OK'
    END                                    AS nivel_alerta
FROM inventario i
INNER JOIN producto  pr        ON i.producto_id       = pr.producto_id
INNER JOIN categoria cat       ON pr.categoria_id     = cat.categoria_id
LEFT  JOIN categoria cat_padre ON cat.categoria_padre_id = cat_padre.categoria_id
WHERE pr.activo = TRUE
  AND i.stock <= i.stock_minimo
ORDER BY unidades_faltantes DESC;

-- -------------------------------------------------------------
-- V3. Vista de performance de productos
--     Combina ventas, margen y calificación promedio
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vista_performance_productos AS
SELECT
    pr.sku,
    pr.nombre                                          AS producto,
    cat.nombre                                         AS categoria,
    pr.precio_costo,
    pr.precio_venta,
    ROUND((pr.precio_venta - pr.precio_costo)
          / NULLIF(pr.precio_venta, 0) * 100, 2)       AS margen_pct,
    COALESCE(SUM(dp.cantidad), 0)                      AS unidades_vendidas,
    COALESCE(
        SUM(dp.cantidad * dp.precio_unitario
            * (1 - dp.descuento / 100.0)), 0
    )                                                  AS revenue_total,
    COALESCE(ROUND(AVG(r.calificacion)::NUMERIC, 2), 0) AS calificacion_promedio,
    COUNT(DISTINCT r.resena_id)                        AS num_resenas,
    i.stock                                            AS stock_actual
FROM producto pr
INNER JOIN categoria cat ON pr.categoria_id = cat.categoria_id
LEFT  JOIN inventario i  ON pr.producto_id  = i.producto_id
LEFT  JOIN detalle_pedido dp ON pr.producto_id = dp.producto_id
LEFT  JOIN pedido p ON dp.pedido_id = p.pedido_id
    AND p.estado NOT IN ('cancelado')
LEFT  JOIN resena r ON pr.producto_id = r.producto_id
WHERE pr.activo = TRUE
GROUP BY
    pr.sku, pr.nombre, cat.nombre,
    pr.precio_costo, pr.precio_venta,
    i.stock;

-- Verificar vistas creadas
SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN ('vista_pedidos_completos', 'vista_inventario_critico', 'vista_performance_productos');
