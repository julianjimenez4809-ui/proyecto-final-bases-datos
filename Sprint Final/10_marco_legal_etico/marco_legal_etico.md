# Marco Legal, Ético y de Estándares — ShopCo E-Commerce

---

## 1. Datos personales tratados

ShopCo recopila y procesa los siguientes datos personales, identificados directamente en el esquema de la base de datos:

| Dato | Tabla | Columna | Tipo | Sensibilidad |
|---|---|---|---|---|
| Nombre completo | `cliente` | `nombre`, `apellido` | Identificador personal | Media |
| Correo electrónico | `cliente` | `email` | Identificador único / contacto | Alta |
| Teléfono | `cliente` | `telefono` | Dato de contacto | Media |
| Dirección física | `direccion` | `calle`, `ciudad`, `departamento` | Dato de ubicación | Alta |
| Historial de compras | `pedido`, `detalle_pedido` | múltiples | Comportamiento de consumo | Media |
| Métodos de pago usados | `pago` | `metodo` | Dato financiero | Alta |
| Referencias de transacciones | `pago` | `referencia_externa` | Dato financiero externo | Alta |
| Opiniones y comentarios | `resena` | `comentario` | Expresión personal | Baja |
| Calificación de productos | `resena` | `calificacion` | Comportamiento de consumo | Baja |

---

## 2. Marco normativo nacional (Colombia)

### Ley 1581 de 2012 — Protección de Datos Personales
Ley general de habeas data en Colombia. ShopCo debe cumplir:

- **Principio de legalidad:** El tratamiento de datos requiere base legal válida (contrato, consentimiento explícito o interés legítimo).
- **Principio de finalidad:** Los datos se recopilan exclusivamente para procesar pedidos, envíos, pagos y mejorar la experiencia del cliente. No se usan para fines distintos sin nuevo consentimiento.
- **Principio de libertad:** El cliente puede solicitar acceso, corrección, actualización o supresión de sus datos en cualquier momento.
- **Principio de veracidad:** Los datos deben ser exactos y actualizados — ShopCo permite al cliente actualizar su perfil y direcciones.
- **Principio de seguridad:** Implementado mediante TLS en tránsito y AES-256 en reposo (Supabase + S3).
- **Principio de confidencialidad:** Solo el personal autorizado accede a datos personales; roles IAM con mínimo privilegio.
- **Principio de minimización:** Solo se recopilan los campos necesarios — el teléfono es `nullable` (no obligatorio).

**Obligaciones aplicables:**
- Registro de la base de datos ante la Superintendencia de Industria y Comercio (SIC).
- Aviso de privacidad visible en el sitio web antes del registro.
- Política de tratamiento de datos publicada.
- Atención de peticiones de habeas data en máximo 15 días hábiles.

### Ley 1266 de 2008 — Habeas Data Financiero
Aplica a los datos de pago (`pago.metodo`, `pago.referencia_externa`). ShopCo no almacena números de tarjeta completos — delega el tratamiento a las pasarelas certificadas (PSE, Nequi, Daviplata). Solo se conserva la referencia externa de la transacción.

### Ley 527 de 1999 — Comercio Electrónico
Valida la firma electrónica y los contratos por medios electrónicos. Los pedidos generados en ShopCo constituyen contratos válidos según esta ley.

### Decreto 1377 de 2013
Reglamenta la Ley 1581. Establece el procedimiento para recopilación de autorizaciones y el contenido mínimo de las políticas de privacidad.

---

## 3. Marco normativo internacional

### GDPR — Reglamento General de Protección de Datos (UE)
Aplica si ShopCo atiende clientes con residencia en la Unión Europea.

| Artículo | Aplicación en ShopCo |
|---|---|
| Art. 6 — Base legal | Contrato (pedido) como base legal principal |
| Art. 17 — Derecho al olvido | Mecanismo de eliminación de cuenta + anonimización de historial |
| Art. 25 — Privacy by design | Esquema diseñado con minimización de datos desde el inicio |
| Art. 32 — Seguridad | TLS + AES-256 + acceso por roles |
| Art. 33 — Notificación de brechas | Protocolo de respuesta a incidentes < 72 horas |

### PCI DSS v4.0 — Payment Card Industry Data Security Standard
Aplica por el procesamiento de pagos con tarjeta. ShopCo adopta el modelo SAQ A (sin almacenamiento de datos de tarjeta):
- Los números de tarjeta nunca tocan los servidores de ShopCo.
- El procesamiento ocurre íntegramente en la pasarela certificada.
- Solo se almacena `referencia_externa` (token de transacción).

