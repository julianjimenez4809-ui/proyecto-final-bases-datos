-- =============================================================
-- ShopCo E-Commerce — Funciones
-- =============================================================

-- -------------------------------------------------------------
-- F1. fn_calcular_total_pedido
--     Retorna el monto total de un pedido aplicando descuentos
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_total_pedido(p_pedido_id UUID)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(
        SUM(cantidad * precio_unitario * (1 - descuento / 100.0)), 0
    )
    INTO v_total
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id;

    RETURN v_total;
END;
$$;

-- -------------------------------------------------------------
-- F2. fn_margen_producto
--     Retorna el margen de ganancia de un producto dado su ID
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_margen_producto(p_producto_id UUID)
RETURNS TABLE (
    sku             VARCHAR,
    nombre          VARCHAR,
    precio_costo    NUMERIC,
    precio_venta    NUMERIC,
    margen_absoluto NUMERIC,
    margen_pct      NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        pr.sku,
        pr.nombre,
        pr.precio_costo,
        pr.precio_venta,
        (pr.precio_venta - pr.precio_costo)                              AS margen_absoluto,
        ROUND((pr.precio_venta - pr.precio_costo)
              / NULLIF(pr.precio_venta, 0) * 100, 2)                     AS margen_pct
    FROM producto pr
    WHERE pr.producto_id = p_producto_id;
END;
$$;

-- -------------------------------------------------------------
-- F3. fn_cliente_segmento
--     Clasifica a un cliente según su gasto histórico total
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_cliente_segmento(p_cliente_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_gasto_total NUMERIC(12,2);
    v_segmento    TEXT;
BEGIN
    SELECT COALESCE(SUM(pa.monto), 0)
    INTO v_gasto_total
    FROM pedido p
    INNER JOIN pago pa ON p.pedido_id = pa.pedido_id
    WHERE p.cliente_id = p_cliente_id
      AND pa.estado     = 'aprobado';

    v_segmento := CASE
        WHEN v_gasto_total >= 5000000 THEN 'Platinum'
        WHEN v_gasto_total >= 2000000 THEN 'Gold'
        WHEN v_gasto_total >= 500000  THEN 'Silver'
        WHEN v_gasto_total >  0       THEN 'Bronze'
        ELSE 'Sin compras'
    END;

    RETURN v_segmento;
END;
$$;

-- =============================================================
-- EJEMPLOS DE USO
-- =============================================================

-- Total de un pedido específico
SELECT fn_calcular_total_pedido('e1000000-0000-0000-0000-000000000001') AS total_pedido_1;

-- Margen de un producto
SELECT * FROM fn_margen_producto('d1000000-0000-0000-0000-000000000002');

-- Segmento de todos los clientes activos
SELECT
    c.nombre || ' ' || c.apellido       AS cliente,
    fn_cliente_segmento(c.cliente_id)   AS segmento
FROM cliente c
WHERE c.activo = TRUE
ORDER BY cliente;
