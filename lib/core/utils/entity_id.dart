/// Parse entity ids from API JSON (Node cuid strings or legacy Odoo ints).
class EntityId {
  static String? parse(dynamic value) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Object? asParam(dynamic value) => parse(value);
}
