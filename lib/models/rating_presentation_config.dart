enum ScoreTagCondition {
  gte,
  gt,
  lte,
  lt,
  betweenInclusive;

  static ScoreTagCondition? tryParse(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final condition in values) {
      if (condition.name == value) {
        return condition;
      }
    }
    return null;
  }
}

class ScoreColorRule {
  const ScoreColorRule({
    required this.id,
    required this.minScore,
    required this.maxScore,
    required this.colorHex,
    required this.enabled,
    required this.order,
  });

  final String id;
  final double minScore;
  final double maxScore;
  final String colorHex;
  final bool enabled;
  final int order;

  bool get isValid =>
      id.trim().isNotEmpty &&
      isValidScore(minScore) &&
      isValidScore(maxScore) &&
      minScore <= maxScore &&
      isValidColorHex(colorHex);

  bool matches(double score) =>
      isValid && score >= minScore && score <= maxScore;

  Map<String, Object?> toJson() => {
        'id': id,
        'minScore': minScore,
        'maxScore': maxScore,
        'colorHex': colorHex,
        'enabled': enabled,
        'order': order,
      };

  static ScoreColorRule? tryFromJson(Object? value) {
    final json = _asStringKeyedMap(value);
    if (json == null) {
      return null;
    }
    final id = _nonEmptyString(json['id']);
    final minScore = _scoreFromJson(json['minScore']);
    final maxScore = _scoreFromJson(json['maxScore']);
    final colorHex = _validColorFromJson(json['colorHex']);
    final enabled = json['enabled'];
    final order = _integerFromJson(json['order']);
    if (id == null ||
        minScore == null ||
        maxScore == null ||
        minScore > maxScore ||
        colorHex == null ||
        enabled is! bool ||
        order == null) {
      return null;
    }
    return ScoreColorRule(
      id: id,
      minScore: minScore,
      maxScore: maxScore,
      colorHex: colorHex,
      enabled: enabled,
      order: order,
    );
  }
}

class ScoreTagRule {
  const ScoreTagRule({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.condition,
    required this.threshold,
    this.upperThreshold,
    required this.enabled,
    required this.order,
  });

  final String id;
  final String name;
  final String colorHex;
  final ScoreTagCondition condition;
  final double threshold;
  final double? upperThreshold;
  final bool enabled;
  final int order;

  bool get isValid {
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        !isValidColorHex(colorHex) ||
        !isValidScore(threshold)) {
      return false;
    }
    if (condition != ScoreTagCondition.betweenInclusive) {
      return upperThreshold == null || isValidScore(upperThreshold!);
    }
    return upperThreshold != null &&
        isValidScore(upperThreshold!) &&
        threshold <= upperThreshold!;
  }

  bool matches(double score) {
    if (!isValid) {
      return false;
    }
    return switch (condition) {
      ScoreTagCondition.gte => score >= threshold,
      ScoreTagCondition.gt => score > threshold,
      ScoreTagCondition.lte => score <= threshold,
      ScoreTagCondition.lt => score < threshold,
      ScoreTagCondition.betweenInclusive =>
        score >= threshold && score <= upperThreshold!,
    };
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'condition': condition.name,
        'threshold': threshold,
        if (upperThreshold != null) 'upperThreshold': upperThreshold,
        'enabled': enabled,
        'order': order,
      };

  static ScoreTagRule? tryFromJson(Object? value) {
    final json = _asStringKeyedMap(value);
    if (json == null) {
      return null;
    }
    final id = _nonEmptyString(json['id']);
    final name = _nonEmptyString(json['name']);
    final colorHex = _validColorFromJson(json['colorHex']);
    final condition = ScoreTagCondition.tryParse(json['condition']);
    final threshold = _scoreFromJson(json['threshold']);
    final rawUpperThreshold = json['upperThreshold'];
    final upperThreshold =
        rawUpperThreshold == null ? null : _scoreFromJson(rawUpperThreshold);
    final enabled = json['enabled'];
    final order = _integerFromJson(json['order']);
    if (id == null ||
        name == null ||
        colorHex == null ||
        condition == null ||
        threshold == null ||
        (rawUpperThreshold != null && upperThreshold == null) ||
        enabled is! bool ||
        order == null) {
      return null;
    }
    final rule = ScoreTagRule(
      id: id,
      name: name,
      colorHex: colorHex,
      condition: condition,
      threshold: threshold,
      upperThreshold: upperThreshold,
      enabled: enabled,
      order: order,
    );
    return rule.isValid ? rule : null;
  }
}

