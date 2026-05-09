import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/app_user.dart';
import '../../../services/admin_service.dart';
import '../../../services/firestore_service.dart';
import 'member_form_screen.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  Future<void> _openCreateMember(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: const MemberFormScreen(),
          ),
        );
      },
    );
  }

  Future<void> _openEditMember(BuildContext context, AppUser user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: MemberFormScreen(user: user),
          ),
        );
      },
    );
  }

  Future<void> _shareResetLink(BuildContext context, AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating reset link...')),
    );

    try {
      final link = await AdminService().createPasswordResetLink(
        userId: user.uid,
      );
      if (!context.mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      final label = user.name.isNotEmpty ? user.name : user.uid;
      await Share.share('Password reset link for $label:\n$link');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      final message = error is StateError
          ? error.message
          : 'Could not generate reset link.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _buildSubtitle(AppUser user) {
    final parts = <String>[];
    if (user.phone.isNotEmpty) {
      parts.add(user.phone);
    }
    if (user.address.isNotEmpty) {
      parts.add(user.address);
    }
    if (parts.isEmpty) {
      return 'No contact details';
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openCreateMember(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create Member'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: firestoreService.watchUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('Failed to load members.'));
              }

              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return const Center(child: Text('No members yet.'));
              }

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final displayName = user.name.isNotEmpty
                      ? user.name
                      : user.uid;
                  final roleLabel = user.role == 'admin' ? 'Admin' : 'User';
                  return ListTile(
                    title: Text(displayName),
                    subtitle: Text(_buildSubtitle(user)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(roleLabel)),
                        const SizedBox(width: 8),
                        PopupMenuButton<_MemberAction>(
                          onSelected: (value) {
                            if (value == _MemberAction.edit) {
                              _openEditMember(context, user);
                            } else {
                              _shareResetLink(context, user);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _MemberAction.edit,
                              child: Text('Edit details'),
                            ),
                            PopupMenuItem(
                              value: _MemberAction.shareResetLink,
                              child: Text('Share reset link'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _MemberAction { edit, shareResetLink }
