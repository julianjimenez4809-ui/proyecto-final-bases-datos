# Informe Financiero — ShopCo E-Commerce
## Costeo, ROI y Proyección de Escenarios

---

## 1. Supuestos de operación

| Variable | Valor base | Fuente |
|---|---|---|
| Usuarios activos / mes | 5.000 | Benchmark e-commerce PYME Colombia (CCCE 2024) |
| Pedidos / mes | 500 | Tasa de conversión 10 % sobre usuarios activos |
| Ticket promedio | $350.000 COP | Basado en datos reales de Supabase ($18.4M / ~52 pedidos) |
| Revenue mensual estimado | $175.000.000 COP | 500 pedidos × $350.000 |
| Almacenamiento datos | 50 GB | PostgreSQL + S3 imágenes + backups |
| Transferencia de datos | 200 GB / mes | API + imágenes vía CloudFront |
| Equipo técnico | 2 developers + 1 DBA | Full-time, nivel mid-senior Colombia |
| Tasa de cambio | $4.200 COP / USD | TRM promedio 2025 |
| IVA Colombia | 19 % | Decreto 624/1989 — servicios tecnológicos |

---

## 2. Costos de infraestructura mensual

### 2.1 Servicios cloud (USD → COP con IVA 19 %)

| Servicio | Descripción | USD / mes | COP (×4.200) | + IVA 19 % | Total COP |
|---|---|---|---|---|---|
| Supabase Pro | PostgreSQL gestionado, 8 GB RAM, backups | $25 | $105.000 | $19.950 | **$124.950** |
| MongoDB Atlas M10 | 2 vCPU, 2 GB RAM, us-east-1 | $57 | $239.400 | $45.486 | **$284.886** |
| AWS Lambda | 2M invocaciones/mes, 512 MB, 500 ms avg | $0,80 | $3.360 | $638 | **$3.998** |
| Amazon API Gateway | 2M requests/mes | $7 | $29.400 | $5.586 | **$34.986** |
| Amazon S3 | 50 GB storage + 200 GB transfer | $18,15 | $76.230 | $14.484 | **$90.714** |
| Amazon CloudFront | 200 GB transfer, 2M requests | $19 | $79.800 | $15.162 | **$94.962** |
| AWS Secrets Manager | 5 secretos + 5.000 llamadas | $2 | $8.400 | $1.596 | **$9.996** |
| Amazon CloudWatch | Logs 10 GB + 10 dashboards | $8 | $33.600 | $6.384 | **$39.984** |
| **Total infraestructura** | | **$136,95** | **$575.190** | **$109.286** | **$684.476** |

### 2.2 Talento humano mensual (COP)

Cálculo basado en normativa laboral colombiana: prestaciones sociales = 51,8 % sobre salario base (cesantías 8,33 % + intereses 1 % + prima 8,33 % + vacaciones 4,17 % + salud empleador 8,5 % + pensión empleador 12 % + ARL 0,522 % + SENA 2 % + ICBF 3 % + CCF 4 %).

| Rol | Salario base | Prestaciones (51,8 %) | Costo total / mes |
|---|---|---|---|
| Developer Full-Stack (x2) | $6.000.000 | $3.108.000 | $9.108.000 × 2 = **$18.216.000** |
| DBA / DevOps | $7.000.000 | $3.626.000 | **$10.626.000** |
| **Total talento** | | | **$28.842.000** |

### 2.3 Costo total mensual

| Componente | Costo mensual COP |
|---|---|
| Infraestructura cloud | $684.476 |
| Talento humano | $28.842.000 |
| **Total operativo** | **$29.526.476** |

---

## 3. Inversión inicial (mes 0)

| Ítem | Costo COP |
|---|---|
| Desarrollo de la plataforma (3 meses × equipo) | $88.542.000 |
| Diseño UX/UI | $5.000.000 |
| Registro de dominio + SSL (anual) | $500.000 |
| Configuración inicial AWS + MongoDB | $2.000.000 |
| Licencias y herramientas de desarrollo | $1.200.000 |
| **Total inversión inicial** | **$97.242.000** |

---

## 4. Proyección de ingresos y ROI

### 4.1 Fórmula de ROI

```
ROI = (Beneficio neto acumulado - Inversión inicial) / Inversión inicial × 100
```

Donde:
```
Beneficio neto mensual = Revenue mensual - Costo operativo mensual
                       = $175.000.000 - $29.526.476
                       = $145.473.524 / mes
```

### 4.2 Escenario Base

| Mes | Revenue | Costo operativo | Beneficio neto | Acumulado | ROI |
|---|---|---|---|---|---|
| 0 (inversión) | $0 | — | -$97.242.000 | -$97.242.000 | — |
| 1 | $175.000.000 | $29.526.476 | $145.473.524 | $48.231.524 | **+49,6 %** |
| 2 | $175.000.000 | $29.526.476 | $145.473.524 | $193.705.048 | +99,2 % |
| 3 | $175.000.000 | $29.526.476 | $145.473.524 | $339.178.572 | +248,9 % |
| 6 | $175.000.000 | $29.526.476 | $145.473.524 | $775.599.144 | +697,6 % |

**Punto de equilibrio: mes 1** (el primer mes de operación recupera la inversión inicial).

### 4.3 Escenario Optimista (+50 % en ventas)

| Supuesto | Valor |
|---|---|
| Pedidos / mes | 750 |
| Revenue mensual | $262.500.000 |
| Infraestructura (escala) | $1.200.000 |
| Beneficio neto mensual | $232.131.524 |
| ROI mes 1 | **+138,6 %** |

### 4.4 Escenario Pesimista (-60 % en ventas)

| Supuesto | Valor |
|---|---|
| Pedidos / mes | 200 |
| Revenue mensual | $70.000.000 |
| Infraestructura (sin escalar) | $684.476 |
| Beneficio neto mensual | $40.473.524 |
| Punto de equilibrio | **Mes 3** |
| ROI mes 3 | **+24,8 %** |

---

## 5. Análisis de costos por unidad

| Métrica | Valor |
|---|---|
| Costo de infraestructura por pedido | $1.369 COP |
| Costo total operativo por pedido | $59.053 COP |
| Margen bruto promedio por pedido | $290.947 COP (83,1 %) |
| Costo de adquisición de cliente (CAC estimado) | $15.000 COP |
| Lifetime Value cliente (LTV, 3 pedidos promedio) | $1.050.000 COP |
| Ratio LTV / CAC | **70x** |

---

## 6. Conclusión ejecutiva

La arquitectura cloud propuesta tiene un **costo de infraestructura de solo $684.476 COP/mes** (~2,3 % del costo operativo total), lo que confirma que el mayor costo es el talento humano. El **ROI se torna positivo en el primer mes de operación** incluso en el escenario base, con una inversión inicial de $97M COP recuperada por el beneficio neto mensual de $145M COP.

La migración a la arquitectura serverless (Lambda + Supabase + MongoDB Atlas) reduce los costos de infraestructura tradicional en aproximadamente **60 %** frente a un servidor dedicado equivalente (EC2 m5.large: ~$180 USD/mes sin gestión de BD).

**Recomendación:** Iniciar con el escenario base (500 pedidos/mes) y activar auto-scaling en Lambda/API Gateway para el escenario optimista sin costo adicional de gestión.
