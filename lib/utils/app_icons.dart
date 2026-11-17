import 'package:flutter/material.dart';

/// Entrada estructurada del catálogo de íconos de Moneo.
class MoneoIconEntry {
  final IconData icon;
  final String label;
  final String category;
  final List<String> keywords;

  const MoneoIconEntry({
    required this.icon,
    required this.label,
    required this.category,
    this.keywords = const [],
  });
}

class AppIcons {
  // Prevent instantiation
  AppIcons._();

  /// Categorías temáticas oficiales del selector de íconos.
  static const List<String> categories = [
    'Finanzas',
    'Comida',
    'Transporte',
    'Hogar',
    'Compras',
    'Salud',
    'Ocio',
    'Trabajo y Otros',
  ];

  /// Catálogo curado y estructurado en 8 categorías temáticas en español.
  ///
  /// Conserva los íconos históricos específicos (sin llenar el selector
  /// principal con flechas genéricas) y añade íconos Material reconocibles.
  static const List<MoneoIconEntry> catalog = [
    // ───────── Finanzas (16) ─────────
    MoneoIconEntry(
      icon: Icons.account_balance_wallet,
      label: 'Billetera',
      category: 'Finanzas',
      keywords: ['cartera', 'efectivo', 'cuenta', 'dinero'],
    ),
    MoneoIconEntry(
      icon: Icons.account_balance,
      label: 'Banco',
      category: 'Finanzas',
      keywords: ['entidad', 'cuenta bancaria', 'ahorros', 'corriente'],
    ),
    MoneoIconEntry(
      icon: Icons.credit_card,
      label: 'Tarjeta de crédito',
      category: 'Finanzas',
      keywords: ['debito', 'visa', 'mastercard', 'plastico', 'cuota'],
    ),
    MoneoIconEntry(
      icon: Icons.savings,
      label: 'Ahorro y alcancía',
      category: 'Finanzas',
      keywords: ['ahorros', 'meta', 'reserva', 'bolsillo'],
    ),
    MoneoIconEntry(
      icon: Icons.attach_money,
      label: 'Dinero en efectivo',
      category: 'Finanzas',
      keywords: ['moneda', 'pesos', 'dolares', 'billete', 'cash'],
    ),
    MoneoIconEntry(
      icon: Icons.trending_up,
      label: 'Inversiones',
      category: 'Finanzas',
      keywords: ['rendimiento', 'bolsa', 'acciones', 'cdt', 'crecimiento'],
    ),
    MoneoIconEntry(
      icon: Icons.receipt,
      label: 'Recibo',
      category: 'Finanzas',
      keywords: ['comprobante', 'soporte', 'ticket', 'pago'],
    ),
    MoneoIconEntry(
      icon: Icons.receipt_long,
      label: 'Factura',
      category: 'Finanzas',
      keywords: ['obligacion', 'cobro', 'cuenta por pagar', 'impuesto'],
    ),
    MoneoIconEntry(
      icon: Icons.currency_exchange,
      label: 'Cambio de divisa',
      category: 'Finanzas',
      keywords: ['divisa', 'dolar', 'euro', 'conversion', 'remesa'],
    ),
    MoneoIconEntry(
      icon: Icons.payments,
      label: 'Pagos y billetes',
      category: 'Finanzas',
      keywords: ['nomina', 'salario', 'sueldo', 'transferencia'],
    ),
    MoneoIconEntry(
      icon: Icons.request_quote,
      label: 'Presupuesto',
      category: 'Finanzas',
      keywords: ['cotizacion', 'credito', 'estado de cuenta', 'calculo'],
    ),
    MoneoIconEntry(
      icon: Icons.qr_code_2,
      label: 'Pago QR',
      category: 'Finanzas',
      keywords: ['bre-b', 'nequi', 'daviplata', 'codigo', 'transferir'],
    ),
    MoneoIconEntry(
      icon: Icons.pie_chart,
      label: 'Distribución',
      category: 'Finanzas',
      keywords: ['estadistica', 'porcentaje', 'portafolio', 'reporte'],
    ),
    MoneoIconEntry(
      icon: Icons.paid,
      label: 'Moneda',
      category: 'Finanzas',
      keywords: ['ingreso', 'pago', 'efectivo', 'valor'],
    ),
    MoneoIconEntry(
      icon: Icons.real_estate_agent,
      label: 'Préstamo e hipoteca',
      category: 'Finanzas',
      keywords: ['credito', 'deuda', 'cuota', 'financiacion'],
    ),
    MoneoIconEntry(
      icon: Icons.percent,
      label: 'Intereses e impuestos',
      category: 'Finanzas',
      keywords: ['tasa', 'iva', 'retencion', 'descuento', 'comision'],
    ),

    // ───────── Comida (14) ─────────
    MoneoIconEntry(
      icon: Icons.restaurant,
      label: 'Restaurante',
      category: 'Comida',
      keywords: ['almuerzo', 'cena', 'comer', 'salida'],
    ),
    MoneoIconEntry(
      icon: Icons.fastfood,
      label: 'Comida rápida',
      category: 'Comida',
      keywords: ['hamburguesa', 'antojo', 'snack', 'calle'],
    ),
    MoneoIconEntry(
      icon: Icons.local_cafe,
      label: 'Café',
      category: 'Comida',
      keywords: ['cafeteria', 'desayuno', 'tinto', 'merienda'],
    ),
    MoneoIconEntry(
      icon: Icons.local_bar,
      label: 'Bar y bebidas',
      category: 'Comida',
      keywords: ['coctel', 'cerveza', 'trago', 'noche'],
    ),
    MoneoIconEntry(
      icon: Icons.local_pizza,
      label: 'Pizza',
      category: 'Comida',
      keywords: ['italiana', 'cena', 'domicilio', 'compartir'],
    ),
    MoneoIconEntry(
      icon: Icons.bakery_dining,
      label: 'Panadería',
      category: 'Comida',
      keywords: ['pan', 'pasteleria', 'desayuno', 'reposteria'],
    ),
    MoneoIconEntry(
      icon: Icons.delivery_dining,
      label: 'Domicilio',
      category: 'Comida',
      keywords: ['delivery', 'rappi', 'pedido', 'envio'],
    ),
    MoneoIconEntry(
      icon: Icons.shopping_basket,
      label: 'Supermercado',
      category: 'Comida',
      keywords: ['mercado', 'viveres', 'frutas', 'verduras', 'despensa'],
    ),
    MoneoIconEntry(
      icon: Icons.lunch_dining,
      label: 'Almuerzo',
      category: 'Comida',
      keywords: ['menu', 'corrientazo', 'comida', 'oficina'],
    ),
    MoneoIconEntry(
      icon: Icons.dinner_dining,
      label: 'Cena',
      category: 'Comida',
      keywords: ['pasta', 'plato', 'noche', 'comida'],
    ),
    MoneoIconEntry(
      icon: Icons.icecream,
      label: 'Postres y helado',
      category: 'Comida',
      keywords: ['dulce', 'heladeria', 'torta', 'antojo'],
    ),
    MoneoIconEntry(
      icon: Icons.ramen_dining,
      label: 'Sopas y comida asiática',
      category: 'Comida',
      keywords: ['ramen', 'sushi', 'fideos', 'oriental'],
    ),
    MoneoIconEntry(
      icon: Icons.liquor,
      label: 'Licores',
      category: 'Comida',
      keywords: ['vino', 'botella', 'celebracion', 'bebida'],
    ),
    MoneoIconEntry(
      icon: Icons.takeout_dining,
      label: 'Para llevar',
      category: 'Comida',
      keywords: ['caja', 'comida', 'pedido', 'empaque'],
    ),

    // ───────── Transporte (14) ─────────
    MoneoIconEntry(
      icon: Icons.directions_car,
      label: 'Carro',
      category: 'Transporte',
      keywords: ['auto', 'vehiculo', 'coche', 'movilidad'],
    ),
    MoneoIconEntry(
      icon: Icons.directions_bus,
      label: 'Bus',
      category: 'Transporte',
      keywords: ['transporte publico', 'transmilenio', 'pasaje', 'ruta'],
    ),
    MoneoIconEntry(
      icon: Icons.flight,
      label: 'Vuelo',
      category: 'Transporte',
      keywords: ['avion', 'aerolinea', 'tiquete', 'viaje'],
    ),
    MoneoIconEntry(
      icon: Icons.directions_subway,
      label: 'Metro y tren',
      category: 'Transporte',
      keywords: ['ferrocarril', 'estacion', 'tarjeta civica', 'pasaje'],
    ),
    MoneoIconEntry(
      icon: Icons.two_wheeler,
      label: 'Moto',
      category: 'Transporte',
      keywords: ['motocicleta', 'scooter', 'soat', 'transporte'],
    ),
    MoneoIconEntry(
      icon: Icons.pedal_bike,
      label: 'Bicicleta',
      category: 'Transporte',
      keywords: ['bici', 'ciclismo', 'ruta', 'movilidad'],
    ),
    MoneoIconEntry(
      icon: Icons.local_gas_station,
      label: 'Gasolina',
      category: 'Transporte',
      keywords: ['combustible', 'tanqueo', 'acpm', 'estacion'],
    ),
    MoneoIconEntry(
      icon: Icons.ev_station,
      label: 'Carga eléctrica',
      category: 'Transporte',
      keywords: ['vehiculo electrico', 'bateria', 'electrolinera'],
    ),
    MoneoIconEntry(
      icon: Icons.local_taxi,
      label: 'Taxi y app',
      category: 'Transporte',
      keywords: ['uber', 'didi', 'cabify', 'indriver', 'carrera'],
    ),
    MoneoIconEntry(
      icon: Icons.local_parking,
      label: 'Parqueadero',
      category: 'Transporte',
      keywords: ['estacionamiento', 'garaje', 'parking', 'valet'],
    ),
    MoneoIconEntry(
      icon: Icons.directions_boat,
      label: 'Barco y ferry',
      category: 'Transporte',
      keywords: ['lancha', 'mar', 'crucero', 'puerto'],
    ),
    MoneoIconEntry(
      icon: Icons.car_repair,
      label: 'Taller mecánico',
      category: 'Transporte',
      keywords: ['mantenimiento', 'aceite', 'llantas', 'lavadero'],
    ),
    MoneoIconEntry(
      icon: Icons.toll,
      label: 'Peaje',
      category: 'Transporte',
      keywords: ['carretera', 'autopista', 'flypass', 'viaje'],
    ),
    MoneoIconEntry(
      icon: Icons.electric_scooter,
      label: 'Patineta eléctrica',
      category: 'Transporte',
      keywords: ['monopatin', 'movilidad', 'urbano'],
    ),

    // ───────── Hogar (14) ─────────
    MoneoIconEntry(
      icon: Icons.home,
      label: 'Casa y arriendo',
      category: 'Hogar',
      keywords: ['vivienda', 'alquiler', 'hogar', 'renta'],
    ),
    MoneoIconEntry(
      icon: Icons.build,
      label: 'Herramientas y arreglos',
      category: 'Hogar',
      keywords: ['ferreteria', 'reparacion', 'mantenimiento', 'obra'],
    ),
    MoneoIconEntry(
      icon: Icons.lightbulb,
      label: 'Electricidad',
      category: 'Hogar',
      keywords: ['luz', 'energia', 'servicio publico', 'factura'],
    ),
    MoneoIconEntry(
      icon: Icons.wifi,
      label: 'Internet y WiFi',
      category: 'Hogar',
      keywords: ['fibra', 'conexion', 'red', 'banda ancha'],
    ),
    MoneoIconEntry(
      icon: Icons.water_drop,
      label: 'Agua',
      category: 'Hogar',
      keywords: ['acueducto', 'servicio publico', 'alcantarillado'],
    ),
    MoneoIconEntry(
      icon: Icons.local_fire_department,
      label: 'Gas domiciliario',
      category: 'Hogar',
      keywords: ['calefaccion', 'cocina', 'pipeta', 'servicio'],
    ),
    MoneoIconEntry(
      icon: Icons.chair,
      label: 'Muebles',
      category: 'Hogar',
      keywords: ['sala', 'decoracion', 'silla', 'sofa'],
    ),
    MoneoIconEntry(
      icon: Icons.bed,
      label: 'Dormitorio',
      category: 'Hogar',
      keywords: ['colchon', 'cama', 'sabanas', 'cuarto'],
    ),
    MoneoIconEntry(
      icon: Icons.cleaning_services,
      label: 'Limpieza',
      category: 'Hogar',
      keywords: ['aseo', 'detergente', 'servicio domestico'],
    ),
    MoneoIconEntry(
      icon: Icons.local_laundry_service,
      label: 'Lavandería',
      category: 'Hogar',
      keywords: ['lavadora', 'ropa', 'tintoreria', 'planchado'],
    ),
    MoneoIconEntry(
      icon: Icons.yard,
      label: 'Jardín y plantas',
      category: 'Hogar',
      keywords: ['vivero', 'matera', 'patio', 'flores'],
    ),
    MoneoIconEntry(
      icon: Icons.security,
      label: 'Seguridad del hogar',
      category: 'Hogar',
      keywords: ['alarma', 'camara', 'vigilancia', 'llaves'],
    ),
    MoneoIconEntry(
      icon: Icons.apartment,
      label: 'Apartamento',
      category: 'Hogar',
      keywords: ['administracion', 'edificio', 'conjunto', 'ph'],
    ),
    MoneoIconEntry(
      icon: Icons.kitchen,
      label: 'Electrodomésticos',
      category: 'Hogar',
      keywords: ['nevera', 'cocina', 'utensilios', 'hogar'],
    ),

    // ───────── Compras (14) ─────────
    MoneoIconEntry(
      icon: Icons.shopping_bag,
      label: 'Bolsa de compras',
      category: 'Compras',
      keywords: ['compras', 'moda', 'retail', 'tienda'],
    ),
    MoneoIconEntry(
      icon: Icons.shopping_cart,
      label: 'Carrito de compras',
      category: 'Compras',
      keywords: ['mercado', 'online', 'comercio', 'compra'],
    ),
    MoneoIconEntry(
      icon: Icons.card_giftcard,
      label: 'Regalos',
      category: 'Compras',
      keywords: ['obsequio', 'cumpleanos', 'detalle', 'bono'],
    ),
    MoneoIconEntry(
      icon: Icons.phone_android,
      label: 'Celular y plan móvil',
      category: 'Compras',
      keywords: ['telefono', 'datos', 'recarga', 'smartphone'],
    ),
    MoneoIconEntry(
      icon: Icons.checkroom,
      label: 'Ropa y calzado',
      category: 'Compras',
      keywords: ['vestuario', 'zapatos', 'camisa', 'armario'],
    ),
    MoneoIconEntry(
      icon: Icons.storefront,
      label: 'Tienda',
      category: 'Compras',
      keywords: ['comercio', 'almacen', 'local', 'negocio'],
    ),
    MoneoIconEntry(
      icon: Icons.local_offer,
      label: 'Ofertas y descuentos',
      category: 'Compras',
      keywords: ['promocion', 'cupon', 'rebaja', 'etiqueta'],
    ),
    MoneoIconEntry(
      icon: Icons.watch,
      label: 'Accesorios',
      category: 'Compras',
      keywords: ['reloj', 'smartwatch', 'estilo', 'complemento'],
    ),
    MoneoIconEntry(
      icon: Icons.devices,
      label: 'Tecnología',
      category: 'Compras',
      keywords: ['electronica', 'tablet', 'gadgets', 'equipos'],
    ),
    MoneoIconEntry(
      icon: Icons.headphones,
      label: 'Audio y audífonos',
      category: 'Compras',
      keywords: ['sonido', 'parlante', 'musica', 'accesorio'],
    ),
    MoneoIconEntry(
      icon: Icons.diamond,
      label: 'Joyería y lujos',
      category: 'Compras',
      keywords: ['anillo', 'joya', 'regalo', 'premium'],
    ),
    MoneoIconEntry(
      icon: Icons.local_mall,
      label: 'Centro comercial',
      category: 'Compras',
      keywords: ['mall', 'boutique', 'paseo', 'compras'],
    ),
    MoneoIconEntry(
      icon: Icons.inventory_2,
      label: 'Envíos y paquetes',
      category: 'Compras',
      keywords: ['encomienda', 'amazon', 'mercadolibre', 'correo'],
    ),
    MoneoIconEntry(
      icon: Icons.print,
      label: 'Papelería',
      category: 'Compras',
      keywords: ['impresion', 'utiles', 'oficina', 'cuadernos'],
    ),

    // ───────── Salud (14) ─────────
    MoneoIconEntry(
      icon: Icons.health_and_safety,
      label: 'Seguro médico',
      category: 'Salud',
      keywords: ['eps', 'prepagada', 'poliza', 'proteccion'],
    ),
    MoneoIconEntry(
      icon: Icons.local_hospital,
      label: 'Médico y clínica',
      category: 'Salud',
      keywords: ['hospital', 'urgencias', 'cita', 'doctor'],
    ),
    MoneoIconEntry(
      icon: Icons.fitness_center,
      label: 'Gimnasio',
      category: 'Salud',
      keywords: ['pesas', 'entrenamiento', 'crossfit', 'ejercicio'],
    ),
    MoneoIconEntry(
      icon: Icons.spa,
      label: 'Bienestar y spa',
      category: 'Salud',
      keywords: ['masaje', 'belleza', 'peluqueria', 'cuidado'],
    ),
    MoneoIconEntry(
      icon: Icons.medication,
      label: 'Farmacia',
      category: 'Salud',
      keywords: ['drogueria', 'medicamentos', 'pastillas', 'receta'],
    ),
    MoneoIconEntry(
      icon: Icons.favorite,
      label: 'Salud y cuidado',
      category: 'Salud',
      keywords: ['corazon', 'vida', 'bienestar', 'saludable'],
    ),
    MoneoIconEntry(
      icon: Icons.medical_services,
      label: 'Consulta médica',
      category: 'Salud',
      keywords: ['botiquin', 'odontologia', 'dental', 'examen'],
    ),
    MoneoIconEntry(
      icon: Icons.visibility,
      label: 'Óptica y ojos',
      category: 'Salud',
      keywords: ['gafas', 'lentes', 'optometria', 'vision'],
    ),
    MoneoIconEntry(
      icon: Icons.psychology,
      label: 'Salud mental',
      category: 'Salud',
      keywords: ['psicologia', 'terapia', 'mente', 'consulta'],
    ),
    MoneoIconEntry(
      icon: Icons.self_improvement,
      label: 'Yoga y meditación',
      category: 'Salud',
      keywords: ['pilates', 'calma', 'mindfulness', 'estiramiento'],
    ),
    MoneoIconEntry(
      icon: Icons.directions_run,
      label: 'Cardio y running',
      category: 'Salud',
      keywords: ['correr', 'maraton', 'atletismo', 'deporte'],
    ),
    MoneoIconEntry(
      icon: Icons.vaccines,
      label: 'Laboratorio y vacunas',
      category: 'Salud',
      keywords: ['analisis', 'sangre', 'inyeccion', 'clinica'],
    ),
    MoneoIconEntry(
      icon: Icons.monitor_heart,
      label: 'Chequeo médico',
      category: 'Salud',
      keywords: ['cardiologia', 'signos', 'control', 'salud'],
    ),
    MoneoIconEntry(
      icon: Icons.clean_hands,
      label: 'Higiene personal',
      category: 'Salud',
      keywords: ['jabon', 'aseo', 'cosmeticos', 'cuidado'],
    ),

    // ───────── Ocio (14) ─────────
    MoneoIconEntry(
      icon: Icons.hotel,
      label: 'Hotel y hospedaje',
      category: 'Ocio',
      keywords: ['airbnb', 'alojamiento', 'estadia', 'turismo'],
    ),
    MoneoIconEntry(
      icon: Icons.tv,
      label: 'Streaming y TV',
      category: 'Ocio',
      keywords: ['netflix', 'suscripcion', 'series', 'television'],
    ),
    MoneoIconEntry(
      icon: Icons.videogame_asset,
      label: 'Videojuegos',
      category: 'Ocio',
      keywords: ['gaming', 'consola', 'steam', 'playstation'],
    ),
    MoneoIconEntry(
      icon: Icons.music_note,
      label: 'Música',
      category: 'Ocio',
      keywords: ['spotify', 'concierto', 'audio', 'instrumento'],
    ),
    MoneoIconEntry(
      icon: Icons.book,
      label: 'Libros y lectura',
      category: 'Ocio',
      keywords: ['libreria', 'kindle', 'novela', 'revista'],
    ),
    MoneoIconEntry(
      icon: Icons.movie,
      label: 'Cine',
      category: 'Ocio',
      keywords: ['peliculas', 'boletas', 'teatro', 'entretenimiento'],
    ),
    MoneoIconEntry(
      icon: Icons.camera_alt,
      label: 'Fotografía',
      category: 'Ocio',
      keywords: ['camara', 'foto', 'video', 'lente'],
    ),
    MoneoIconEntry(
      icon: Icons.beach_access,
      label: 'Vacaciones y playa',
      category: 'Ocio',
      keywords: ['descanso', 'paseo', 'turismo', 'verano'],
    ),
    MoneoIconEntry(
      icon: Icons.confirmation_number,
      label: 'Eventos y entradas',
      category: 'Ocio',
      keywords: ['tickets', 'boleta', 'parque', 'espectaculo'],
    ),
    MoneoIconEntry(
      icon: Icons.sports_soccer,
      label: 'Deportes',
      category: 'Ocio',
      keywords: ['futbol', 'cancha', 'partido', 'club'],
    ),
    MoneoIconEntry(
      icon: Icons.palette,
      label: 'Arte y hobbies',
      category: 'Ocio',
      keywords: ['pintura', 'manualidades', 'diseno', 'pasatiempo'],
    ),
    MoneoIconEntry(
      icon: Icons.luggage,
      label: 'Viajes',
      category: 'Ocio',
      keywords: ['maleta', 'equipaje', 'tour', 'escapada'],
    ),
    MoneoIconEntry(
      icon: Icons.celebration,
      label: 'Celebraciones',
      category: 'Ocio',
      keywords: ['fiesta', 'evento', 'aniversario', 'reunion'],
    ),
    MoneoIconEntry(
      icon: Icons.podcasts,
      label: 'Podcasts y suscripciones',
      category: 'Ocio',
      keywords: ['membresia', 'radio', 'digital', 'stream'],
    ),

    // ───────── Trabajo y Otros (14) ─────────
    MoneoIconEntry(
      icon: Icons.work,
      label: 'Trabajo',
      category: 'Trabajo y Otros',
      keywords: ['empleo', 'sueldo', 'oficina', 'empresa'],
    ),
    MoneoIconEntry(
      icon: Icons.computer,
      label: 'Portátil y cómputo',
      category: 'Trabajo y Otros',
      keywords: ['pc', 'laptop', 'escritorio', 'equipo'],
    ),
    MoneoIconEntry(
      icon: Icons.school,
      label: 'Educación',
      category: 'Trabajo y Otros',
      keywords: ['universidad', 'colegio', 'curso', 'matricula'],
    ),
    MoneoIconEntry(
      icon: Icons.pets,
      label: 'Mascotas',
      category: 'Trabajo y Otros',
      keywords: ['perro', 'gato', 'veterinaria', 'concentrado'],
    ),
    MoneoIconEntry(
      icon: Icons.child_friendly,
      label: 'Niños y familia',
      category: 'Trabajo y Otros',
      keywords: ['bebe', 'panales', 'juguete', 'hijos'],
    ),
    MoneoIconEntry(
      icon: Icons.category,
      label: 'General y otros',
      category: 'Trabajo y Otros',
      keywords: ['categoria', 'varios', 'miscelaneo', 'sin definir'],
    ),
    MoneoIconEntry(
      icon: Icons.business_center,
      label: 'Negocios y oficina',
      category: 'Trabajo y Otros',
      keywords: ['freelance', 'cliente', 'proyecto', 'emprendimiento'],
    ),
    MoneoIconEntry(
      icon: Icons.volunteer_activism,
      label: 'Donaciones y ayuda',
      category: 'Trabajo y Otros',
      keywords: ['caridad', 'propina', 'aporte', 'fundacion'],
    ),
    MoneoIconEntry(
      icon: Icons.gavel,
      label: 'Trámites y legal',
      category: 'Trabajo y Otros',
      keywords: ['abogado', 'notaria', 'multa', 'documento'],
    ),
    MoneoIconEntry(
      icon: Icons.cloud,
      label: 'Nube y software',
      category: 'Trabajo y Otros',
      keywords: ['saas', 'licencia', 'hosting', 'almacenamiento'],
    ),
    MoneoIconEntry(
      icon: Icons.handyman,
      label: 'Servicios técnicos',
      category: 'Trabajo y Otros',
      keywords: ['soporte', 'instalacion', 'oficio', 'servicio'],
    ),
    MoneoIconEntry(
      icon: Icons.groups,
      label: 'Familia y equipo',
      category: 'Trabajo y Otros',
      keywords: ['compartido', 'hogar', 'reunion', 'personas'],
    ),
    MoneoIconEntry(
      icon: Icons.campaign,
      label: 'Marketing',
      category: 'Trabajo y Otros',
      keywords: ['publicidad', 'anuncios', 'redes', 'ventas'],
    ),
    MoneoIconEntry(
      icon: Icons.calculate,
      label: 'Contabilidad',
      category: 'Trabajo y Otros',
      keywords: ['calculadora', 'numeros', 'declaracion', 'impuestos'],
    ),
  ];

