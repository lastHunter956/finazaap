import 'package:finazaap/providers/pin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PinMode { setup, verify, change, check }

class PinCodeScreen extends StatefulWidget {
  final PinMode mode;
  final Function? onSuccess; // Relaxed type to handle both signatures
  final VoidCallback? onCancel;

  const PinCodeScreen({
    Key? key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
  }) : super(key: key);

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  String _currentPin = '';
  String _tempPin = ''; // Used for setup (confirm step)
  String _title = 'Ingrese su PIN';
  bool _isConfirming = false;
  String? _errorMessage;
  final PinProvider _pinProvider = PinProvider();

  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle() {
    setState(() {
      if (widget.mode == PinMode.setup) {
        _title = _isConfirming ? 'Confirme su nuevo PIN' : 'Cree un nuevo PIN';
      } else if (widget.mode == PinMode.change) {
         _title = 'Ingrese su PIN actual';
      } else {
        _title = 'Ingrese su PIN';
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_currentPin.length < 4) {
      setState(() {
        _currentPin += digit;
        _errorMessage = null;
      });

      if (_currentPin.length == 4) {
        _handlePinSubmit();
      }
    }
  }

  void _onDeletePress() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handlePinSubmit() async {
    final enteredPin = _currentPin;
    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      if (widget.mode == PinMode.setup) {
        if (!_isConfirming) {
          setState(() {
            _tempPin = enteredPin;
            _isConfirming = true;
            _currentPin = '';
            _updateTitle();
          });
        } else {
          if (enteredPin == _tempPin) {
            await _pinProvider.setPin(enteredPin);
            _callOnSuccess(context);
          } else {
             _showError('Los PINs no coinciden. Intente de nuevo.');
             setState(() {
               _isConfirming = false;
               _tempPin = '';
               _currentPin = '';
               _updateTitle();
             });
          }
        }
      } else {
        // Verify mode (or first step of change)
        final isValid = await _pinProvider.verifyPin(enteredPin);
        if (isValid) {
          if (widget.mode == PinMode.change) {
             // Now setup the new pin
             Navigator.pushReplacement(
               context, 
               MaterialPageRoute(builder: (_) => PinCodeScreen(
                 mode: PinMode.setup, 
                 onSuccess: widget.onSuccess,
                 onCancel: widget.onCancel,
               ))
             );
          } else {
            _callOnSuccess(context);
          }
        } else {
          _showError('PIN incorrecto');
          _shakeError();
          setState(() {
            _currentPin = '';
          });
        }
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _callOnSuccess(BuildContext context) {
    if (widget.onSuccess != null) {
      if (widget.onSuccess is void Function(BuildContext)) {
        (widget.onSuccess as void Function(BuildContext))(context);
      } else if (widget.onSuccess is void Function()) {
        (widget.onSuccess as void Function())();
      } else {
        try {
          Function.apply(widget.onSuccess!, [context]);
        } catch (_) {
          Function.apply(widget.onSuccess!, []);
        }
      }
    }
  }

  void _showError(String msg) {
    setState(() {
      _errorMessage = msg;
    });
  }
  
  void _shakeError() {
    HapticFeedback.heavyImpact();
    // Animation could go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onCancel != null ? IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ) : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Icon(Icons.lock_outline, size: 60, color: Color.fromARGB(255, 82, 226, 255)),
                      const SizedBox(height: 30),
                      Text(
                        _title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: const EdgeInsets.all(8),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _currentPin.length ? const Color.fromARGB(255, 82, 226, 255) : Colors.white24,
                            ),
                          );
                        }),
                      ),
                       if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        ),
                      const Spacer(),
                      _buildKeypad(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildRow('1', '2', '3'),
          _buildRow('4', '5', '6'),
          _buildRow('7', '8', '9'),
          _buildRow('', '0', 'del'),
        ],
      ),
    );
  }

  Widget _buildRow(String a, String b, String c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildKey(a),
          _buildKey(b),
          _buildKey(c),
        ],
      ),
    );
  }

  Widget _buildKey(String val) {
    if (val.isEmpty) return const SizedBox(width: 80, height: 80);
    if (val == 'del') {
      return InkWell(
        onTap: _onDeletePress,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80, 
          height: 80,
          alignment: Alignment.center,
          child: const Icon(Icons.backspace_outlined, color: Colors.white),
        ),
      );
    }
    return InkWell(
      onTap: () => _onDigitPress(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        alignment: Alignment.center,
        child: Text(
          val,
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
