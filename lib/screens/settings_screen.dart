import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_database.dart';
import '../widgets/app_bottom_navigation.dart';
import 'account_settings_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.db});

  final AppDatabase db;

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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 27, 18, 0),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 34,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
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
            const _SettingsTile(icon: Icons.drafts_outlined, label: 'Feedback'),
          ],
        ),
      ),
      bottomNavigationBar: _SettingsBottomBar(db: db),
    );
  }
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