class RatingPresentationStyle {
  const RatingPresentationStyle({
    this.unmatchedColorHex,
    this.inactiveStarColorHex,
  });

  final String? unmatchedColorHex;
  final String? inactiveStarColorHex;

  bool get isEmpty => unmatchedColorHex == null && inactiveStarColorHex == null;

  Map<String, Object?> toJson() => {
        if (unmatchedColorHex != null) 'unmatchedColorHex': unmatchedColorHex,
        if (inactiveStarColorHex != null)
          'inactiveStarColorHex': inactiveStarColorHex,
      };

  factory RatingPresentationStyle.fromJson(Object? value) {
    final json = _asStringKeyedMap(value);
    if (json == null) {
      return const RatingPresentationStyle();
    }
    return RatingPresentationStyle(
      unmatchedColorHex: _validColorFromJson(json['unmatchedColorHex']),
      inactiveStarColorHex: _validColorFromJson(json['inactiveStarColorHex']),
    );
  }
}

class RatingPresentationConfig {
  const RatingPresentationConfig({
    this.colorRules = const [],
    this.tags = const [],
    this.style = const RatingPresentationStyle(),
  });

  static const empty = RatingPresentationConfig();

  /// Initial presentation data for installations that have never saved a
  /// rating presentation configuration.
  ///
  /// These are ordinary editable rules, not runtime rating semantics. Once
  /// persisted, users can edit, reorder, disable, or remove every rule.
  static const hanaBookDefaults = RatingPresentationConfig(
    colorRules: [
      ScoreColorRule(
        id: 'default-color-1',
        minScore: 0,
        maxScore: 5.9,
        colorHex: '#7B737D',
        enabled: true,
        order: 0,
      ),
      ScoreColorRule(
        id: 'default-color-2',
        minScore: 6,
        maxScore: 6.9,
        colorHex: '#75879A',
        enabled: true,
        order: 1,
      ),
      ScoreColorRule(
        id: 'default-color-3',
        minScore: 7,
        maxScore: 7.9,
        colorHex: '#70968E',
        enabled: true,
        order: 2,
      ),
      ScoreColorRule(
        id: 'default-color-4',
        minScore: 8,
        maxScore: 8.9,
        colorHex: '#9477A5',
        enabled: true,
        order: 3,
      ),
      ScoreColorRule(
        id: 'default-color-5',
        minScore: 9,
        maxScore: 10,
        colorHex: '#D0A64B',
        enabled: true,
        order: 4,
      ),
    ],
  );

  final List<ScoreColorRule> colorRules;
  final List<ScoreTagRule> tags;
  final RatingPresentationStyle style;

  bool get isEmpty => colorRules.isEmpty && tags.isEmpty && style.isEmpty;

  Map<String, Object?> toJson() => {
        'colorRules': colorRules.map((rule) => rule.toJson()).toList(),
        'tags': tags.map((tag) => tag.toJson()).toList(),
        'style': style.toJson(),
      };

  factory RatingPresentationConfig.fromJson(Object? value) {
    final json = _asStringKeyedMap(value);
    if (json == null) {
      return empty;
    }
    return RatingPresentationConfig(
      colorRules: _validItems(json['colorRules'], ScoreColorRule.tryFromJson),
      tags: _validItems(json['tags'], ScoreTagRule.tryFromJson),
      style: RatingPresentationStyle.fromJson(json['style']),
    );
  }
}

bool isValidScore(double score) => score.isFinite && score >= 0 && score <= 10;

bool isValidColorHex(String value) =>
    RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim());

Map<String, Object?>? _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return null;
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String? _nonEmptyString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

String? _validColorFromJson(Object? value) {
  if (value is! String || !isValidColorHex(value)) {
    return null;
  }
  return value.trim();
}

double? _scoreFromJson(Object? value) {
  if (value is! num) {
    return null;
  }
  final score = value.toDouble();
  return isValidScore(score) ? score : null;
}

int? _integerFromJson(Object? value) {
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    return null;
  }
  return value.toInt();
}

List<T> _validItems<T>(Object? value, T? Function(Object?) parse) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (parse(item) case final parsed?) parsed,
  ];
}
