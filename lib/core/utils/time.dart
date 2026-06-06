// Helpers de tiempo para el protocolo (ISO-8601 UTC con sufijo Z;
// docs/pc-contract.md: el orden lexicográfico = cronológico).

/// Serializa un [DateTime] como ISO-8601 en UTC (con `Z`).
String isoUtc(DateTime dt) => dt.toUtc().toIso8601String();

/// Parsea un timestamp ISO-8601 a [DateTime] UTC; null si vacío/ inválido.
DateTime? parseIsoUtc(String? s) {
  if (s == null || s.isEmpty) {
    return null;
  }
  return DateTime.tryParse(s)?.toUtc();
}
