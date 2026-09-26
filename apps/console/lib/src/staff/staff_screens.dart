import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/auth.dart';
import 'staff_providers.dart';

/// While the roles load, or when loading failed (with retry).
class CheckingAccessScreen extends ConsumerWidget {
  const CheckingAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final staff = ref.watch(staffMemberProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [SignOutButton()],
      ),
      body: Center(
        child: staff.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.accessCheckFailed),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(staffMemberProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l10n.checkingAccess),
                ],
              ),
      ),
    );
  }
}

class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = ref.watch(currentUserProvider)?.phone ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [SignOutButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.noAccessTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(l10n.noAccessBody(phone), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Roles: Content admin, Reviewer" for the app bar.
class RolesLabel extends ConsumerWidget {
  const RolesLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roles = ref.watch(staffMemberProvider).value?.roles ?? const {};
    final names = [
      for (final role in StaffRole.values)
        if (roles.contains(role))
          switch (role) {
            StaffRole.reviewer => l10n.roleReviewer,
            StaffRole.contentAdmin => l10n.roleContentAdmin,
            StaffRole.superAdmin => l10n.roleSuperAdmin,
          },
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(l10n.rolesLabel(names.join(', '))),
      ),
    );
  }
}
