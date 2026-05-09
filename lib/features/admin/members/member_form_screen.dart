import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/app_user.dart';
import '../../../services/admin_service.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.user});

  final AppUser? user;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  bool _busy = false;
  String? _successMessage;
  String? _result;
  String? _error;
  String _countryCode = '+91';

  static const List<Map<String, String>> _countryCodes = [
    {'label': 'IN +91', 'value': '+91'},
    {'label': 'US +1', 'value': '+1'},
    {'label': 'UK +44', 'value': '+44'},
    {'label': 'UAE +971', 'value': '+971'},
  ];

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) {
      _nameController.text = user.name;
      _addressController.text = user.address;
      _hydratePhone(user.phone);
    }
  }

  void _hydratePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) {
      for (final entry in _countryCodes) {
        final code = entry['value'] ?? '';
        if (code.isNotEmpty && trimmed.startsWith(code)) {
          _countryCode = code;
          _phoneController.text = trimmed.substring(code.length);
          return;
        }
      }
    }

    _phoneController.text = trimmed.replaceAll(RegExp(r'\D'), '');
  }

  InputDecoration _inputDecoration(String label, {String? helperText}) {
    return const InputDecoration(
      border: OutlineInputBorder(),
    ).copyWith(labelText: label, helperText: helperText);
  }

  Widget _buildStatus() {
    Widget child = const SizedBox.shrink();
    if (_error != null) {
      child = Text(
        _error!,
        key: const ValueKey('error'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else if (_result != null) {
      child = Column(
        key: const ValueKey('result'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('Reset link: $_result'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _shareResetLink,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: _copyResetLink,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      );
    } else if (_successMessage != null) {
      child = Text(_successMessage!, key: const ValueKey('success'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _successMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final phone = '$_countryCode${_phoneController.text.trim()}';
      final address = _addressController.text.trim();
      final aadhaar = _aadhaarController.text.trim();
      final pan = _panController.text.trim();

      if (_isEdit) {
        await _adminService.updateUser(
          userId: widget.user!.uid,
          name: name,
          phone: phone,
          address: address,
          aadhaar: aadhaar.isEmpty ? null : aadhaar,
          pan: pan.isEmpty ? null : pan,
        );
        setState(() {
          _successMessage = 'Member updated.';
        });
      } else {
        final response = await _adminService.createUser(
          email: _emailController.text.trim(),
          name: name,
          phone: phone,
          address: address,
          aadhaar: aadhaar,
          pan: pan,
        );
        setState(() {
          _result = response['passwordResetLink'] as String?;
        });
      }
    } catch (error) {
      setState(() {
        if (error is StateError) {
          _error = error.message;
        } else {
          _error = _isEdit
              ? 'Could not update member.'
              : 'Could not create member.';
        }
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _shareResetLink() async {
    final link = _result;
    if (link == null || link.isEmpty) {
      return;
    }
    await Share.share('Password reset link:\n$link');
  }

  Future<void> _copyResetLink() async {
    final link = _result;
    if (link == null || link.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reset link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (!_isEdit) ...[
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (!value.contains('@')) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Name'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    initialValue: _countryCode,
                    items: _countryCodes
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry['value'],
                            child: Text(entry['label'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _countryCode = value);
                      }
                    },
                    decoration: _inputDecoration('Code'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: _inputDecoration('Phone'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Required';
                      }
                      if (!RegExp(r'^\d{7,15}$').hasMatch(trimmed)) {
                        return 'Invalid phone number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: _inputDecoration('Address'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aadhaarController,
              decoration: _inputDecoration(
                'Aadhaar',
                helperText: _isEdit ? 'Leave blank to keep unchanged.' : null,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return _isEdit ? null : 'Required';
                }
                if (!RegExp(r'^\d{12}$').hasMatch(trimmed)) {
                  return 'Aadhaar must be 12 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _panController,
              decoration: _inputDecoration(
                'PAN',
                helperText: _isEdit ? 'Leave blank to keep unchanged.' : null,
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(10),
                UpperCaseTextFormatter(),
              ],
              validator: (value) {
                final trimmed = value?.trim().toUpperCase() ?? '';
                if (trimmed.isEmpty) {
                  return _isEdit ? null : 'Required';
                }
                if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(trimmed)) {
                  return 'PAN must be 5 letters, 4 numbers, 1 letter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildStatus(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Update Member' : 'Create Member'),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
