import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_feedback.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  String? _avatarPath;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final action = ref.watch(authControllerProvider);
    if (!_initialized) {
      _name.text = user?.displayName ?? 'No name';
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TripWeave'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: action.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, ${user?.displayName ?? 'User'}!',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  const Text(
                    'Your trip space is ready. Trip creation is the next project phase.',
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundImage: user?.avatarUrl == null
                              ? null
                              : NetworkImage(user!.avatarUrl!),
                          child: user?.avatarUrl == null
                              ? const Icon(Icons.person_rounded, size: 42)
                              : null,
                        ),
                        TextButton.icon(
                          onPressed: _pickAvatar,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Choose profile photo'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              const InputDecoration(labelText: 'Display name'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: user?.email,
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: action.isLoading ? null : _save,
                            child: const Text('Save profile'),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (image != null) setState(() => _avatarPath = image.path);
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid display name.')),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).updateProfile(
          name: _name.text,
          avatarPath: _avatarPath,
        );
    if (!mounted) return;
    if (!ok) {
      showAuthError(context, ref.read(authControllerProvider));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }
}
