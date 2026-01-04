import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/icon_lists.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';

class AddResponsibilityDialog extends StatefulWidget {
  final Responsibility? responsibility;

  const AddResponsibilityDialog({Key? key, this.responsibility}) : super(key: key);

  @override
  State<AddResponsibilityDialog> createState() => _AddResponsibilityDialogState();
}

class _AddResponsibilityDialogState extends State<AddResponsibilityDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _dueDayCtrl;
  late TextEditingController _cardLimitCtrl;
  late TextEditingController _cardBalanceCtrl;
  late TextEditingController _interestRateCtrl;
  late TextEditingController _installmentsCtrl;

  String _selectedCategory = 'servicio';
  String _selectedFrequency = 'mensual';
  late int _selectedIconCode;
  Color iconColor = const Color(0xFF3D7AF0);

  @override
  void initState() {
    super.initState();
    final r = widget.responsibility;
    _nameCtrl = TextEditingController(text: r?.safeName ?? '');
    _amountCtrl = TextEditingController(text: r?.safeAmount.toStringAsFixed(0) ?? '');
    _dueDayCtrl = TextEditingController(text: r?.safeDueDay.toString() ?? '1');
    _cardLimitCtrl = TextEditingController(text: r?.cardLimit?.toStringAsFixed(0) ?? '');
    _cardBalanceCtrl = TextEditingController(text: r?.cardBalance?.toStringAsFixed(0) ?? '');
    _interestRateCtrl = TextEditingController(text: r?.interestRate?.toString() ?? '');
    _installmentsCtrl = TextEditingController(text: r?.installments?.toString() ?? '1');
    
    _selectedCategory = r?.safeCategory ?? 'servicio';
    _selectedFrequency = r?.safeFrequency ?? 'mensual';
    _selectedIconCode = r?.safeIconCode ?? 0xe3a6; // Icons.lightbulb
    
    if (_selectedCategory == 'cuota_manejo') iconColor = const Color(0xFFEF4444);
    if (_selectedCategory == 'préstamo') iconColor = const Color(0xFFF59E0B);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    _cardLimitCtrl.dispose();
    _cardBalanceCtrl.dispose();
    _interestRateCtrl.dispose();
    _installmentsCtrl.dispose();
    super.dispose();
  }

  void _calculateCardPayment() {
    if (_selectedCategory == 'préstamo') {
      final balance = double.tryParse(_cardBalanceCtrl.text) ?? 0;
      final rate = (double.tryParse(_interestRateCtrl.text) ?? 0) / 100;
      final n = int.tryParse(_installmentsCtrl.text) ?? 1;

      if (balance > 0 && n > 0) {
        double monthly;
        if (rate > 0) {
          monthly = balance * (rate * math.pow(1 + rate, n)) / (math.pow(1 + rate, n) - 1);
        } else {
          monthly = balance / n;
        }
        _amountCtrl.text = monthly.toStringAsFixed(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = false; // El préstamo ahora es una obligación simple como servicio

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xFF222939),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header con gradiente
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            iconColor.withOpacity(0.25),
                            iconColor.withOpacity(0.05),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: iconColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              IconData(_selectedIconCode, fontFamily: 'MaterialIcons'),
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.responsibility == null ? 'Nueva Obligación' : 'Editar Obligación',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Organiza tus gastos fijos',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cuerpo del formulario
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel('Nombre de la obligación'),
                          _buildInputField(
                            child: TextFormField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Ej: Alquiler, Netflix...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.label_important_outline, color: iconColor.withOpacity(0.7), size: 22),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Categoría'),
                                    _buildDropdown(
                                      value: _selectedCategory,
                                      items: ResponsibilityService.availableCategories,
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedCategory = v!;
                                          switch (v) {
                                            case 'cuota_manejo':
                                              iconColor = const Color(0xFFEF4444);
                                              _selectedIconCode = Icons.credit_card.codePoint;
                                              break;
                                            case 'préstamo':
                                              iconColor = const Color(0xFFF59E0B);
                                              _selectedIconCode = Icons.account_balance.codePoint;
                                              break;
                                            case 'vivienda':
                                              iconColor = const Color(0xFF6366F1);
                                              _selectedIconCode = Icons.home_rounded.codePoint;
                                              break;
                                            case 'seguros':
                                              iconColor = const Color(0xFF10B981);
                                              _selectedIconCode = Icons.verified_user_rounded.codePoint;
                                              break;
                                            case 'educación':
                                              iconColor = const Color(0xFF8B5CF6);
                                              _selectedIconCode = Icons.school_rounded.codePoint;
                                              break;
                                            case 'transporte':
                                              iconColor = const Color(0xFFF59E0B);
                                              _selectedIconCode = Icons.directions_car_rounded.codePoint;
                                              break;
                                            case 'ahorro':
                                              iconColor = const Color(0xFF10B981);
                                              _selectedIconCode = Icons.trending_up_rounded.codePoint;
                                              break;
                                            case 'legal':
                                              iconColor = const Color(0xFF6B7280);
                                              _selectedIconCode = Icons.gavel_rounded.codePoint;
                                              break;
                                            case 'salud':
                                              iconColor = const Color(0xFFEF4444);
                                              _selectedIconCode = Icons.medical_services_rounded.codePoint;
                                              break;
                                            case 'impuestos':
                                              iconColor = const Color(0xFF475569);
                                              _selectedIconCode = Icons.account_balance_rounded.codePoint;
                                              break;
                                            case 'mascotas':
                                              iconColor = const Color(0xFFD97706);
                                              _selectedIconCode = Icons.pets_rounded.codePoint;
                                              break;
                                            case 'otros':
                                              iconColor = const Color(0xFF94A3B8);
                                              _selectedIconCode = Icons.more_horiz_rounded.codePoint;
                                              break;
                                            case 'servicio':
                                              iconColor = const Color(0xFF3D7AF0);
                                              _selectedIconCode = Icons.electrical_services.codePoint;
                                              break;
                                            default:
                                              iconColor = const Color(0xFF8B5CF6);
                                              _selectedIconCode = Icons.subscriptions.codePoint;
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Frecuencia'),
                                    _buildDropdown(
                                      value: _selectedFrequency,
                                      items: ['mensual', 'bimestral', 'trimestral', 'anual'], // Frecuencias permitidas
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedFrequency = v!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          if (isCredit) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Saldo Actual'),
                                      _buildInputField(
                                        child: TextFormField(
                                          controller: _cardBalanceCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (_) => _calculateCardPayment(),
                                          decoration: InputDecoration(
                                            hintText: '0.00',
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: iconColor.withOpacity(0.7), size: 20),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('% Interés'),
                                      _buildInputField(
                                        child: TextFormField(
                                          controller: _interestRateCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (_) => _calculateCardPayment(),
                                          decoration: InputDecoration(
                                            hintText: '2.5',
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(Icons.percent, color: iconColor.withOpacity(0.7), size: 20),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Cuotas'),
                                      _buildInputField(
                                        child: TextFormField(
                                          controller: _installmentsCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (_) => _calculateCardPayment(),
                                          decoration: InputDecoration(
                                            hintText: '12',
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(Icons.repeat, color: iconColor.withOpacity(0.7), size: 20),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Cupo Límite'),
                                      _buildInputField(
                                        child: TextFormField(
                                          controller: _cardLimitCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Ej: 5000',
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(Icons.credit_card, color: iconColor.withOpacity(0.7), size: 20),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                          
                          // Replacement for the Row containing Amount and Due Day
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel(isCredit ? 'Cuota Mensual' : 'Monto Fijo'),
                                    _buildInputField(
                                      highlight: isCredit,
                                      child: TextFormField(
                                        controller: _amountCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          hintText: '0.00',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(Icons.attach_money, color: iconColor, size: 22),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2, // Más espacio para el texto descriptivo
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel(_getDueDayLabel()),
                                    _buildDueDayInput(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          _buildInputLabel('Icono'),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: accountIcons.length,
                              itemBuilder: (context, index) {
                                final icon = accountIcons[index];
                                final isSelected = _selectedIconCode == icon.codePoint;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedIconCode = icon.codePoint),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? iconColor : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: isSelected ? [BoxShadow(color: iconColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                                    ),
                                    child: Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 24),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botones de acción
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: iconColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _save,
                              child: Text(
                                widget.responsibility == null ? 'Crear Obligación' : 'Guardar Cambios',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInputField({required Widget child, bool highlight = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? iconColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required Function(String?) onChanged}) {
    return _buildInputField(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: iconColor.withOpacity(0.7)),
            dropdownColor: const Color(0xFF2A3143),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: items.map((i) {
              String label = i;
              if (i == 'cuota_manejo') label = 'cuota de manejo';
              return DropdownMenuItem(value: i, child: Text(label.toUpperCase()));
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  String _getDueDayLabel() {
    if (_selectedFrequency == 'diario') return 'Vence';
    if (_selectedFrequency == 'semanal') return 'Día de la Semana';
    if (_selectedFrequency == 'quincenal') return 'Primer Pago';
    return 'Día Pago (1-31)';
  }

  Widget _buildDueDayInput() {
    if (_selectedFrequency == 'diario') {
      return _buildInputField(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Text('Todos los días', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ),
      );
    }

    if (_selectedFrequency == 'semanal') {
      final days = {
        '1': 'Lunes', '2': 'Martes', '3': 'Miércoles', 
        '4': 'Jueves', '5': 'Viernes', '6': 'Sábado', '7': 'Domingo'
      };
      
      return _buildInputField(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: days.containsKey(_dueDayCtrl.text) ? _dueDayCtrl.text : '1',
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: iconColor.withOpacity(0.7)),
              dropdownColor: const Color(0xFF2A3143),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: days.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value.toUpperCase()));
              }).toList(),
              onChanged: (v) => setState(() => _dueDayCtrl.text = v!),
            ),
          ),
        ),
      );
    }
    
    // Default fallback
    return _buildInputField(
      child: TextFormField(
        controller: _dueDayCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _selectedFrequency == 'quincenal' ? '1-15' : '1-31',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.calendar_month, color: iconColor.withOpacity(0.7), size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        validator: (v) {
          if (v!.isEmpty) return '?';
          final val = int.tryParse(v);
          if (val == null) return '?';
          if (_selectedFrequency == 'quincenal' && val > 15) return 'Max 15';
          if (val < 1 || val > 31) return 'Inválido';
          return null;
        },
      ),
    );
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final responsibility = Responsibility(
        id: widget.responsibility?.id ?? Uuid().v4(),
        name: _nameCtrl.text,
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        dueDay: int.tryParse(_dueDayCtrl.text) ?? 1,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        iconCode: _selectedIconCode,
        isPaid: widget.responsibility?.isPaid ?? false,
        lastPaymentDate: widget.responsibility?.lastPaymentDate,
        cardLimit: double.tryParse(_cardLimitCtrl.text),
        cardBalance: double.tryParse(_cardBalanceCtrl.text),
        interestRate: double.tryParse(_interestRateCtrl.text),
        installments: int.tryParse(_installmentsCtrl.text),
      );

      if (widget.responsibility == null) {
        await ResponsibilityService.addResponsibility(responsibility);
      } else {
        await ResponsibilityService.updateResponsibility(responsibility);
      }
      
      Navigator.pop(context);
    }
  }
}
