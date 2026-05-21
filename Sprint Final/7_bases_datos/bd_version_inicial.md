# Base de Datos — Versión Inicial (AS-IS)
**Empresa:** ShopCo S.A.S. — E-Commerce Colombia  
**Período:** Enero 2023 – Abril 2026 (3 años de operación sin optimización)  
**Motor original:** PostgreSQL 14 — servidor VPS único (DigitalOcean, $20 USD/mes)  
**Problema:** Base de datos construida en el lanzamiento rápido del MVP, nunca refactorizada

---

## Contexto del problema

ShopCo fue fundada en 2023 con el objetivo de vender electrónica, ropa y artículos deportivos online en Colombia. Para salir rápido al mercado, el equipo técnico (1 desarrollador) construyó la base de datos en 2 semanas. El resultado fue funcional para 10–20 pedidos/mes, pero al crecer a 500 pedidos/mes el sistema comenzó a mostrar fallas críticas.

---

## Esquema original (2 tablas principales, sin normalizar)

```sql
-- TABLA 1: ventas (mezcla pedido + cliente + pago + envío en una sola fila)
CREATE TABLE ventas (
    id              SERIAL PRIMARY KEY,
    cliente_nombre  VARCHAR(200),        -- se repite en cada compra
    cliente_email   VARCHAR(200),        -- sin UNIQUE, hay duplicados
    cliente_tel     VARCHAR(20),
    direccion       TEXT,                -- "Cra 10 #45-20, Bogotá, Cundinamarca" todo junto
    producto_nombre VARCHAR(200),        -- nombre libre, sin referencia a tabla
    producto_precio NUMERIC,             -- sin CHECK, acepta valores negativos
    cantidad        INTEGER,             -- sin CHECK, acepta 0 o negativos
    descuento       NUMERIC,             -- sin límite, puede superar el 100 %
    metodo_pago     VARCHAR(50),         -- texto libre: 'tarjeta', 'Tarjeta', 'TARJETA DEBITO'
    estado          VARCHAR(50),         -- texto libre: 'enviado','Enviado','en camino','despachado'
    transportista   VARCHAR(100),
    guia            VARCHAR(100),
    fecha_venta     TIMESTAMP DEFAULT now()
    -- sin estado_pago separado del estado_pedido
    -- sin referencia_pago externa
    -- sin fecha_actualizacion
);

-- TABLA 2: productos (sin normalización de categoría ni control de inventario)
CREATE TABLE productos (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200),
    descripcion TEXT,
    precio      NUMERIC,            -- sin CHECK, precio puede ser 0 o negativo
    stock       INTEGER,            -- sin CHECK, puede volverse negativo
    categoria   VARCHAR(100),       -- texto libre, sin tabla de referencia
    activo      BOOLEAN DEFAULT TRUE
    -- sin sku único
    -- sin distinción precio_costo vs precio_venta
    -- sin fecha_creacion
    -- sin stock_minimo de alerta
);
```

**Total tablas:** 2  
**Constraints de integridad:** 0 (solo PRIMARY KEY)  
**Foreign keys:** 0  
**Vistas analíticas:** 0  
**Stored procedures:** 0  
**Índices:** 0

---

## Datos reales exportados de la versión inicial

### ventas (muestra de 10 registros — problemas resaltados)

| id | cliente_email | producto_nombre | precio | cantidad | estado | metodo_pago |
|---|---|---|---|---|---|---|
| 1 | vrios@gmail.com | MacBook Air M2 | 5999000 | 1 | **enviado** | pse |
| 2 | lvargas@gmail.com | Bicicleta MTB | 1899000 | 1 | **Enviado** | tarjeta |
| 3 | vrios@gmail.com | Samsung A54 | 1199000 | 1 | **entregado** | tarjeta |
| 4 | smorales@hotmail.com | iPhone 14 | 3799000 | 1 | **entregado** | PSE |
| 5 | dcastro@yahoo.com | Lenovo IdeaPad | 2199000 | 1 | **en camino** | nequi |
| 6 | nperez@gmail.com | Tenis Nike | **-449000** | 1 | procesando | nequi |
| 7 | agutierrez@gmail.com | Camiseta Polo | 189000 | **0** | procesando | tarjeta |
| 8 | cherrera@gmail.com | Tenis Adidas | 599000 | 1 | pendiente | daviplata |
| 9 | vrios@gmail.com | Samsung A54 | 1199000 | **-2** | pendiente | tarjeta |
| 10 | smorales@hotmail.com | MacBook Air M2 | 5999000 | 1 | pendiente | tarjeta |

