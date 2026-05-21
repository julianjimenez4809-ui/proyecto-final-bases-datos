-- =============================================================
-- ShopCo E-Commerce — Stored Procedure
-- sp_procesar_pedido: crea un pedido completo validando stock
-- =============================================================
-- Parámetros de entrada:
--   p_cliente_id   UUID  — ID del cliente
--   p_direccion_id UUID  — ID de la dirección de entrega
--   p_items        JSONB — Array de ítems: [{producto_id, cantidad, descuento}]
--   p_metodo_pago  TEXT  — Método de pago ('tarjeta','pse','efectivo','nequi','daviplata')
--
-- Retorna: pedido_id del pedido creado (o lanza excepción si hay error)
-- =============================================================

CREATE OR REPLACE PROCEDURE sp_procesar_pedido(
    IN  p_cliente_id   UUID,
    IN  p_direccion_id UUID,
    IN  p_items        JSONB,
    IN  p_metodo_pago  TEXT,
    OUT p_pedido_id    UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item          JSONB;
    v_producto_id   UUID;
    v_cantidad      INTEGER;
    v_descuento     NUMERIC(5,2);
    v_precio_venta  NUMERIC(12,2);
    v_stock_actual  INTEGER;
    v_total_pedido  NUMERIC(12,2) := 0;
    v_subtotal      NUMERIC(12,2);
BEGIN
    -- Validar que el cliente existe y está activo
    IF NOT EXISTS (
        SELECT 1 FROM cliente WHERE cliente_id = p_cliente_id AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Cliente % no existe o está inactivo', p_cliente_id;
    END IF;

    -- Validar que la dirección pertenece al cliente
    IF NOT EXISTS (
        SELECT 1 FROM direccion
        WHERE direccion_id = p_direccion_id AND cliente_id = p_cliente_id
    ) THEN
        RAISE EXCEPTION 'Dirección % no pertenece al cliente %', p_direccion_id, p_cliente_id;
    END IF;

    -- Validar items no vacíos
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El pedido debe contener al menos un ítem';
    END IF;

    -- Validar stock para todos los ítems antes de crear nada (validación atómica)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::UUID;
        v_cantidad    := (v_item->>'cantidad')::INTEGER;

        SELECT i.stock INTO v_stock_actual
        FROM inventario i
        WHERE i.producto_id = v_producto_id;

        IF v_stock_actual IS NULL THEN
            RAISE EXCEPTION 'Producto % no tiene registro de inventario', v_producto_id;
        END IF;

        IF v_stock_actual < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para producto %. Disponible: %, solicitado: %',
                v_producto_id, v_stock_actual, v_cantidad;
        END IF;
    END LOOP;

    -- Crear el pedido
    INSERT INTO pedido (cliente_id, direccion_id, estado)
    VALUES (p_cliente_id, p_direccion_id, 'pendiente')
    RETURNING pedido_id INTO p_pedido_id;

    -- Insertar ítems, descontar stock y acumular total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::UUID;
        v_cantidad    := (v_item->>'cantidad')::INTEGER;
        v_descuento   := COALESCE((v_item->>'descuento')::NUMERIC, 0);

        SELECT precio_venta INTO v_precio_venta
        FROM producto WHERE producto_id = v_producto_id;

        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, descuento)
        VALUES (p_pedido_id, v_producto_id, v_cantidad, v_precio_venta, v_descuento);

        -- Descontar del inventario
        UPDATE inventario
        SET stock                = stock - v_cantidad,
            ultima_actualizacion = now()
        WHERE producto_id = v_producto_id;

        -- Acumular total
        v_subtotal     := v_cantidad * v_precio_venta * (1 - v_descuento / 100.0);
        v_total_pedido := v_total_pedido + v_subtotal;
    END LOOP;

    -- Registrar el pago en estado pendiente
    INSERT INTO pago (pedido_id, metodo, estado, monto)
    VALUES (p_pedido_id, p_metodo_pago, 'pendiente', v_total_pedido);

    -- Cambiar estado del pedido a procesando
    UPDATE pedido
    SET estado = 'procesando', fecha_actualizacion = now()
    WHERE pedido_id = p_pedido_id;

    RAISE NOTICE 'Pedido % creado exitosamente. Total: $%', p_pedido_id, v_total_pedido;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- =============================================================
-- EJEMPLO DE USO:
-- =============================================================
/*
DO $$
DECLARE
    v_nuevo_pedido UUID;
BEGIN
    CALL sp_procesar_pedido(
        'b1000000-0000-0000-0000-000000000004',   -- cliente_id (Pedro Hernández)
        'c1000000-0000-0000-0000-000000000004',   -- direccion_id
        '[
            {"producto_id": "d1000000-0000-0000-0000-000000000004", "cantidad": 2, "descuento": 0},
            {"producto_id": "d1000000-0000-0000-0000-000000000010", "cantidad": 1, "descuento": 5}
        ]'::JSONB,
        'nequi',
        v_nuevo_pedido
    );
    RAISE NOTICE 'Pedido creado: %', v_nuevo_pedido;
END;
$$;
*/
