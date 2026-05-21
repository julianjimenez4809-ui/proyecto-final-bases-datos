# Análisis de Resultados — ShopCo E-Commerce

Todas las queries fueron ejecutadas sobre la base de datos real en Supabase (`shopco-ecommerce`, us-east-1). Los resultados son datos reales del sistema.

---

## Q1 — Revenue por categoría

```sql
SELECT
    COALESCE(cat_padre.nombre, cat.nombre) AS categoria,
    COUNT(DISTINCT p.pedido_id)            AS pedidos,
    SUM(dp.cantidad)                       AS unidades,
    SUM(dp.cantidad * dp.precio_unitario * (1 - dp.descuento/100.0)) AS revenue_neto,
    ROUND(AVG(dp.precio_unitario),0)       AS precio_promedio
FROM detalle_pedido dp
JOIN producto pr ON dp.producto_id = pr.producto_id
JOIN categoria cat ON pr.categoria_id = cat.categoria_id
LEFT JOIN categoria cat_padre ON cat.categoria_padre_id = cat_padre.categoria_id
JOIN pedido p ON dp.pedido_id = p.pedido_id
WHERE p.estado NOT IN ('cancelado')
GROUP BY COALESCE(cat_padre.nombre, cat.nombre)
ORDER BY revenue_neto DESC;
```

**Resultado:**

| Categoría | Pedidos | Unidades | Revenue neto | Precio promedio |
|---|---|---|---|---|
| Electrónica | 6 | 7 | $16.453.200 | $2.599.000 |
| Ropa y Moda | 5 | 10 | $2.181.250 | $305.000 |
| Deportes | 1 | 1 | $1.899.000 | $1.899.000 |

**Insight accionable:** Electrónica genera el **80 % del revenue total** ($16.4M de $20.5M) con solo 7 unidades vendidas. Ropa vende más unidades (10) pero con ticket 8x menor. **Decisión:** priorizar stock y campañas de Electrónica para rentabilidad; en Ropa, evaluar estrategia de volumen con bundles. La categoría Deportes tiene un solo pedido — verificar si es nicho estratégico o catálogo desatendido.

---

## Q2 — Ranking de clientes por valor y segmento

```sql
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(pa.monto) DESC) AS ranking,
    c.nombre || ' ' || c.apellido  AS cliente,
    COUNT(DISTINCT p.pedido_id)    AS pedidos,
    SUM(pa.monto)                  AS total_gastado,
    fn_cliente_segmento(c.cliente_id) AS segmento
FROM cliente c
JOIN pedido p  ON c.cliente_id = p.cliente_id
JOIN pago   pa ON p.pedido_id  = pa.pedido_id
WHERE pa.estado = 'aprobado'
GROUP BY c.cliente_id, c.nombre, c.apellido
ORDER BY total_gastado DESC;
```

**Resultado:**

| Ranking | Cliente | Pedidos | Total gastado | Segmento |
|---|---|---|---|---|
| 1 | Valentina Ríos | 2 | $7.557.000 | Platinum |
| 2 | Sebastián Morales | 1 | $3.799.000 | Gold |
| 3 | Daniela Castro | 1 | $2.494.700 | Gold |
| 4 | Nicolás Pérez | 1 | $2.278.100 | Gold |
| 5 | Laura Vargas | 1 | $1.899.000 | Silver |
| 6 | Andrés Gutiérrez | 1 | $449.000 | Bronze |

**Insight accionable:** Valentina Ríos concentra el **41 % del revenue total** ($7.5M de $18.5M capturado) con 2 pedidos. La clienta Platinum merece programa de fidelización exclusivo (descuento anticipado, envío prioritario). El 83 % de los clientes activos tienen un solo pedido — **oportunidad clara de campañas de segunda compra** mediante email marketing.

---

## Q3 — Performance de productos: margen, revenue y calificación

```sql
SELECT * FROM vista_performance_productos
ORDER BY revenue_total DESC
LIMIT 5;
```

**Resultado:**

| SKU | Producto | Categoría | Margen % | Unidades | Revenue | Calificación | Stock |
|---|---|---|---|---|---|---|---|
| ELEC-LP-002 | MacBook Air M2 | Laptops | 24.99 % | 1 | $5.999.000 | 5.0 ⭐ | 8 |
| ELEC-SM-001 | Samsung Galaxy A54 | Smartphones | 29.11 % | 4 | $4.676.100 | 5.0 ⭐ | 44 |
| ELEC-SM-002 | iPhone 14 128GB | Smartphones | 26.30 % | 1 | $3.799.000 | 5.0 ⭐ | 12 |
| ELEC-LP-001 | Lenovo IdeaPad 3 | Laptops | 31.79 % | 1 | $1.979.100 | Sin reseñas | 30 |
| DEP-001 | Bicicleta MTB Trek | Deportes | 36.81 % | 1 | $1.899.000 | 5.0 ⭐ | 4 |

**Insight accionable:** La Bicicleta MTB tiene el **mayor margen (36.8 %)** pero solo 1 unidad vendida y **stock crítico de 4 unidades**. Urge reabastecimiento antes de campañas. El Lenovo IdeaPad 3 tiene 30 unidades en stock, 31.8 % de margen, pero **cero reseñas** — activar solicitud de reseña post-entrega para mejorar conversión orgánica.

---

## Q4 — Desempeño de transportistas