> Filas en negrita: errores reales encontrados en producción — precio negativo (fila 6), cantidad cero (fila 7), cantidad negativa (fila 9), estados inconsistentes ("enviado" vs "Enviado" vs "en camino").

### productos (10 registros — sin control de stock ni margen)

| id | nombre | precio | stock | categoria |
|---|---|---|---|---|
| 1 | Samsung Galaxy A54 | 1199000 | **-3** | Electrónica |
| 2 | iPhone 14 128GB | 3799000 | 12 | Electrónica |
| 3 | Lenovo IdeaPad 3 | 2199000 | 30 | **electronica** |
| 4 | MacBook Air M2 | 5999000 | 8 | Electrónica |
| 5 | Camiseta Polo Ralph Lauren | 189000 | 120 | Ropa |
| 6 | Camiseta Nike Dri-FIT | 99000 | 95 | **ropa y moda** |
| 7 | Tenis Nike Air Max 270 | 449000 | 35 | **Calzado deportivo** |
| 8 | Tenis Adidas Ultraboost 22 | 599000 | 22 | Calzado |
| 9 | Licuadora Oster Pro | 229000 | 60 | Hogar |
| 10 | Bicicleta MTB Trek Marlin | 1899000 | 4 | **Deportes y recreacion** |

> Samsung Galaxy A54 con **stock = -3**: se vendieron 3 unidades que no existían en bodega, resultando en 3 pedidos incumplidos.

---

## Brechas críticas identificadas

| # | Brecha | Evidencia en datos | Impacto económico estimado |
|---|---|---|---|
| B1 | **Stock negativo** — se despachan unidades inexistentes | Samsung A54: stock = -3 | $3.597.000 en pedidos incumplidos/mes |
| B2 | **Precios inválidos** — ventas con precio o cantidad negativos | Fila 6 y 9 de ventas | Pérdida contable no detectada |
| B3 | **Estados inconsistentes** — mismo estado escrito de 4 formas distintas | "enviado"/"Enviado"/"en camino"/"despachado" | Imposible generar reportes de estado confiables |
| B4 | **Sin separación pago/pedido** — no se sabe si un pedido fue cobrado | No existe tabla de pagos | ~8 % de pedidos sin confirmación de pago |
| B5 | **Sin normalización de clientes** — datos duplicados en cada venta | vrios@gmail.com aparece 3 veces con datos diferentes | Duplicados en campañas de email; costo extra de marketing |
| B6 | **Sin analytics** — cero vistas ni queries de negocio | Consultas manuales en Excel | 20 horas/mes de trabajo manual de reconciliación |
| B7 | **Categorías inconsistentes** — texto libre sin tabla de referencia | "electronica" / "Electrónica" / "ropa y moda" | Catálogo del sitio web desorganizado |
| B8 | **Sin arquitectura cloud** — servidor único sin backups automáticos | VPS DigitalOcean sin replicación | Riesgo de pérdida total de datos ante fallo del servidor |

---

## Pérdida mensual cuantificada (pre-optimización)

| Brecha | Pérdida / mes |
|---|---|
| Pedidos incumplidos por stock negativo (B1) | $3.597.000 COP |
| Reconciliación manual en Excel (B6) | $1.200.000 COP (20 h × $60.000/h) |
| Pedidos sin cobro confirmado (B4) | $1.400.000 COP (8 % × $17.5M revenue) |
| Costo extra campañas por duplicados (B5) | $400.000 COP |
| **Total pérdida mensual estimada** | **$6.597.000 COP** |
| **Pérdida anual** | **$79.164.000 COP** |