  /// Lista centralizada de TODOS los íconos permitidos en la app.
  ///
  /// Conserva los 43 codePoints históricos en primer lugar (retrocompatibilidad
  /// 100% con Hive/SharedPreferences y tree-shaking) e incorpora los nuevos
  /// íconos del catálogo sin duplicados de `codePoint`.
  static const List<IconData> allIcons = [
    // ── 43 íconos históricos originales (orden y codePoints intactos) ──
    Icons.fastfood, Icons.restaurant, Icons.local_cafe, Icons.local_bar,
    Icons.shopping_bag, Icons.shopping_cart, Icons.credit_card, Icons.receipt,
    Icons.directions_car, Icons.directions_bus, Icons.flight, Icons.hotel,
    Icons.home, Icons.build, Icons.lightbulb, Icons.wifi,
    Icons.health_and_safety, Icons.local_hospital, Icons.fitness_center, Icons.spa,
    Icons.school, Icons.book, Icons.work, Icons.computer,
    Icons.phone_android, Icons.tv, Icons.videogame_asset, Icons.music_note,
    Icons.pets, Icons.child_friendly, Icons.card_giftcard, Icons.savings,
    Icons.account_balance, Icons.attach_money, Icons.trending_up, Icons.category,
    Icons.swap_horiz_rounded, Icons.north_rounded, Icons.south_rounded,
    Icons.sync_alt, Icons.arrow_downward_rounded, Icons.arrow_upward_rounded,
    Icons.account_balance_wallet,

    // ── Nuevos íconos del catálogo temático (sin duplicar históricos) ──
    // Finanzas
    Icons.receipt_long,
    Icons.currency_exchange,
    Icons.payments,
    Icons.request_quote,
    Icons.qr_code_2,
    Icons.pie_chart,
    Icons.paid,
    Icons.real_estate_agent,
    Icons.percent,
    // Comida
    Icons.local_pizza,
    Icons.bakery_dining,
    Icons.delivery_dining,
    Icons.shopping_basket,
    Icons.lunch_dining,
    Icons.dinner_dining,
    Icons.icecream,
    Icons.ramen_dining,
    Icons.liquor,
    Icons.takeout_dining,
    // Transporte
    Icons.directions_subway,
    Icons.two_wheeler,
    Icons.pedal_bike,
    Icons.local_gas_station,
    Icons.ev_station,
    Icons.local_taxi,
    Icons.local_parking,
    Icons.directions_boat,
    Icons.car_repair,
    Icons.toll,
    Icons.electric_scooter,
    // Hogar
    Icons.water_drop,
    Icons.local_fire_department,
    Icons.chair,
    Icons.bed,
    Icons.cleaning_services,
    Icons.local_laundry_service,
    Icons.yard,
    Icons.security,
    Icons.apartment,
    Icons.kitchen,
    // Compras
    Icons.checkroom,
    Icons.storefront,
    Icons.local_offer,
    Icons.watch,
    Icons.devices,
    Icons.headphones,
    Icons.diamond,
    Icons.local_mall,
    Icons.inventory_2,
    Icons.print,
    // Salud
    Icons.medication,
    Icons.favorite,
    Icons.medical_services,
    Icons.visibility,
    Icons.psychology,
    Icons.self_improvement,
    Icons.directions_run,
    Icons.vaccines,
    Icons.monitor_heart,
    Icons.clean_hands,
    // Ocio
    Icons.movie,
    Icons.camera_alt,
    Icons.beach_access,
    Icons.confirmation_number,
    Icons.sports_soccer,
    Icons.palette,
    Icons.luggage,
    Icons.celebration,
    Icons.podcasts,
    // Trabajo y Otros
    Icons.business_center,
    Icons.volunteer_activism,
    Icons.gavel,
    Icons.cloud,
    Icons.handyman,
    Icons.groups,
    Icons.campaign,
    Icons.calculate,
  ];

