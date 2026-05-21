# Informe de Negocio — ShopCo E-Commerce
### Propuesta de Optimización de Base de Datos
**Proyecto Final · Bases de Datos · Noviembre 2025**

---

## 1. Contexto inicial

**ShopCo S.A.S.** es una empresa colombiana de comercio electrónico fundada en Bogotá en enero de 2023. Opera en las categorías de Electrónica, Ropa y Deportes, atendiendo clientes en Bogotá, Medellín, Cali, Barranquilla y Pereira.

**¿Qué hace ShopCo?**
Vende productos de marcas como Samsung, Apple, Lenovo, Nike, Adidas y Polo Ralph Lauren a través de su plataforma web. Gestiona el ciclo completo: catálogo → pedido → pago → envío → reseña.

**¿Qué datos gestiona?**

| Dominio | Datos | Volumen (2026) |
|---|---|---|
| Clientes | Nombre, email, teléfono, direcciones | 8 clientes registrados |
| Productos | Catálogo con precios, costos, stock | 10 SKUs activos, 9 categorías |
| Transacciones | Pedidos, ítems, pagos, envíos | 11 pedidos, $18.5M COP revenue |
| Logística | Transportistas, guías, estados de entrega | 3 transportistas (Servientrega, Envia, Coordinadora) |
| Satisfacción | Reseñas y calificaciones | 5 reseñas, promedio 4.8/5 |

**Sistema original (enero 2023 – abril 2026):**
ShopCo operó durante 3 años con una base de datos construida en el lanzamiento rápido del MVP: **2 tablas, sin constraints, sin normalización, en un servidor VPS único** a $20 USD/mes. Funcionó para los primeros 20 pedidos/mes, pero al escalar a 500 pedidos/mes el sistema comenzó a generar errores críticos en producción.

---

## 2. Problema identificado

El equipo de ShopCo identificó **8 brechas críticas** en su base de datos original, con impacto económico directo y medible.

### 2.1 Diagnóstico técnico del esquema original

El sistema original consistía en dos tablas sin relaciones formales:

- **`ventas`** — mezclaba en una sola fila: datos del cliente, del producto, del pago y del envío (sin normalización)
- **`productos`** — sin distinción entre precio de costo y precio de venta, sin control de stock mínimo, sin categorías normalizadas

**Problemas encontrados en datos reales de producción:**

| Evidencia | Dato real | Consecuencia |
|---|---|---|
| Stock negativo | Samsung Galaxy A54: stock = **-3 unidades** | 3 pedidos despachados sin producto en bodega |
| Precio negativo | Venta registrada con precio = **-$449.000** | Error contable no detectado por semanas |
| Cantidad inválida | Pedido con cantidad = **0** y otro con cantidad = **-2** | Revenue inflado artificialmente |
| Estados inconsistentes | "enviado" / "Enviado" / "en camino" / "despachado" para el mismo estado | Imposible generar reportes automáticos |
| Clientes duplicados | vrios@gmail.com aparece **3 veces** con datos distintos | Campañas de email con duplicados; CRM corrupto |
| Categorías inconsistentes | "electronica" / "Electrónica" / "Deportes y recreacion" | Catálogo web desorganizado |

### 2.2 Brechas por área

```
INTEGRIDAD DE DATOS
├── Sin constraints de valor    → precios/cantidades negativas sin detección
├── Sin foreign keys            → datos huérfanos imposibles de rastrear
└── Sin unicidad de cliente     → duplicados en base de clientes

MODELO DE DATOS
├── Todo desnormalizado en 2 tablas → redundancia masiva de datos
├── Sin separación pago/pedido  → imposible saber si un pedido fue cobrado
└── Sin tabla de inventario     → sin alertas de stock mínimo

ANALYTICS
├── 0 vistas de negocio         → reportes 100 % manuales en Excel
├── 0 funciones reutilizables   → lógica de negocio en código de aplicación
└── 0 agregaciones automáticas  → 20 horas/mes de trabajo manual

ARQUITECTURA
├── Servidor único sin backups  → riesgo de pérdida total ante fallo
├── Sin separación de ambientes → producción y pruebas en el mismo servidor
└── Sin datos no estructurados  → catálogo sin imágenes ni specs técnicas
```

### 2.3 Impacto económico cuantificado

| Brecha | Pérdida mensual estimada |
|---|---|
| Pedidos incumplidos por stock negativo | $3.597.000 COP |
| Pedidos sin confirmación de pago (8 %) | $1.400.000 COP |
| Reconciliación manual en Excel (20 h/mes) | $1.200.000 COP |
| Campañas de email con duplicados de clientes | $400.000 COP |
| **Total pérdida mensual** | **$6.597.000 COP** |
| **Total pérdida anual (3 años sin optimizar)** | **$237.492.000 COP** |

---

## 3. Mejora propuesta e implementada

El equipo rediseñó completamente el sistema de bases de datos de ShopCo sobre tres ejes:

| Eje | Qué se hizo | Resultado verificado |
|---|---|---|
| **SQL normalizado** | 10 tablas en 3FN + 24 constraints + 3 vistas + 1 SP + 3 funciones + 8 índices | Ejecuta sin errores en Supabase (PostgreSQL 17) |
| **NoSQL complementario** | MongoDB Atlas: 3 colecciones (catálogo, sesiones, carritos) + 5 aggregation pipelines | Integración via `producto_id` / `cliente_id` con PostgreSQL |
| **Cloud escalable** | AWS serverless: Lambda + API Gateway + S3 + CloudWatch + IAM + Secrets Manager | Costo infra: $684.476 COP/mes vs $84.000 COP del VPS original |

---

## 4. Modelo de datos propuesto

