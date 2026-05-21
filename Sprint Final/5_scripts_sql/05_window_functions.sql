-- =============================================================
-- ShopCo E-Commerce — Window Functions
-- =============================================================

-- -------------------------------------------------------------
-- W1. RANK — Ranking de productos por revenue dentro de cada categoría
-- -------------------------------------------------------------
SELECT
    cat.nombre                               AS categoria,
    pr.nombre                                AS producto,
    SUM(dp.cantidad * dp.precio_unitario
        * (1 - dp.descuento / 100.0))        AS revenue,
    RANK() OVER (
        PARTITION BY cat.categoria_id
        ORDER BY SUM(dp.cantidad * dp.precio_unitario * (1 - dp.descuento / 100.0)) DESC
    )                                        AS ranking_en_categoria
FROM detalle_pedido dp
INNER JOIN producto  pr  ON dp.producto_id  = pr.producto_id
INNER JOIN categoria cat ON pr.categoria_id = cat.categoria_id
INNER JOIN pedido    p   ON dp.pedido_id    = p.pedido_id
WHERE p.estado NOT IN ('cancelado')
GROUP BY cat.categoria_id, cat.nombre, pr.producto_id, pr.nombre
ORDER BY cat.nombre, ranking_en_categoria;

-- -------------------------------------------------------------
-- W2. ROW_NUMBER — Clientes ordenados por gasto acumulado
-- -------------------------------------------------------------
SELECT
    ROW_NUMBER() OVER (ORDER BY total_gastado DESC) AS posicion,
    cliente,
    email,
    total_pedidos,
    total_gastado,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY total_gastado DESC) = 1 THEN 'Platinum'
        WHEN ROW_NUMBER() OVER (ORDER BY total_gastado DESC) <= 3 THEN 'Gold'
        WHEN ROW_NUMBER() OVER (ORDER BY total_gastado DESC) <= 6 THEN 'Silver'
        ELSE 'Bronze'
    END AS segmento
FROM (
    SELECT
        c.nombre || ' ' || c.apellido AS cliente,
        c.email,
        COUNT(DISTINCT p.pedido_id)   AS total_pedidos,
        SUM(pa.monto)                 AS total_gastado
    FROM cliente c
    INNER JOIN pedido p ON c.cliente_id = p.cliente_id
    INNER JOIN pago  pa ON p.pedido_id  = pa.pedido_id
    WHERE pa.estado = 'aprobado'
    GROUP BY c.cliente_id, c.nombre, c.apellido, c.email
) resumen_clientes
ORDER BY posicion;

-- -------------------------------------------------------------
-- W3. LAG / LEAD — Comparación de ventas mes a mes
-- -------------------------------------------------------------
WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', p.fecha_pedido) AS mes,
        SUM(pa.monto)                        AS facturacion
    FROM pedido p
    INNER JOIN pago pa ON p.pedido_id = pa.pedido_id
    WHERE pa.estado = 'aprobado'
    GROUP BY DATE_TRUNC('month', p.fecha_pedido)
)
SELECT
    mes,
    facturacion,
    LAG(facturacion)  OVER (ORDER BY mes) AS facturacion_mes_anterior,
    LEAD(facturacion) OVER (ORDER BY mes) AS facturacion_mes_siguiente,
    ROUND(
        100.0 * (facturacion - LAG(facturacion) OVER (ORDER BY mes))
        / NULLIF(LAG(facturacion) OVER (ORDER BY mes), 0), 2
    ) AS crecimiento_pct
FROM ventas_mensuales
ORDER BY mes;

-- -------------------------------------------------------------
-- W4. SUM acumulado — Revenue acumulado en el tiempo por cliente
-- -------------------------------------------------------------
SELECT
    c.nombre || ' ' || c.apellido       AS cliente,
    p.fecha_pedido::DATE                AS fecha,
    pa.monto                            AS monto_pedido,
    SUM(pa.monto) OVER (
        PARTITION BY c.cliente_id
        ORDER BY p.fecha_pedido
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                   AS gasto_acumulado
FROM pedido p
INNER JOIN cliente c ON p.cliente_id = c.cliente_id
INNER JOIN pago   pa ON p.pedido_id  = pa.pedido_id
WHERE pa.estado = 'aprobado'
ORDER BY c.nombre, p.fecha_pedido;

-- -------------------------------------------------------------
-- W5. PERCENT_RANK — Percentil de precio de venta por categoría
-- -------------------------------------------------------------
SELECT
    cat.nombre        AS categoria,
    pr.nombre         AS producto,
    pr.precio_venta,
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY cat.categoria_id
            ORDER BY pr.precio_venta
        )::NUMERIC * 100, 1
    )                 AS percentil_precio,
    NTILE(4) OVER (
        PARTITION BY cat.categoria_id
        ORDER BY pr.precio_venta
    )                 AS cuartil
FROM producto pr
INNER JOIN categoria cat ON pr.categoria_id = cat.categoria_id
WHERE pr.activo = TRUE
ORDER BY cat.nombre, pr.precio_venta;
