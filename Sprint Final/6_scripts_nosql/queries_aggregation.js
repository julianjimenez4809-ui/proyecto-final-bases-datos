// =============================================================
// ShopCo E-Commerce — MongoDB Aggregation Pipelines
// Ejecutar en mongosh: load("queries_aggregation.js")
// Base de datos: use shopco
// =============================================================

// =============================================================
// AGG-1. Top 5 productos más vistos por categoría
// Colección: sesiones_usuario
// Insight: Qué productos generan más interés orgánico por categoría
// =============================================================
print("\n=== AGG-1: Top productos más vistos por categoría ===");

db.sesiones_usuario.aggregate([
  // Descomponer el array de eventos en documentos individuales
  { $unwind: "$eventos" },

  // Filtrar solo eventos de vista de producto
  { $match: { "eventos.tipo": "vista_producto" } },

  // Agrupar por producto y sumar vistas + tiempo promedio en página
  {
    $group: {
      _id: {
        producto_id:   "$eventos.producto_id",
        nombre:        "$eventos.nombre_producto"
      },
      total_vistas:        { $sum: 1 },
      tiempo_promedio_seg: { $avg: "$eventos.tiempo_en_pagina_seg" },
      scroll_promedio_pct: { $avg: "$eventos.scroll_pct" }
    }
  },

  // Enriquecer con datos del catálogo (lookup)
  {
    $lookup: {
      from:         "catalogo_productos",
      localField:   "_id.producto_id",
      foreignField: "_id",
      as:           "catalogo"
    }
  },
  { $unwind: { path: "$catalogo", preserveNullAndEmptyArrays: true } },

  // Proyectar campos finales
  {
    $project: {
      _id:               0,
      producto:          "$_id.nombre",
      categoria:         "$catalogo.categoria",
      precio_venta:      "$catalogo.precio_venta",
      total_vistas:      1,
      tiempo_promedio_seg: { $round: ["$tiempo_promedio_seg", 0] },
      scroll_promedio_pct: { $round: ["$scroll_promedio_pct", 0] },
      engagement_score: {
        $round: [{
          $multiply: [
            { $divide: ["$tiempo_promedio_seg", 60] },
            { $divide: ["$scroll_promedio_pct", 100] }
          ]
        }, 2]
      }
    }
  },

  // Ranking por categoría
  {
    $setWindowFields: {
      partitionBy: "$categoria",
      sortBy:      { total_vistas: -1 },
      output: {
        ranking_en_categoria: {
          $rank: {}
        }
      }
    }
  },

  { $match: { ranking_en_categoria: { $lte: 5 } } },
  { $sort: { categoria: 1, total_vistas: -1 } }
]);

// Interpretación de negocio:
// - Productos con alto engagement_score y bajo conversion (no están en pedidos) → candidatos a descuento
// - Productos con alto tiempo_promedio_seg → información insuficiente (mejorar ficha técnica)


// =============================================================
// AGG-2. Carritos abandonados: monto perdido y tasa de recuperación
// Colección: carritos_abandonados
// Insight: Cuánto revenue se pierde por abandono y qué tan efectivo
//          es el remarketing por email
// =============================================================
print("\n=== AGG-2: Análisis de carritos abandonados ===");

db.carritos_abandonados.aggregate([
  {
    $group: {
      _id: "$estado",
      total_carritos:      { $sum: 1 },
      monto_total:         { $sum: "$monto_total" },
      monto_promedio:      { $avg: "$monto_total" },
      emails_enviados:     { $sum: { $cond: ["$remarketing.email_enviado", 1, 0] } },
      clicks_email:        { $sum: { $cond: ["$remarketing.click_email",   1, 0] } },
      descuento_promedio:  { $avg: "$remarketing.descuento_ofrecido_pct" }
    }
  },
  {
    $project: {
      _id:             0,
      estado:          "$_id",
      total_carritos:  1,
      monto_total:     1,
      monto_promedio:  { $round: ["$monto_promedio", 0] },
      emails_enviados: 1,
      tasa_click_pct: {
        $cond: [
          { $gt: ["$emails_enviados", 0] },
          { $round: [{ $multiply: [{ $divide: ["$clicks_email", "$emails_enviados"] }, 100] }, 1] },
          0
        ]
      },
      descuento_promedio_pct: { $round: ["$descuento_promedio", 1] }
    }
  },
  { $sort: { monto_total: -1 } }
]);

// Interpretación de negocio:
// - Si tasa_click_pct es < 20% → revisar asunto del email de remarketing
// - Si monto_total "activo" >> "recuperado" → ajustar descuento ofrecido o timing del email


// =============================================================
// AGG-3. Funnel de conversión: vista → carrito → compra
// Colección: sesiones_usuario
// Insight: En qué paso se pierde más tráfico
// =============================================================
print("\n=== AGG-3: Funnel de conversión ===");

