import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import 'profile_providers.dart';
import 'language_button.dart';
import '../consent/consent.dart';

/// Signup step 1: name, date of birth, exam year, category, language.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  /// Signup is open to ages 13–30 (also enforced by the database).
  static const minAge = 13;
  static const maxAge = 30;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  int? _examYear;
  String? _category;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final dob = parseDate(_dob.text)!;
    final age = ageOn(dob, DateTime.now());
    if (age < ProfileScreen.minAge || age > ProfileScreen.maxAge) {
      setState(() => _error = l10n.errorAgeOutOfRange);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(signupStateProvider.notifier)
          .completeProfile(
            ProfileInput(
              fullName: _name.text,
              dateOfBirth: dob,
              targetExamYear: _examYear!,
              category: _category,
              preferredLanguage: Localizations.localeOf(context).languageCode,
            ),
          );
      // The router moves on to the next step.
    } on SignupFailure catch (e) {
      if (mounted) setState(() => _error = e.localized(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final examYears = ref.watch(targetExamYearsProvider);
    final language = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l10n.profileIntro),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('name-field'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: InputDecoration(labelText: l10n.profileNameLabel),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.profileNameRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('dob-field'),
                controller: _dob,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: l10n.profileDobLabel,
                  hintText: l10n.profileDobHint,
                  helperText: l10n.profileDobOnce,
                  helperMaxLines: 3,
                ),
                validator: (v) =>
                    parseDate(v ?? '') == null ? l10n.profileDobInvalid : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('exam-year-field'),
                initialValue: _examYear,
                decoration: InputDecoration(
                  labelText: l10n.profileExamYearLabel,
                ),
                items: [
                  for (final y in examYears.value ?? const <int>[])
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                // Disabled until the years load.
                onChanged: examYears.hasValue
                    ? (v) => setState(() => _examYear = v)
                    : null,
                validator: (v) =>
                    v == null ? l10n.profileExamYearRequired : null,
              ),
              if (examYears.hasError && !examYears.isLoading)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.profileExamYearsLoadFailed,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('exam-years-retry'),
                      onPressed: () => ref.invalidate(targetExamYearsProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                )
              else if (examYears.value?.isEmpty ?? false)
                Text(
                  l10n.profileExamYearsUnavailable,
                  key: const Key('exam-years-unavailable'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: const Key('category-field'),
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.profileCategoryLabel,
                  helperText: l10n.profileCategoryHelp,
                  helperMaxLines: 2,
                ),
                items: [
                  DropdownMenuItem(child: Text(l10n.categoryNone)),
                  for (final (value, label) in [
                    ('general', l10n.categoryGeneral),
                    ('ews', l10n.categoryEws),
                    ('obc_ncl', l10n.categoryObcNcl),
                    ('sc', l10n.categorySc),
                    ('st', l10n.categorySt),
                  ])
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.profileLanguageLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                  ButtonSegment(value: 'kn', label: Text(l10n.languageKannada)),
                ],
                selected: {language},
                onSelectionChanged: (s) =>
                    ref.read(localeProvider.notifier).preview(s.single),
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                Text(
                  _error!,
                  key: const Key('profile-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              BusyButton(
                label: l10n.continueButton,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses `DD/MM/YYYY`; null if it is not a real date.
@visibleForTesting
DateTime? parseDate(String input) {
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
      .firstMatch(input.trim());
  if (match == null) return null;
  final [d, m, y] = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  final date = DateTime(y, m, d);
  return date.year == y && date.month == m && date.day == d ? date : null;
}

/// Age in whole years on [today].
@visibleForTesting
int ageOn(DateTime dob, DateTime today) {
  var age = today.year - dob.year;
  if (today.month < dob.month ||
      (today.month == dob.month && today.day < dob.day)) {
    age--;
  }
  return age;
}
