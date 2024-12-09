import 'package:flutter/material.dart';
import 'package:finazaap/screens/edit_profile_screen.dart';
import 'package:image_picker/image_picker.dart'; // Importar el paquete image_picker

class HeaderWidget extends StatelessWidget {
  final String userName;
  final Function(String, XFile?) updateProfile;

  const HeaderWidget({
    Key? key,
    required this.userName,
    required this.updateProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 400, // Alinea a la derecha con un padding de 10
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            // container para el icono de notificaciones
            child: Container(
              height: 40,
              width: 40,
              color: Color.fromRGBO(250, 250, 250, 0.1),
              child: Icon(
                Icons.notifications_none_outlined,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Column(
          children: [
            Container(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  onSave: updateProfile,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Text(
                                _getInitials(userName),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff368983),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          obtenerSaludoSegunHora(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Color.fromARGB(255, 224, 223, 223),
                          ),
                        ),
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return nameParts[0][0] + nameParts[1][0];
    } else if (nameParts.length == 1) {
      return nameParts[0][0];
    }
    return '';
  }

  String obtenerSaludoSegunHora() {
    final horaActual = DateTime.now().hour;

    if (horaActual >= 6 && horaActual < 12) {
      return 'Buenos días';
    } else if (horaActual >= 12 && horaActual < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }
}