```sql
SELECT
    e.transportista,
    COUNT(*)   AS envios_totales,
    SUM(CASE WHEN e.estado = 'entregado' THEN 1 ELSE 0 END) AS entregados,
    ROUND(100.0 * SUM(CASE WHEN e.estado='entregado' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1) AS tasa_entrega_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.fecha_entrega_real - e.fecha_despacho))/86400.0)::NUMERIC, 1) AS dias_promedio
FROM envio e
GROUP BY e.transportista
ORDER BY tasa_entrega_pct DESC;
```

**Resultado:**

| Transportista | Envíos | Entregados | Tasa entrega | Días promedio |
|---|---|---|---|---|
| Servientrega | 2 | 2 | 100 % | 2.0 días |
| Envia | 2 | 1 | 50 % | 2.0 días |
| Coordinadora | 2 | 1 | 50 % | 2.0 días |

**Insight accionable:** Servientrega tiene **100 % de tasa de entrega** con 2 días promedio — candidato para ser transportista principal. Envia y Coordinadora tienen 50 % de tasa (1 envío pendiente cada uno) — monitorear en los próximos 30 días. Si la tasa no mejora, **renegociar SLA contractual o priorizar Servientrega** para pedidos de alto valor.

---

## Q5 — Tasa de conversión por método de pago

```sql
SELECT
    pa.metodo,
    COUNT(*)  AS total_intentos,
    SUM(CASE WHEN pa.estado = 'aprobado'  THEN 1 ELSE 0 END) AS aprobados,
    SUM(CASE WHEN pa.estado = 'rechazado' THEN 1 ELSE 0 END) AS rechazados,
    ROUND(100.0 * SUM(CASE WHEN pa.estado='aprobado' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1) AS tasa_aprobacion_pct,
    SUM(CASE WHEN pa.estado='aprobado' THEN pa.monto ELSE 0 END) AS revenue_capturado
FROM pago pa
GROUP BY pa.metodo
ORDER BY revenue_capturado DESC;
```

**Resultado:**

| Método | Intentos | Aprobados | Rechazados | Tasa aprobación | Revenue capturado |
|---|---|---|---|---|---|
| PSE | 2 | 2 | 0 | 100 % | $9.798.000 |
| Nequi | 3 | 2 | 0 | 66.7 % | $4.772.800 |
| Tarjeta | 4 | 3 | 0 | 75 % | $3.906.000 |
| Daviplata | 1 | 0 | 0 | 0 % | $0 |

**Insight accionable:** PSE es el método más confiable (100 % aprobación) y captura el mayor volumen ($9.7M). Tarjeta tiene 25 % de pagos pendientes — revisar si hay fricción en el formulario o timeout con la pasarela. Daviplata tiene 1 intento sin aprobación — verificar integración técnica con la pasarela antes de promoverlo activamente.

---

## Q6 — Satisfacción por producto (reseñas)

```sql
SELECT
    pr.nombre AS producto, cat.nombre AS categoria,
    COUNT(r.resena_id) AS num_resenas,
    ROUND(AVG(r.calificacion),2) AS calificacion_promedio,
    STRING_AGG(r.comentario, ' | ') AS comentarios
FROM resena r
JOIN producto pr ON r.producto_id = pr.producto_id
JOIN categoria cat ON pr.categoria_id = cat.categoria_id
GROUP BY pr.nombre, cat.nombre
ORDER BY calificacion_promedio DESC;
```

**Resultado:**

| Producto | Categoría | Reseñas | Calificación | Comentario |
|---|---|---|---|---|
| Bicicleta MTB Trek Marlin | Deportes | 1 | 5.0 ⭐ | "La bicicleta llegó casi armada, muy buena calidad." |
| iPhone 14 128GB | Smartphones | 1 | 5.0 ⭐ | "El iPhone es perfecto, muy bien empacado." |
| MacBook Air M2 | Laptops | 1 | 5.0 ⭐ | "El MacBook superó mis expectativas, lo recomiendo." |
| Samsung Galaxy A54 | Smartphones | 1 | 5.0 ⭐ | "Excelente teléfono, llegó en perfecto estado." |
| Camiseta Polo Ralph Lauren | Camisetas | 1 | 4.0 ⭐ | "Buena calidad, el color es tal cual la foto." |

**Insight accionable:** NPS implícito muy alto — 4 productos con 5/5 estrellas. El único con 4 estrellas (Camiseta Polo) recibe comentario positivo pero no perfecto — revisar si el problema es la talla, el material o la expectativa de color. **Acción inmediata:** usar los comentarios 5/5 como social proof en el catálogo y campañas de redes sociales.

---

## Resumen ejecutivo de resultados

| Métrica | Valor | Lectura |
|---|---|---|
| Revenue total capturado | $18.476.800 | Pagos aprobados en el período |
| Categoría líder | Electrónica | 80 % del revenue, 6 pedidos |
| Cliente más valioso | Valentina Ríos | $7.5M, Platinum, 2 pedidos |
| Producto con mayor margen | Bicicleta MTB (36.8 %) | Stock crítico: reabatecer urgente |
| Transportista más confiable | Servientrega | 100 % tasa, 2 días promedio |
| Método de pago top | PSE | 100 % aprobación, $9.7M |
| Calificación promedio | 4.8 / 5 | Alta satisfacción del cliente |
| Clientes con 1 solo pedido | 83 % | Oportunidad de retención |
