/// First word of [raw], trimmed, with the first letter capitalized.
/// Returns null when there is no usable name.
String? firstNameOf(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;
  final first = trimmed.split(RegExp(r'\s+')).first;
  if (first.isEmpty) return null;
  if (first.length == 1) return first.toUpperCase();
  return first[0].toUpperCase() + first.substring(1);
}

/// Home greeting: "Hi, Imran" or "Hi there" when no name is set.
String homeGreeting(String? raw) {
  final first = firstNameOf(raw);
  return first == null ? 'Hi there' : 'Hi, $first';
}
