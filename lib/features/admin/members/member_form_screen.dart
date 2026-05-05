import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  bool _busy = false;
  String? _result;
  String? _error;
  String _role = 'user';

  final _emailController = TextEditingController();
  final _existingUidController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final response = await _adminService.createUser(
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        existingUid: _existingUidController.text.trim().isEmpty
            ? null
            : _existingUidController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        aadhaar: _aadhaarController.text.trim(),
        pan: _panController.text.trim(),
        role: _role,
      );

      setState(() {
        _result = response['passwordResetLink'] as String?;
      });
    } catch (error) {
      setState(() {
        _error = 'Could not create member.';
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
    _existingUidController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                if (_existingUidController.text.trim().isNotEmpty) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (!value.contains('@')) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _existingUidController,
              decoration: const InputDecoration(
                labelText: 'Existing UID (Google sign-in)',
              ),
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _aadhaarController,
              decoration: const InputDecoration(labelText: 'Aadhaar'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _panController,
              decoration: const InputDecoration(labelText: 'PAN'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _role = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_result != null) SelectableText('Reset link: $_result'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Member'),
            ),
          ],
        ),
      ),
    );
  }
}
