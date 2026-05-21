-- =============================================================
-- ShopCo E-Commerce — Agregaciones (GROUP BY / HAVING)
-- =============================================================

-- -------------------------------------------------------------
-- A1. Revenue total por categoría principal
-- -------------------------------------------------------------
SELECT
    COALESCE(cat_padre.nombre, cat.nombre) AS categoria_principal,
    COUNT(DISTINCT dp.pedido_id)           AS num_pedidos,
    SUM(dp.cantidad)                       AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario * (1 - dp.descuento / 100.0)) AS revenue_neto,
    AVG(dp.precio_unitario)                AS precio_promedio
FROM detalle_pedido dp
INNER JOIN producto  pr  ON dp.producto_id      = pr.producto_id
INNER JOIN categoria cat ON pr.categoria_id     = cat.categoria_id
LEFT  JOIN categoria cat_padre ON cat.categoria_padre_id = cat_padre.categoria_id
INNER JOIN pedido    p   ON dp.pedido_id        = p.pedido_id
WHERE p.estado NOT IN ('cancelado')
GROUP BY COALESCE(cat_padre.nombre, cat.nombre)
ORDER BY revenue_neto DESC;

-- -------------------------------------------------------------
-- A2. Resumen de pedidos por estado y método de pago
-- -------------------------------------------------------------
SELECT
    p.estado          AS estado_pedido,
    pa.metodo         AS metodo_pago,
    COUNT(*)          AS cantidad_pedidos,
    SUM(pa.monto)     AS monto_total,
    AVG(pa.monto)     AS ticket_promedio,
    MIN(pa.monto)     AS ticket_minimo,
    MAX(pa.monto)     AS ticket_maximo
FROM pedido p
INNER JOIN pago pa ON p.pedido_id = pa.pedido_id
GROUP BY p.estado, pa.metodo
ORDER BY p.estado, monto_total DESC;

-- -------------------------------------------------------------
-- A3. Clientes con más de 1 pedido (HAVING)
-- -------------------------------------------------------------
SELECT
    c.nombre || ' ' || c.apellido AS cliente,
    c.email,
    COUNT(p.pedido_id)            AS total_pedidos,
    SUM(pa.monto)                 AS total_gastado,
    MAX(p.fecha_pedido)           AS ultimo_pedido
FROM cliente c
INNER JOIN pedido p ON c.cliente_id = p.cliente_id
INNER JOIN pago  pa ON p.pedido_id  = pa.pedido_id
WHERE pa.estado = 'aprobado'
GROUP BY c.cliente_id, c.nombre, c.apellido, c.email
HAVING COUNT(p.pedido_id) > 1
ORDER BY total_gastado DESC;

-- -------------------------------------------------------------
-- A4. Productos más vendidos (TOP 5 por unidades)
-- -------------------------------------------------------------
SELECT
    pr.sku,
    pr.nombre                                AS producto,
    cat.nombre                               AS categoria,
    SUM(dp.cantidad)                         AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario
        * (1 - dp.descuento / 100.0))        AS revenue_generado,
    ROUND(AVG(r.calificacion), 2)            AS calificacion_promedio
FROM detalle_pedido dp
INNER JOIN producto  pr  ON dp.producto_id  = pr.producto_id
INNER JOIN categoria cat ON pr.categoria_id = cat.categoria_id
INNER JOIN pedido    p   ON dp.pedido_id    = p.pedido_id
LEFT  JOIN resena    r   ON r.producto_id   = pr.producto_id
WHERE p.estado NOT IN ('cancelado')
GROUP BY pr.sku, pr.nombre, cat.nombre
ORDER BY unidades_vendidas DESC
LIMIT 5;

-- -------------------------------------------------------------
-- A5. Ventas por mes (tendencia temporal)
-- -------------------------------------------------------------
SELECT
    DATE_TRUNC('month', p.fecha_pedido)   AS mes,
    COUNT(DISTINCT p.pedido_id)           AS pedidos,
    COUNT(DISTINCT p.cliente_id)          AS clientes_activos,
    SUM(pa.monto)                         AS facturacion_total,
    AVG(pa.monto)                         AS ticket_promedio
FROM pedido p
INNER JOIN pago pa ON p.pedido_id = pa.pedido_id
WHERE pa.estado = 'aprobado'
GROUP BY DATE_TRUNC('month', p.fecha_pedido)
ORDER BY mes DESC;

-- -------------------------------------------------------------
-- A6. Transportistas: desempeño de entrega
-- -------------------------------------------------------------
SELECT
    e.transportista,
    COUNT(*)                               AS envios_totales,
    SUM(CASE WHEN e.estado = 'entregado' THEN 1 ELSE 0 END) AS entregados,
    SUM(CASE WHEN e.estado = 'devuelto'  THEN 1 ELSE 0 END) AS devueltos,
    ROUND(
        100.0 * SUM(CASE WHEN e.estado = 'entregado' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                      AS tasa_entrega_pct,
    AVG(
        EXTRACT(EPOCH FROM (e.fecha_entrega_real - e.fecha_despacho)) / 86400.0
    )::NUMERIC(5,2)                        AS dias_promedio_entrega
FROM envio e
GROUP BY e.transportista
ORDER BY tasa_entrega_pct DESC;