---

## 4. Estándares de calidad aplicados

| Estándar | Alcance en ShopCo |
|---|---|
| **ISO 27001:2022** | Sistema de gestión de seguridad de la información: controles de acceso IAM, gestión de secretos (Secrets Manager), auditoría de logs (CloudWatch + CloudTrail) |
| **ISO 9001:2015** | Calidad del servicio: SLA de entrega documentado, proceso de gestión de reseñas, trazabilidad completa del pedido en la BD |
| **OWASP Top 10** | Mitigación de vulnerabilidades web: SQL injection (queries parametrizadas en Supabase), XSS (sanitización en capa de aplicación), autenticación JWT con expiración |
| **ISO/IEC 25010** | Calidad del software: el modelo ER fue diseñado para mantenibilidad, portabilidad y eficiencia (índices, normalización 3FN) |

---

## 5. Consideraciones éticas

### 5.1 Sesgos algorítmicos
ShopCo puede implementar en el futuro sistemas de recomendación de productos basados en historial de compras (`detalle_pedido`) y sesiones (`sesiones_usuario` en MongoDB). Riesgos identificados:

- **Sesgo de popularidad:** Los algoritmos tenderán a recomendar siempre los mismos productos más vendidos, reduciendo la visibilidad del catálogo largo.
- **Sesgo demográfico:** Si el historial está sesgado hacia ciertos segmentos de clientes (ej. Valentina Ríos concentra 41 % del revenue), las recomendaciones reflejarán preferencias no representativas.

**Mitigación:** Auditar periódicamente la distribución de recomendaciones por categoría y segmento de cliente; introducir diversidad intencional en los resultados.

### 5.2 Transparencia
- Los clientes deben saber qué datos se recopilan y para qué se usan.
- Los descuentos y precios mostrados deben coincidir con los almacenados en la BD (`detalle_pedido.precio_unitario`, `detalle_pedido.descuento`).
- El constraint `ck_precio_venta_mayor_costo` garantiza que ShopCo no cobra por debajo del costo, eliminando el riesgo de precios "trampa".

### 5.3 Trazabilidad
El modelo de datos garantiza trazabilidad completa de cada transacción:
- Quién compró (`cliente_id`) → qué compró (`detalle_pedido`) → cuánto pagó (`pago`) → cómo llegó (`envio`) → qué opinó (`resena`).
- Los logs de CloudWatch y CloudTrail registran toda acción sobre la infraestructura.

### 5.4 Retención de datos
| Tipo de dato | Retención recomendada | Justificación |
|---|---|---|
| Datos transaccionales (pedidos, pagos) | 5 años | Obligación tributaria (DIAN) |
| Datos personales de clientes inactivos | 2 años desde última actividad | Ley 1581 — principio de retención |
| Logs de sesiones (MongoDB TTL) | 90 días | Balance entre análisis y privacidad |
| Carritos abandonados recuperados (MongoDB TTL) | 30 días | Dato operativo sin valor a largo plazo |
| Logs de infraestructura (CloudWatch) | 1 año | Requisito de auditoría ISO 27001 |

### 5.5 Explicabilidad
Todas las decisiones de negocio derivadas del análisis de datos (segmentación de clientes, alertas de inventario, selección de transportista) están documentadas en [09_analisis_resultados.md](../5_scripts_sql/09_analisis_resultados.md) con el query exacto y la interpretación. Ninguna decisión queda como "caja negra".

---

## 6. Resumen de cumplimiento

| Marco | Estado | Acción requerida |
|---|---|---|
| Ley 1581/2012 | Diseño cumplido | Registrar BD ante SIC, publicar política de privacidad |
| Ley 1266/2008 | Cumplido | Pasarela maneja datos de tarjeta (SAQ A) |
| Ley 527/1999 | Cumplido | Contratos electrónicos válidos |
| GDPR | Cumplido en diseño | Activar si se expande a UE |
| PCI DSS v4.0 | Cumplido (SAQ A) | Renovar certificación anual con pasarela |
| ISO 27001 | En implementación | Formalizar SGSI, auditoría interna |
| ISO 9001 | En implementación | Documentar procesos de calidad operativa |
| OWASP Top 10 | Mitigado en BD | Auditoría de capa de aplicación pendiente |
