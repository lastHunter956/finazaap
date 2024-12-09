import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_nameController.text, _profileImage);
                Navigator.pop(context);
              },
              child: Text('Save'),
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