  // Map for fast lookup by codePoint
  static final Map<int, IconData> _codePointMap = {
    for (var icon in allIcons) icon.codePoint: icon,
  };

  /// Retrieves an IconData from a codePoint assuming it's in the allowed list.
  /// Returns a default icon (Icons.category) if not found,
  /// ensuring we never return a dynamically created IconData that violates tree shaking.
  static IconData getIcon(int codePoint) {
    return _codePointMap[codePoint] ?? Icons.category;
  }

  /// Busca entradas del catálogo por texto libre (nombre, categoría o palabras
  /// clave, sin distinción de mayúsculas ni acentos) y opcionalmente por categoría.
  static List<MoneoIconEntry> search(String query, {String? category}) {
    final normalizedCategory = _normalizeCategory(category);
    final normalizedQuery = _normalizeText(query);
    final tokens = normalizedQuery.isEmpty
        ? const <String>[]
        : normalizedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    return catalog.where((entry) {
      if (normalizedCategory != null &&
          _normalizeText(entry.category) != normalizedCategory) {
        return false;
      }
      if (tokens.isEmpty) return true;

      final searchable = _normalizeText(
        '${entry.label} ${entry.category} ${entry.keywords.join(' ')}',
      );
      return tokens.every(searchable.contains);
    }).toList(growable: false);
  }

  static String? _normalizeCategory(String? category) {
    if (category == null) return null;
    final trimmed = _normalizeText(category);
    if (trimmed.isEmpty || trimmed == 'todos') return null;
    if (trimmed == 'trabajo') return 'trabajo y otros';
    return trimmed;
  }

  static String _normalizeText(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return '';
    return lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}
