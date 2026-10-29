import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  final DatabaseService db;

  const UserManagementScreen({super.key, required this.db});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  void _showAddUserDialog([UserModel? existing]) {
    final usernameController = TextEditingController(text: existing?.username ?? '');
    final nameController = TextEditingController(text: existing?.namaUser ?? '');
    final passwordController = TextEditingController(text: existing?.password ?? '');
    
    // Non-admin can only register Pelanggan
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;
    var selectedRole = existing?.role ?? (isAdmin ? UserRole.waiter : UserRole.pelanggan);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                existing == null ? 'Registrasi Pengguna Baru' : 'Edit Pengguna',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      enabled: existing == null,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 12),
                    if (isAdmin)
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role / Hak Akses'),
                        items: UserRole.values.map((r) {
                          return DropdownMenuItem(value: r, child: Text(r.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Text('Hak Akses: ${selectedRole.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final username = usernameController.text.trim();
                    final name = nameController.text.trim();
                    final password = passwordController.text;

                    if (name.isEmpty || (existing == null && (username.isEmpty || password.isEmpty))) {
                      return;
                    }

                    if (existing == null) {
                      widget.db.addUser(username, password, name, selectedRole);
                    } else {
                      widget.db.updateUser(existing.idUser, name, password, selectedRole);
                    }

                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: Text(existing == null ? 'Simpan' : 'Perbarui'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.db.users;
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = users[index];
          final isCurrentUser = user.idUser == widget.db.currentUser?.idUser;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.orangeLight,
                    child: Text(
                      user.namaUser.isNotEmpty ? user.namaUser[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.namaUser,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusGreenBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Akun Aktif',
                                  style: TextStyle(fontSize: 10, color: AppTheme.statusGreen, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Username: ${user.username}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.orangeBorder),
                    ),
                    child: Text(
                      user.role.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.orangePrimary),
                    ),
                  ),
                  if (isAdmin && !isCurrentUser) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textMuted),
                      onPressed: () => _showAddUserDialog(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.statusRed),
                      onPressed: () {
                        widget.db.deleteUser(user.idUser);
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.orangePrimary,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Registrasi User'),
        onPressed: () => _showAddUserDialog(),
      ),
    );
  }
}
