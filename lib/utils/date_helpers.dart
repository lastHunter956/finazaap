/// Constantes y utilidades de fechas en español.

const List<String> monthNamesShort = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const List<String> monthNamesFull = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Nombre corto del mes (1-12).
String monthShort(int month) =>
    (month >= 1 && month <= 12) ? monthNamesShort[month - 1] : '';

/// Nombre completo del mes (1-12).
String monthFull(int month) =>
    (month >= 1 && month <= 12) ? monthNamesFull[month - 1] : '';
