# Arquitectura en la Nube — ShopCo E-Commerce

## Proveedor elegido: AWS

**Justificación:** Supabase (PostgreSQL) ya corre sobre AWS `us-east-1`. Usar AWS como proveedor unifica la región, elimina latencia inter-cloud, simplifica IAM y reduce costos de transferencia de datos entre servicios.

---

## Diagrama de arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET / USUARIOS                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     AMAZON CLOUDFRONT (CDN)                         │
│          Cache de imágenes, assets estáticos, distribución global   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AMAZON API GATEWAY (REST)                        │
│           Rate limiting · Auth JWT · Rutas /productos /pedidos      │
└──────┬────────────────────────────────────────────┬────────────────┘
       │ invoca                                     │ invoca
       ▼                                            ▼
┌─────────────────────┐                  ┌─────────────────────────┐
│   AWS LAMBDA        │                  │   AWS LAMBDA            │
│   shopco-api        │                  │   shopco-events         │
│   (Node.js 20)      │                  │   (Python 3.12)         │
│   CRUD principal    │                  │   Sesiones / Carritos   │
└────────┬────────────┘                  └──────────┬──────────────┘
         │                                          │
    ┌────┴──────────────────────────────────────────┴────┐
    │                  CAPA DE DATOS                      │
    │                                                     │
    │  ┌──────────────────────┐  ┌─────────────────────┐ │
    │  │  SUPABASE (Postgres) │  │  MONGODB ATLAS M10  │ │
    │  │  us-east-1           │  │  us-east-1          │ │
    │  │  BD transaccional    │  │  Catálogo / Eventos │ │
    │  │  pedidos · pagos     │  │  Carritos abandon.  │ │
    │  │  clientes · envíos   │  │  Sesiones usuario   │ │
    │  └──────────────────────┘  └─────────────────────┘ │
    │                                                     │
    │  ┌──────────────────────────────────────────────┐  │
    │  │           AMAZON S3                          │  │
    │  │  shopco-productos/   → imágenes de catálogo  │  │
    │  │  shopco-backups/     → exports CSV/BSON      │  │
    │  │  shopco-logs/        → access logs archivados│  │
    │  └──────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
┌─────────────────┐      ┌──────────────────────────────┐
│  AWS SECRETS    │      │  AMAZON CLOUDWATCH           │
│  MANAGER        │      │  · Logs de Lambda            │
│  DB passwords   │      │  · Métricas de API Gateway   │
│  API keys       │      │  · Alertas de errores 5xx    │
│  JWT secrets    │      │  · Dashboard de latencia p99 │
└─────────────────┘      └──────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                  AWS IAM                                 │
│  Role: lambda-shopco-api    → S3 read/write, RDS access │
│  Role: lambda-shopco-events → S3 write, logs            │
│  Role: ci-deploy            → Lambda update only        │
│  Policy: least-privilege por función                    │
└─────────────────────────────────────────────────────────┘
```

---

## Servicios y justificación

| Servicio | Categoría | Función en ShopCo | Por qué este y no otro |
|---|---|---|---|
| **AWS Lambda** | Compute | Lógica de negocio de la API REST y procesamiento de eventos | Serverless = $0 en idle; escala automático con tráfico; sin gestión de servidores |
| **Amazon API Gateway** | Compute | Entrada única HTTPS con rate limiting y auth JWT | Integración nativa con Lambda; WAF opcional; no requiere ALB para este volumen |
| **Supabase (PostgreSQL)** | Base de datos relacional | Fuente de verdad transaccional: clientes, pedidos, pagos | Ya existe y está en us-east-1; PostgREST incluido; backups automáticos |
| **MongoDB Atlas M10** | Base de datos NoSQL | Catálogo enriquecido, sesiones de usuario, carritos | Esquema flexible para atributos variables por categoría; TTL index nativo |
| **Amazon S3** | Almacenamiento | Imágenes de productos, backups, logs archivados | Durabilidad 11-9s; integración con CloudFront; lifecycle policies automáticas |
| **Amazon CloudFront** | CDN | Distribución de imágenes y assets con caché global | Reduce latencia para usuarios en Colombia; origen S3 nativo |
| **AWS Secrets Manager** | Seguridad | Gestión de credenciales de BD, API keys, JWT secrets | Rotación automática; auditoría en CloudTrail; integración con Lambda sin código extra |
| **AWS IAM** | Seguridad | Control de acceso por rol (least-privilege) | Principio de mínimo privilegio por función Lambda; sin credenciales hardcodeadas |
| **Amazon CloudWatch** | Observabilidad | Logs, métricas, alertas | Integración nativa con todos los servicios AWS; dashboards de latencia y errores |

---

## Flujo de una orden de compra

```
1. Cliente → CloudFront → API Gateway → Lambda (shopco-api)
2. Lambda valida JWT en Secrets Manager
3. Lambda llama sp_procesar_pedido en Supabase:
   - Verifica stock en inventario
   - Crea pedido + detalle_pedido + pago (estado: pendiente)
   - Descuenta stock de inventario
4. Lambda publica evento "pedido_creado" → SQS (cola de pagos)
5. Lambda (shopco-events) consume SQS:
   - Llama pasarela de pago (PSE/Nequi/tarjeta)
   - Actualiza pago.estado en Supabase
6. Si pago aprobado → Lambda crea registro en envio
7. Todo el flujo emite logs a CloudWatch
8. Evento de sesión escrito en MongoDB Atlas (sesiones_usuario)
```

---

## Evidencia de despliegue (comandos AWS CLI)

```bash
# 1. Crear bucket S3 para imágenes de productos
aws s3api create-bucket \
  --bucket shopco-productos \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1

# 2. Subir imagen de producto
aws s3 cp imagen_samsung_a54.jpg \
  s3://shopco-productos/productos/ELEC-SM-001/ \
  --content-type image/jpeg

# 3. Crear secreto en Secrets Manager
aws secretsmanager create-secret \
  --name shopco/prod/supabase \
  --description "Credenciales Supabase ShopCo producción" \
  --secret-string '{"url":"<SUPABASE_URL>","anon_key":"<ANON_KEY>","service_role":"<SERVICE_KEY>"}'

# 4. Crear función Lambda (shopco-api)
aws lambda create-function \
  --function-name shopco-api \
  --runtime nodejs20.x \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-shopco-api \
  --handler index.handler \
  --zip-file fileb://shopco-api.zip \
  --environment Variables='{STAGE=prod}' \
  --region us-east-1

# 5. Crear alarma CloudWatch para errores 5xx
aws cloudwatch put-metric-alarm \
  --alarm-name shopco-api-errors \
  --metric-name 5XXError \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --period 60 \
  --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:shopco-alerts

# 6. Verificar logs de Lambda en CloudWatch
aws logs filter-log-events \
  --log-group-name /aws/lambda/shopco-api \
  --start-time $(date -d '1 hour ago' +%s000) \
  --filter-pattern "ERROR"
```

---

## Seguridad implementada

| Capa | Medida | Servicio |
|---|---|---|
| Red | HTTPS obligatorio, TLS 1.2+ | CloudFront + API Gateway |
| Autenticación | JWT verificado en cada request | Lambda + Secrets Manager |
| Autorización | IAM roles por función, least-privilege | AWS IAM |
| Credenciales | Nunca hardcodeadas, rotación automática | Secrets Manager |
| Datos en tránsito | Cifrado TLS end-to-end | Todos los servicios |
| Datos en reposo | AES-256 en S3 y Supabase | S3 SSE + Supabase encryption |
| Observabilidad | Logs de todas las llamadas | CloudWatch + CloudTrail |
