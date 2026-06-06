/// Número de columnas para rejillas de portadas según el ancho disponible.
/// Mantiene tarjetas de tamaño cómodo en teléfonos (2) y aprovecha tablets.
int gridColumns(double width) {
  if (width >= 1000) {
    return 5;
  }
  if (width >= 720) {
    return 4;
  }
  if (width >= 520) {
    return 3;
  }
  return 2;
}
