import 'package:meta/meta.dart';

/// A row of `public.profiles`.
@immutable
class Profile {
  const Profile({
    required this.id,
    this.fullName,
    this.phone,
    this.preferredLanguage = 'en',
    this.dateOfBirth,
    this.targetExamYear,
  });

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json['id']! as String,
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
    preferredLanguage: (json['preferred_language'] as String?) ?? 'en',
    dateOfBirth: switch (json['date_of_birth']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    targetExamYear: json['target_exam_year'] as int?,
  );

  final String id;
  final String? fullName;
  final String? phone;

  /// `en` or `kn`.
  final String preferredLanguage;
  final DateTime? dateOfBirth;
  final int? targetExamYear;

  /// Whether the profile has the details collected at signup.
  bool get isComplete => fullName != null && dateOfBirth != null;
}
