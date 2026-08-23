import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../widgets/app_bottom_navigation.dart';
import 'account_settings_screen.dart';
import 'debug_import_screen.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffaf9fd),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46,
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 22),
        ),
        title: const Text(
          'Backup',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _BackupRow(
            label: 'Google Drive automated backup',
            trailing: const Text(
              'Off',
              style: TextStyle(color: Color(0xffd96e60)),
            ),
          ),
          const _BackupRow(label: 'Backup/restore on device'),
          const _BackupRow(label: 'Export backup files to e-mail'),
          const _BackupRow(label: 'Export data to Excel'),
          _BackupRow(
            label: 'Import Excel File',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DebugImportScreen(db: db)),
            ),
          ),
          const _BackupRow(label: 'Export Photo Files'),
          const _BackupRow(label: 'Import Photo Files'),
          const _BackupRow(label: 'Help (backup/restore)'),
          const _SectionLabel('Reset'),
          const _BackupRow(label: 'A complete reset'),
          const _BackupRow(label: 'Reset contents only (Others remain)'),
        ],
      ),
      bottomNavigationBar: _BackupBottomBar(db: db),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.label, this.trailing, this.onTap});

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap ?? () {},
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 14)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        color: Color(0xfff7f6fa),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xffe3e3e3)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xff888888)),
      ),
    );
  }
}

class _BackupBottomBar extends StatelessWidget {
  const _BackupBottomBar({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavigation(
      currentIndex: 3,
      onTap: (index) {
        if (index == 0 || index == 1) {
          Navigator.popUntil(context, (route) => route.isFirst);
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