**10 tablas relacionales en 3FN** — ver [modelo_er.md](../3_modelo_er/modelo_er.md)

```
CATEGORIA (9 registros, jerarquía 2 niveles)
└── PRODUCTO (10 SKUs — constraint: precio_venta ≥ precio_costo)
    └── INVENTARIO (1:1 — stock_minimo con alerta automática)
    └── DETALLE_PEDIDO ← precio histórico capturado al momento de la venta

CLIENTE (8 registros — email único, soft delete con activo=FALSE)
└── DIRECCION (normalizada, separada del pedido)
└── PEDIDO (11 pedidos — estados validados por CHECK)
    └── PAGO (1:1 — métodos y estados controlados por ENUM)
    └── ENVIO (1:1 — trazabilidad logística con fechas y guías)
    └── RESENA (vinculada a compra verificada, no editable libremente)
```

**Constraints implementados:** 24 reglas de negocio verificables.  
**Constraint estrella:** `ck_precio_venta_mayor_costo` — elimina el riesgo de registrar ventas a pérdida.  
Ver detalle en [reglas_negocio.md](../4_reglas_negocio/reglas_negocio.md)

---

## 5. Resultados del análisis con el nuevo sistema

*Queries ejecutados sobre datos reales en Supabase — ver [09_analisis_resultados.md](../5_scripts_sql/09_analisis_resultados.md)*

| Hallazgo | Cifra real | Acción recomendada |
|---|---|---|
| Electrónica = 80 % del revenue | $16.453.200 de $20.533.450 | Priorizar stock y campañas |
| 1 cliente = 41 % del revenue | Valentina Ríos → $7.557.000 (Platinum) | Programa de fidelización exclusivo |
| 83 % de clientes con 1 solo pedido | 5 de 6 clientes activos con compra | Campaña de segunda compra |
| Mayor margen: Bicicleta MTB (36,8 %) | Stock crítico: 4 unidades | Reabastecimiento urgente |
| PSE: 100 % aprobación de pagos | $9.798.000 capturado | Promover en checkout |
| NPS implícito 4,8 / 5 estrellas | 4 productos con 5/5 | Usar como social proof |

---

## 6. Evolución de la base de datos

| Versión | Estado | Tablas | Constraints | Objetos DB | Analytics |
|---|---|---|---|---|---|
| **Inicial (AS-IS)** | Problemática | 2 (sin normalizar) | 0 | 0 | 0 vistas, 0 funciones |
| **Propuesta (TO-BE)** | Producción | 10 (3FN) | 24 | Vistas + SP + Funciones | 6 queries con insights |

Ver datos completos en [7_bases_datos/](../7_bases_datos/)

---

## 7. Arquitectura cloud propuesta

**De:** VPS único DigitalOcean ($20 USD/mes, sin backups, sin escala)  
**A:** AWS serverless multi-servicio ($136 USD/mes, alta disponibilidad, escala automática)

| Servicio | Rol | Costo/mes (con IVA 19 %) |
|---|---|---|
| Supabase Pro | BD relacional gestionada | $124.950 COP |
| MongoDB Atlas M10 | BD documental (catálogo/eventos) | $284.886 COP |
| AWS Lambda + API Gateway | Compute serverless | $38.984 COP |
| Amazon S3 + CloudFront | Storage + CDN imágenes | $185.676 COP |
| Secrets Manager + CloudWatch | Seguridad + Observabilidad | $49.980 COP |
| **Total infraestructura** | | **$684.476 COP/mes** |

Ver detalle en [arquitectura_nube.md](../8_arquitectura_nube/arquitectura_nube.md)

---

## 8. Viabilidad financiera

| Escenario | Revenue/mes | Costo operativo | Beneficio neto | Break-even |
|---|---|---|---|---|
| Base (500 pedidos) | $175.000.000 | $29.526.476 | $145.473.524 | **Mes 1** |
| Optimista (750 pedidos) | $262.500.000 | $30.726.476 | $231.773.524 | Mes 1 |
| Pesimista (200 pedidos) | $70.000.000 | $29.526.476 | $40.473.524 | Mes 3 |

**Inversión inicial:** $97.242.000 COP  
**Ahorro por eliminación de pérdidas:** $6.597.000 COP/mes → **$79.164.000 COP/año**  
**ROI mes 1 (escenario base): +49,6 %**

Ver detalle en [informe_financiero.md](../9_informe_financiero/informe_financiero.md)

---

## 9. Marco legal y ético

- **Colombia:** Ley 1581/2012 · Ley 1266/2008 · Ley 527/1999 · Decreto 1377/2013
- **Internacional:** GDPR · PCI DSS v4.0 SAQ-A
- **Estándares:** ISO 27001 · ISO 9001 · ISO/IEC 25010 · OWASP Top 10
- **Datos personales tratados:** nombre, email, teléfono, dirección física, historial de compras, método de pago

Ver detalle en [marco_legal_etico.md](../10_marco_legal_etico/marco_legal_etico.md)

---

## 10. Roadmap de implementación

| Fase | Hito | Estado |
|---|---|---|
| 0 | Diagnóstico AS-IS + diseño TO-BE | ✅ Completado |
| 0 | BD SQL optimizada en producción (Supabase) | ✅ Completado |
| 0 | Módulo NoSQL diseñado (MongoDB Atlas) | ✅ Completado |
| 0 | Análisis de resultados con datos reales | ✅ Completado |
| 1 | Despliegue AWS Lambda + API Gateway | 30 días |
| 2 | Integración pasarelas de pago certificadas | 45 días |
| 3 | Dashboard analítico en tiempo real | 60 días |
| 4 | Campaña fidelización clientes Platinum/Gold | 75 días |
| 5 | Motor de recomendaciones por historial | 6 meses |
