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

class _PinCodeScreenState extends State<PinCodeScreen> with SingleTickerProviderStateMixin {
  String _currentPin = '';
  String _tempPin = ''; 
  String _title = 'Ingrese su PIN';
  bool _isConfirming = false;
  String? _errorMessage;
  final PinProvider _pinProvider = PinProvider();
  
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  @override
  void dispose() {
    super.dispose();
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
      HapticFeedback.selectionClick();
      setState(() {
        _currentPin += digit;
      });
      
      // Clear error after frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorMessage != null) {
          setState(() {
            _errorMessage = null;
          });
        }
      });

      if (_currentPin.length == 4) {
        _handlePinSubmit();
      }
    }
  }

  void _onDeletePress() {
    if (_currentPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
      // Clear error after frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorMessage != null) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }

  Future<void> _handlePinSubmit() async {
    final enteredPin = _currentPin;
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
             _shakeError();
             setState(() {
               _isConfirming = false;
               _tempPin = '';
               _currentPin = '';
               _updateTitle();
             });
          }
        }
      } else {
        final isValid = await _pinProvider.verifyPin(enteredPin);
        if (isValid) {
          if (widget.mode == PinMode.change) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A2036),
              Color(0xFF0D1321),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final isSmall = h < 600;

              return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeader(),
                            
                            SizedBox(height: isSmall ? 20 : 40),

                            // 2. Lock & PIN Section
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLockIcon(isSmall),
                                SizedBox(height: isSmall ? 16 : 24),
                                Text(
                                  _title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.mode == PinMode.setup 
                                    ? 'Crea un código de 4 dígitos'
                                    : 'Ingresa tu código de acceso',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                SizedBox(height: isSmall ? 24 : 32),
                                _buildPinDots(isSmall),
                              ],
                            ),

                            SizedBox(height: isSmall ? 8 : 12),

                            // 3. Error Section
                            SizedBox(
                              height: 48,
                              child: Center(
                                child: _errorMessage != null ? _buildErrorState() : null,
                              ),
                            ),

                            // 4. Keypad
                            SizedBox(
                              height: h * 0.42, // Re-added fixed height to prevent crash
                              child: Padding(
                                padding: EdgeInsets.only(bottom: isSmall ? 10 : 20),
                                child: _buildPremiumKeypad(isSmall),
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                );
              },
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon(bool isSmallScreen) {
    final double size = isSmallScreen ? 70 : 90;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 20,
          height: size + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A90F7).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4A90F7).withOpacity(0.15),
                const Color(0xFF4A90F7).withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF4A90F7).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.lock_rounded,
            size: size * 0.45,
            color: const Color(0xFF4A90F7),
          ),
        ),
      ],
    );
  }

  Widget _buildPinDots(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < _currentPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFF4A90F7) : Colors.transparent,
            border: Border.all(
              color: isFilled 
                ? const Color(0xFF4A90F7)
                : Colors.white.withOpacity(0.2),
              width: isFilled ? 0 : 2,
            ),
            boxShadow: isFilled ? [
              const BoxShadow(
                color: Color(0x804A90F7),
                blurRadius: 10, 
                spreadRadius: 2,
              ),
            ] : const [],
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (widget.onCancel != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: widget.onCancel,
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumKeypad(bool isSmallScreen) {
    // Calculate button size based on available space
    // We have 4 rows. 
    // Max button size limited by width (3 columns) or height (4 rows)
    
    return Column(
      children: [
        Expanded(child: _buildKeyRow(['1', '2', '3'])),
        Expanded(child: _buildKeyRow(['4', '5', '6'])),
        Expanded(child: _buildKeyRow(['7', '8', '9'])),
        Expanded(
          child: Row(
            children: [
              // Fingerprint button
              Expanded(
                child: widget.mode == PinMode.verify && _pinProvider.isBiometricEnabled
                  ? _buildBiometricKey()
                  : Container(),
              ),
              Expanded(child: _buildPremiumKey('0')),
              Expanded(child: _buildPremiumKey('del', icon: Icons.backspace_outlined)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricKey() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final success = await _pinProvider.authenticateWithBiometrics();
            if (success && mounted) {
              _callOnSuccess(context);
            }
          },
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFF50C878).withOpacity(0.15),
          highlightColor: const Color(0xFF50C878).withOpacity(0.08),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF50C878).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF50C878).withOpacity(0.3),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.fingerprint_rounded,
                color: const Color(0xFF50C878),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys.map((k) => Expanded(child: _buildPremiumKey(k))).toList(),
    );
  }

  Widget _buildPremiumKey(String val, {IconData? icon}) {
    bool isDel = val == 'del';
    
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDel ? _onDeletePress : () => _onDigitPress(val),
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFF4A90F7).withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.05),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDel 
                  ? null 
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                border: Border.all(
                  color: isDel 
                    ? Colors.transparent 
                    : Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: icon != null
                ? Icon(
                    icon,
                    color: Colors.white.withOpacity(0.65),
                    size: 24,
                  )
                : Text(
                    val,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