db.sesiones_usuario.aggregate([
  { $unwind: "$eventos" },
  {
    $group: {
      _id: null,
      sesiones_totales:       { $addToSet: "$sesion_id" },
      vistas_producto:        { $sum: { $cond: [{ $eq: ["$eventos.tipo", "vista_producto"]  }, 1, 0] } },
      agregar_carrito:        { $sum: { $cond: [{ $eq: ["$eventos.tipo", "agregar_carrito"] }, 1, 0] } },
      checkout_iniciado:      { $sum: { $cond: [{ $eq: ["$eventos.tipo", "checkout_iniciado"] }, 1, 0] } }
    }
  },
  {
    $project: {
      _id:                  0,
      sesiones_totales:     { $size: "$sesiones_totales" },
      vistas_producto:      1,
      agregar_carrito:      1,
      checkout_iniciado:    1,
      tasa_vista_a_carrito_pct: {
        $cond: [
          { $gt: ["$vistas_producto", 0] },
          { $round: [{ $multiply: [{ $divide: ["$agregar_carrito", "$vistas_producto"] }, 100] }, 1] },
          0
        ]
      },
      tasa_carrito_a_checkout_pct: {
        $cond: [
          { $gt: ["$agregar_carrito", 0] },
          { $round: [{ $multiply: [{ $divide: ["$checkout_iniciado", "$agregar_carrito"] }, 100] }, 1] },
          0
        ]
      }
    }
  }
]);

// Interpretación de negocio:
// - tasa_vista_a_carrito_pct < 5% → problema con fotos, precio, o descripción del producto
// - tasa_carrito_a_checkout_pct < 40% → fricción en el proceso de pago (formulario largo, métodos limitados)


// =============================================================
// AGG-4. Distribución de clientes por nivel de actividad ($bucket)
// Colección: sesiones_usuario
// Insight: Segmentación de clientes por engagement
// =============================================================
print("\n=== AGG-4: Segmentación de clientes por actividad ===");

db.sesiones_usuario.aggregate([
  {
    $group: {
      _id:            "$cliente_id",
      total_sesiones: { $sum: 1 },
      total_eventos:  { $sum: { $size: "$eventos" } },
      conversiones:   { $sum: { $cond: ["$conversion", 1, 0] } },
      ultima_sesion:  { $max: "$fecha" }
    }
  },
  {
    $bucket: {
      groupBy: "$total_sesiones",
      boundaries: [1, 3, 6, 10, 20],
      default: "20+",
      output: {
        num_clientes:          { $sum: 1 },
        sesiones_promedio:     { $avg: "$total_sesiones" },
        tasa_conversion_avg:   {
          $avg: {
            $cond: [
              { $gt: ["$total_sesiones", 0] },
              { $divide: ["$conversiones", "$total_sesiones"] },
              0
            ]
          }
        }
      }
    }
  },
  {
    $project: {
      rango_sesiones:       "$_id",
      num_clientes:         1,
      sesiones_promedio:    { $round: ["$sesiones_promedio", 1] },
      tasa_conversion_pct:  { $round: [{ $multiply: ["$tasa_conversion_avg", 100] }, 1] }
    }
  }
]);

// Interpretación de negocio:
// - Clientes en rango 1 (una sola visita) → campaña de reactivación
// - Clientes 10+ sesiones sin conversión → revisar si el precio es la barrera


// =============================================================
// AGG-5. Integración relacional: carritos con stock disponible en PostgreSQL
// (Simulación — en producción se ejecuta desde la capa de aplicación)
// Colección: carritos_abandonados
// Insight: De los carritos activos, ¿cuáles tienen stock disponible para recuperar?
// =============================================================
print("\n=== AGG-5: Carritos activos con datos del catálogo ===");

db.carritos_abandonados.aggregate([
  // Solo carritos activos (no recuperados, no expirados)
  { $match: { estado: "activo" } },

  // Descomponer items
  { $unwind: "$items" },

  // Enriquecer con catálogo de productos (precio vigente, categoría)
  {
    $lookup: {
      from:         "catalogo_productos",
      localField:   "items.producto_id",
      foreignField: "_id",
      as:           "catalogo_item"
    }
  },
  { $unwind: { path: "$catalogo_item", preserveNullAndEmptyArrays: true } },

  // Reagrupar por carrito
  {
    $group: {
      _id:           "$_id",
      cliente_id:    { $first: "$cliente_id" },
      monto_total:   { $first: "$monto_total" },
      fecha_abandono:{ $first: "$fecha_abandono" },
      num_items:     { $sum: 1 },
      categorias:    { $addToSet: "$catalogo_item.categoria" },
      precio_vigente_total: {
        $sum: { $multiply: ["$items.cantidad", "$catalogo_item.precio_venta"] }
      }
    }
  },

  // Calcular diferencia de precio (si el precio subió desde el abandono)
  {
    $project: {
      cliente_id:    1,
      monto_total:   1,
      precio_vigente_total: 1,
      fecha_abandono:1,
      num_items:     1,
      categorias:    1,
      variacion_precio: { $subtract: ["$precio_vigente_total", "$monto_total"] },
      dias_abandonado: {
        $dateDiff: {
          startDate: "$fecha_abandono",
          endDate:   "$$NOW",
          unit:      "day"
        }
      }
    }
  },

  { $sort: { monto_total: -1 } }
]);

// NOTA DE INTEGRACIÓN:
// El campo "stock disponible" se consulta en tiempo real desde PostgreSQL:
//   SELECT producto_id, stock FROM inventario
//   WHERE producto_id = ANY($1::uuid[])   -- array de producto_ids del carrito
// Esto garantiza que el stock mostrado en el email de remarketing sea exacto.
