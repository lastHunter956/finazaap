import 'package:flutter/material.dart';
import 'package:finazaap/Screens/edit_profile_screen.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

class AccountManagement extends StatelessWidget {
  const AccountManagement({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      appBar: MoneoHeaderBar.subScreen(
        title: 'Administrar Cuenta',
      ).asPreferredSize(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Common',
              style: TextStyle(
                color: context.appTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.appTheme.cardBackground,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language, color: context.appTheme.accent),
                  title: Text('Language', style: TextStyle(color: context.appTheme.textPrimary)),
                  trailing: Text('Spanish', style: TextStyle(color: context.appTheme.textSecondary)),
                ),
                Divider(height: 1, color: context.appTheme.borderSubtle),
                ListTile(
                  leading: Icon(Icons.person, color: context.appTheme.accent),
                  title: Text('Editar Perfil', style: TextStyle(color: context.appTheme.textPrimary)),
                  trailing: Icon(Icons.chevron_right, color: context.appTheme.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          onSave: (name, profileImage) {
                            // Implementa la lógica de guardado aquí si es necesario
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
