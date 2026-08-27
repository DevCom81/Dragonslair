const effectKinds = {'buff', 'debuff', 'wound', 'spell'};

class PlayerEffect {
  const PlayerEffect({
    required this.id,
    required this.name,
    required this.kind,
    this.stat,
    this.delta = 0,
    this.remaining,
    this.source = 'gm',
  });

  final String id;
  final String name;
  final String kind;
  final String? stat;
  final int delta;
  final int? remaining;
  final String source;

  bool get isPermanent => remaining == null;

  factory PlayerEffect.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw ArgumentError('Invalid player effect: $json');
    }
    return parsed;
  }

  static PlayerEffect? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final id = (json['id'] as String? ?? json['name'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? id).trim();
    if (id.isEmpty || name.isEmpty) {
      return null;
    }
    final kindRaw = (json['kind'] as String? ?? json['type'] as String? ?? 'spell')
        .trim();
    final kind = effectKinds.contains(kindRaw) ? kindRaw : 'spell';
    final statRaw =
        (json['stat'] as String? ?? json['ability'] as String?)?.trim();
    const abilities = {
      'strength',
      'dexterity',
      'constitution',
      'intelligence',
      'wisdom',
      'charisma',
    };
    final remainingValue = json['remaining'] ?? json['duration'];
    return PlayerEffect(
      id: id,
      name: name,
      kind: kind,
      stat: abilities.contains(statRaw) ? statRaw : null,
      delta: ((json['delta'] as num?) ?? (json['bonus'] as num?) ?? 0)
          .toInt()
          .clamp(-6, 6),
      remaining: remainingValue == null
          ? null
          : (remainingValue as num).toInt().clamp(1, 20),
      source: (json['source'] as String? ?? 'gm').trim(),
    );
  }

  static List<PlayerEffect> listFromJson(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw ArgumentError('Effects must be a JSON list');
    }
    return value
        .map(tryParse)
        .whereType<PlayerEffect>()
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind,
      'stat': stat,
      'delta': delta,
      'remaining': remaining,
      'source': source,
    };
  }
}
