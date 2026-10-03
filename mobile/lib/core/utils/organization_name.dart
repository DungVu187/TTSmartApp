/// Legal-form prefixes every Vietnamese company name starts with. They are the
/// same for everyone, so in a narrow chip they only push the part that tells
/// companies apart ("Xây dựng Hòa Bình") behind the "…".
final _legalForm = RegExp(
  r'^\s*(?:(?:tổng\s+)?(?:công\s*ty|c[ôo]ng\s*ty|cty\.?|c\.ty)'
  r'(?:\s+(?:cổ\s+phần|cp|tnhh(?:\s+(?:một\s+thành\s+viên|mtv|hai\s+thành\s+viên(?:\s+trở\s+lên)?))?'
  r'|trách\s+nhiệm\s+hữu\s+hạn(?:\s+(?:một\s+thành\s+viên|mtv))?|hợp\s+danh|liên\s+doanh))?'
  r'|doanh\s+nghiệp\s+tư\s+nhân|dntn)\s+',
  caseSensitive: false,
  unicode: true,
);

/// "Công ty CP Xây dựng Hòa Bình" → "Xây dựng Hòa Bình" for tight places
/// (filter chips). The full name stays everywhere else and in the tooltip.
/// Names without a legal-form prefix ("Trạm Hà Nam", "Tất cả công ty") are
/// returned unchanged.
String compactOrganizationName(String name) {
  final match = _legalForm.firstMatch(name);
  if (match == null) return name;
  final rest = name.substring(match.end).trim();
  return rest.length < 3 ? name : rest;
}
