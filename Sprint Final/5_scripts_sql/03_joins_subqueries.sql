-- =============================================================
-- ShopCo E-Commerce — JOINs y Subconsultas
-- =============================================================

-- -------------------------------------------------------------
-- J1. Pedidos completos: cliente + dirección + estado + total
-- -------------------------------------------------------------
SELECT
    c.nombre || ' ' || c.apellido          AS cliente,
    d.ciudad,
    p.pedido_id,
    p.estado,
    p.fecha_pedido,
    SUM(dp.cantidad * dp.precio_unitario * (1 - dp.descuento / 100.0)) AS total_pedido
FROM pedido p
INNER JOIN cliente   c  ON p.cliente_id  = c.cliente_id
INNER JOIN direccion d  ON p.direccion_id = d.direccion_id
INNER JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id
GROUP BY c.nombre, c.apellido, d.ciudad, p.pedido_id, p.estado, p.fecha_pedido
ORDER BY p.fecha_pedido DESC;

-- -------------------------------------------------------------
-- J2. Productos vendidos con su categoría (incluyendo padre)
-- -------------------------------------------------------------
SELECT
    cat_hijo.nombre  AS subcategoria,
    cat_padre.nombre AS categoria_principal,
    pr.sku,
    pr.nombre        AS producto,
    pr.precio_venta,
    SUM(dp.cantidad) AS unidades_vendidas
FROM detalle_pedido dp
INNER JOIN producto  pr        ON dp.producto_id      = pr.producto_id
INNER JOIN categoria cat_hijo  ON pr.categoria_id     = cat_hijo.categoria_id
LEFT  JOIN categoria cat_padre ON cat_hijo.categoria_padre_id = cat_padre.categoria_id
INNER JOIN pedido    p         ON dp.pedido_id        = p.pedido_id
WHERE p.estado NOT IN ('cancelado')
GROUP BY cat_hijo.nombre, cat_padre.nombre, pr.sku, pr.nombre, pr.precio_venta
ORDER BY unidades_vendidas DESC;

-- -------------------------------------------------------------
-- J3. Estado de envío vs estado de pedido (JOIN triple)
-- -------------------------------------------------------------
SELECT
    p.pedido_id,
    c.nombre || ' ' || c.apellido AS cliente,
    p.estado           AS estado_pedido,
    e.transportista,
    e.numero_guia,
    e.estado           AS estado_envio,
    e.fecha_entrega_estimada,
    e.fecha_entrega_real,
    CASE
        WHEN e.fecha_entrega_real <= e.fecha_entrega_estimada::timestamptz THEN 'A tiempo'
        WHEN e.fecha_entrega_real >  e.fecha_entrega_estimada::timestamptz THEN 'Tardío'
        ELSE 'En curso'
    END AS cumplimiento
FROM pedido p
INNER JOIN cliente  c ON p.cliente_id = c.cliente_id
LEFT  JOIN envio    e ON p.pedido_id  = e.pedido_id
ORDER BY p.fecha_pedido DESC;

-- -------------------------------------------------------------
-- J4. Reseñas con datos completos de cliente y producto
-- -------------------------------------------------------------
SELECT
    c.nombre || ' ' || c.apellido AS cliente,
    pr.nombre                     AS producto,
    r.calificacion,
    r.comentario,
    r.fecha_resena
FROM resena r
INNER JOIN cliente  c  ON r.cliente_id  = c.cliente_id
INNER JOIN producto pr ON r.producto_id = pr.producto_id
ORDER BY r.fecha_resena DESC;

-- -------------------------------------------------------------
-- S1. Subconsulta: clientes que han gastado más que el promedio
-- -------------------------------------------------------------
SELECT
    c.nombre || ' ' || c.apellido AS cliente,
    c.email,
    total_gastado.monto_total
FROM cliente c
INNER JOIN (
    SELECT
        p.cliente_id,
        SUM(dp.cantidad * dp.precio_unitario * (1 - dp.descuento / 100.0)) AS monto_total
    FROM pedido p
    INNER JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id
    WHERE p.estado NOT IN ('cancelado')
    GROUP BY p.cliente_id
) AS total_gastado ON c.cliente_id = total_gastado.cliente_id
WHERE total_gastado.monto_total > (
    SELECT AVG(sub.monto_total)
    FROM (
        SELECT
            p2.cliente_id,
            SUM(dp2.cantidad * dp2.precio_unitario * (1 - dp2.descuento / 100.0)) AS monto_total
        FROM pedido p2
        INNER JOIN detalle_pedido dp2 ON p2.pedido_id = dp2.pedido_id
        WHERE p2.estado NOT IN ('cancelado')
        GROUP BY p2.cliente_id
    ) sub
)
ORDER BY total_gastado.monto_total DESC;

-- -------------------------------------------------------------
-- S2. Subconsulta correlacionada: productos sin ventas recientes
--     (no vendidos en los últimos 30 días)
-- -------------------------------------------------------------
SELECT
    pr.sku,
    pr.nombre,
    pr.precio_venta,
    i.stock
FROM producto pr
INNER JOIN inventario i ON pr.producto_id = i.producto_id
WHERE pr.activo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM detalle_pedido dp
      INNER JOIN pedido p ON dp.pedido_id = p.pedido_id
      WHERE dp.producto_id = pr.producto_id
        AND p.fecha_pedido >= now() - INTERVAL '30 days'
        AND p.estado NOT IN ('cancelado')
  )
ORDER BY i.stock DESC;

-- -------------------------------------------------------------
-- S3. Productos con stock por debajo del mínimo (alerta)
-- -------------------------------------------------------------
SELECT
    pr.sku,
    pr.nombre,
    cat.nombre  AS categoria,
    i.stock,
    i.stock_minimo,
    (i.stock_minimo - i.stock) AS unidades_faltantes,
    i.ubicacion
FROM inventario i
INNER JOIN producto  pr ON i.producto_id  = pr.producto_id
INNER JOIN categoria cat ON pr.categoria_id = cat.categoria_id
WHERE i.stock < i.stock_minimo
ORDER BY unidades_faltantes DESC;
