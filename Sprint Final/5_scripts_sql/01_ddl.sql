-- =============================================================
-- ShopCo E-Commerce — DDL (Data Definition Language)
-- Proyecto Final Bases de Datos
-- =============================================================

-- Extensión para UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------------
-- 1. CATEGORIA (tabla jerárquica auto-referenciada)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categoria (
    categoria_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre           VARCHAR(100) NOT NULL UNIQUE,
    descripcion      TEXT,
    categoria_padre_id UUID REFERENCES categoria(categoria_id)
);

-- -------------------------------------------------------------
-- 2. CLIENTE
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cliente (
    cliente_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    telefono        VARCHAR(20),
    fecha_registro  TIMESTAMPTZ NOT NULL DEFAULT now(),
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

-- -------------------------------------------------------------
-- 3. DIRECCION
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS direccion (
    direccion_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id    UUID NOT NULL REFERENCES cliente(cliente_id),
    calle         VARCHAR(200) NOT NULL,
    ciudad        VARCHAR(100) NOT NULL,
    departamento  VARCHAR(100) NOT NULL,
    codigo_postal VARCHAR(20),
    es_principal  BOOLEAN NOT NULL DEFAULT FALSE
);

-- -------------------------------------------------------------
-- 4. PRODUCTO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS producto (
    producto_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku           VARCHAR(50) NOT NULL UNIQUE,
    nombre        VARCHAR(150) NOT NULL,
    descripcion   TEXT,
    precio_costo  NUMERIC(12,2) NOT NULL CHECK (precio_costo >= 0),
    precio_venta  NUMERIC(12,2) NOT NULL CHECK (precio_venta >= 0),
    categoria_id  UUID NOT NULL REFERENCES categoria(categoria_id),
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------
-- 5. INVENTARIO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventario (
    inventario_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    producto_id         UUID NOT NULL UNIQUE REFERENCES producto(producto_id),
    stock               INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo        INTEGER NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    ubicacion           VARCHAR(100),
    ultima_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------
-- 6. PEDIDO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pedido (
    pedido_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id         UUID NOT NULL REFERENCES cliente(cliente_id),
    direccion_id       UUID NOT NULL REFERENCES direccion(direccion_id),
    estado             VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                           CHECK (estado IN ('pendiente','procesando','enviado','entregado','cancelado')),
    fecha_pedido       TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
    notas              TEXT
);

-- -------------------------------------------------------------
-- 7. DETALLE_PEDIDO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_pedido (
    detalle_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id      UUID NOT NULL REFERENCES pedido(pedido_id),
    producto_id    UUID NOT NULL REFERENCES producto(producto_id),
    cantidad       INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    descuento      NUMERIC(5,2) NOT NULL DEFAULT 0
                       CHECK (descuento >= 0 AND descuento <= 100)
);

-- -------------------------------------------------------------
-- 8. PAGO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pago (
    pago_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id           UUID NOT NULL UNIQUE REFERENCES pedido(pedido_id),
    metodo              VARCHAR(20) NOT NULL
                            CHECK (metodo IN ('tarjeta','pse','efectivo','nequi','daviplata')),
    estado              VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                            CHECK (estado IN ('pendiente','aprobado','rechazado','reembolsado')),
    monto               NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    referencia_externa  VARCHAR(100),
    fecha_pago          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------
-- 9. ENVIO
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS envio (
    envio_id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id              UUID NOT NULL UNIQUE REFERENCES pedido(pedido_id),
    transportista          VARCHAR(100) NOT NULL,
    numero_guia            VARCHAR(100),
    estado                 VARCHAR(20) NOT NULL DEFAULT 'preparando'
                               CHECK (estado IN ('preparando','en_transito','entregado','devuelto')),
    fecha_despacho         TIMESTAMPTZ,
    fecha_entrega_estimada DATE,
    fecha_entrega_real     TIMESTAMPTZ
);

-- -------------------------------------------------------------
-- 10. RESENA
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resena (
    resena_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id   UUID NOT NULL REFERENCES cliente(cliente_id),
    producto_id  UUID NOT NULL REFERENCES producto(producto_id),
    pedido_id    UUID NOT NULL REFERENCES pedido(pedido_id),
    calificacion SMALLINT NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
    comentario   TEXT,
    fecha_resena TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------
-- ÍNDICES de soporte para JOINs frecuentes
-- -------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedido_cliente   ON pedido(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedido_estado    ON pedido(estado);
CREATE INDEX IF NOT EXISTS idx_detalle_pedido   ON detalle_pedido(pedido_id);
CREATE INDEX IF NOT EXISTS idx_detalle_producto ON detalle_pedido(producto_id);
CREATE INDEX IF NOT EXISTS idx_pago_estado      ON pago(estado);
CREATE INDEX IF NOT EXISTS idx_envio_estado     ON envio(estado);
CREATE INDEX IF NOT EXISTS idx_resena_producto  ON resena(producto_id);
CREATE INDEX IF NOT EXISTS idx_producto_categoria ON producto(categoria_id);
