import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_database.dart';
import '../security/app_lock_settings.dart';
import '../security/local_auth_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_bottom_navigation.dart';
import 'account_settings_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.db, this.lockAuthenticator});

  final AppDatabase db;

  /// Confirms changes to the fingerprint lock; the system prompt by default.
  final LocalAuthenticator? lockAuthenticator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46,
        titleSpacing: 16,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        actions: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.only(right: 22),
              child: Center(
                child: Text(
                  snapshot.hasData ? snapshot.data!.version : '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xffaaaaaa),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 27, 18, DesignSpacing.lg),
        children: [
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 34,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const _SettingsTile(
                icon: Icons.settings_outlined,
                label: 'Configuration',
              ),
              const _SettingsTile(
                icon: Icons.desktop_windows_outlined,
                label: 'PC Manager',
              ),
              _SettingsTile(
                icon: Icons.refresh,
                label: 'Backup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BackupScreen(db: db)),
                ),
              ),
              const _SettingsTile(icon: Icons.palette_outlined, label: 'Style'),
              const _SettingsTile(icon: Icons.question_mark, label: 'Help'),
              const _SettingsTile(
                icon: Icons.drafts_outlined,
                label: 'Feedback',
              ),
            ],
          ),
          if (AppLockScope.maybeOf(context) case final appLock?) ...[
            const SizedBox(height: DesignSpacing.xxl),
            _SecuritySection(
              appLock: appLock,
              authenticator: lockAuthenticator,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _SettingsBottomBar(db: db),
    );
  }
}

/// Ajustes → Seguridad, following the settings screen of the v1 prototype
/// (`design/`): uppercase group title and a rounded card of 52px rows.
class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.appLock, this.authenticator});

  final AppLockSettings appLock;
  final LocalAuthenticator? authenticator;

  Future<void> _toggle(BuildContext context, bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    // Both turning the lock on and off require the device owner, so a
    // borrowed unlocked phone cannot change it and enabling it proves the
    // device can actually unlock the app afterwards.
    final result = await (authenticator ?? SystemLocalAuthenticator())
        .authenticate();
    switch (result) {
      case LocalAuthenticationResult.authenticated:
        await appLock.setEnabled(enable);
      case LocalAuthenticationResult.unavailable:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Configura una huella o un bloqueo de pantalla en tu teléfono primero.',
            ),
          ),
        );
      case LocalAuthenticationResult.rejected:
      case LocalAuthenticationResult.error:
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo confirmar tu identidad.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = appLock.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignSpacing.xs,
            0,
            DesignSpacing.xs,
            6,
          ),
          child: Text('SEGURIDAD', style: DesignTextStyles.settingsGroupTitle),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: DesignColors.surfaceCard,
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            boxShadow: DesignShadows.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(DesignRadius.lg),
              onTap: () => _toggle(context, !enabled),
              child: Semantics(
                toggled: enabled,
                label: 'Bloqueo con huella',
                excludeSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: DesignColors.textSecondary,
                        ),
                        const SizedBox(width: DesignSpacing.md),
                        const Expanded(
                          child: Text(
                            'Bloqueo con huella',
                            style: DesignTextStyles.body,
                          ),
                        ),
                        _Toggle(value: enabled),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 40×24 toggle of the prototype: primary track when on, grey when off.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 40,
    height: 24,
    padding: const EdgeInsets.all(3),
    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: value ? DesignColors.primary : DesignColors.toggleTrackOff,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: DesignColors.onPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap ?? () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: const Color(0xff555555)),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xff555555)),
          ),
        ],
      ),
    );
  }
}

class _SettingsBottomBar extends StatelessWidget {
  const _SettingsBottomBar({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavigation(
      currentIndex: 3,
      onTap: (index) {
        if (index == 0 || index == 1) {
          Navigator.pop(context);
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AccountSettingsScreen(db: db)),
          );
        }
      },
    );
  }
}
