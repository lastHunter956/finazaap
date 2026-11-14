import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

class EditProfileScreen extends StatefulWidget {
  final Function(String, XFile?) onSave;

  const EditProfileScreen({Key? key, required this.onSave}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  XFile? _profileImage;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Scaffold(
      backgroundColor: t.primaryBackground,
      appBar: MoneoHeaderBar.subScreen(
        title: 'Editar Perfil',
      ).asPreferredSize(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: t.textPrimary),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_nameController.text, _profileImage);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.buttonBackground,
                foregroundColor: t.buttonForeground,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

@override
Future<void> loadUserName(Function(String) setUserName) async {
  final prefs = await SharedPreferences.getInstance();
  setUserName(prefs.getString('userName') ?? 'Jesús Martinez');
}

@override
Future<void> saveUserName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('userName', name);
}
