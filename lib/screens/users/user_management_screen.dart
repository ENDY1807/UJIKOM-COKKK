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
    final emailController = TextEditingController(text: existing?.googleEmail ?? (existing != null && existing.username.contains('@') ? existing.username : ''));
    final phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    final passwordController = TextEditingController(text: existing?.password ?? '');
    
    // Non-admin can register Pelanggan
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;
    var selectedRole = existing?.role ?? (isAdmin ? UserRole.waiter : UserRole.pelanggan);
    bool isSubscribed = existing?.isSubscribed ?? (selectedRole == UserRole.pelanggan);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                existing == null ? 'Registrasi Pengguna / Pelanggan' : 'Edit Data Pengguna',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        hintText: 'Contoh: Ahmad Fauzi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      enabled: existing == null,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Contoh: fauzi123',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Pelanggan',
                        hintText: 'Contoh: fauzi@gmail.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'No Telepon / WhatsApp',
                        hintText: 'Contoh: 081234567890',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: existing == null ? 'Masukkan Password' : 'Kosongkan jika tidak diubah',
                      ),
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
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                              if (val == UserRole.pelanggan && existing == null) {
                                isSubscribed = true;
                              }
                            });
                          }
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.surfaceBg,
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
                    const SizedBox(height: 12),
                    // Checkbox Langganan VIP
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSubscribed ? const Color(0xFFF0FDF4) : context.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSubscribed ? const Color(0xFF86EFAC) : AppTheme.borderSubtle,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => setDialogState(() => isSubscribed = !isSubscribed),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSubscribed,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (v) => setDialogState(() => isSubscribed = v ?? false),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pelanggan Langganan (VIP Member)',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Mendapat potongan harga belanja 10% & akses pesan mandiri',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();
                    final password = passwordController.text;

                    if (name.isEmpty || (existing == null && (username.isEmpty || password.isEmpty))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mohon lengkapi Nama, Username, dan Password'),
                          backgroundColor: AppTheme.statusRed,
                        ),
                      );
                      return;
                    }

                    if (existing == null) {
                      final exists = widget.db.users.any(
                        (u) => u.username.toLowerCase() == username.toLowerCase(),
                      );
                      if (exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Username sudah terdaftar, gunakan yang lain'),
                            backgroundColor: AppTheme.statusRed,
                          ),
                        );
                        return;
                      }
                      widget.db.addUser(
                        username,
                        password,
                        name,
                        selectedRole,
                        email: email.isNotEmpty ? email : null,
                        phoneNumber: phone,
                        isSubscribed: isSubscribed,
                      );
                    } else {
                      widget.db.updateUser(
                        existing.idUser,
                        name,
                        password,
                        selectedRole,
                        email: email.isNotEmpty ? email : null,
                        phoneNumber: phone,
                        isSubscribed: isSubscribed,
                      );
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
      backgroundColor: context.surfaceBg,
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
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
                            if (user.isSubscribed) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Text(
                                  'VIP Langganan',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Username: @${user.username}${user.phoneNumber.isNotEmpty ? ' • ${user.phoneNumber}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        if (user.googleEmail != null && user.googleEmail!.isNotEmpty)
                          Text(
                            user.googleEmail!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                  if ((isAdmin || widget.db.currentUser?.role == UserRole.waiter) && !isCurrentUser) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Edit Data',
                      onPressed: () => _showAddUserDialog(user),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.statusRed),
                        tooltip: 'Hapus Pengguna',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (delCtx) => AlertDialog(
                              backgroundColor: AppTheme.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              content: Text('Yakin ingin menghapus pengguna "${user.namaUser}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(delCtx).pop(),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                                  onPressed: () {
                                    widget.db.deleteUser(user.idUser);
                                    Navigator.of(delCtx).pop();
                                    setState(() {});
                                  },
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
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
        label: const Text('Registrasi User / Pelanggan'),
        onPressed: () => _showAddUserDialog(),
      ),
    );
  }
}
