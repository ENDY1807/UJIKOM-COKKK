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
    
    // Hanya Administrator yang dapat mendaftarkan akun
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;
    var selectedRole = existing?.role ?? UserRole.waiter;
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
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      enabled: existing == null,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Pelanggan',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'No Telepon / WhatsApp',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: existing == null ? 'Password' : 'Password (Kosongkan jika tetap)',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isAdmin)
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Peran Akun'),
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
                            Text(selectedRole.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                                    'Pelanggan Member',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Mendapat potongan harga belanja 10% & pemesanan mandiri',
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
                  onPressed: () async {
                    final username = usernameController.text.trim();
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();
                    final password = passwordController.text;

                    if (name.isEmpty || (existing == null && (username.isEmpty || password.isEmpty))) {
                      return;
                    }

                    if (existing == null) {
                      final exists = widget.db.users.any(
                        (u) => u.username.toLowerCase() == username.toLowerCase(),
                      );
                      if (exists) {
                        return;
                      }
                      await widget.db.addUser(
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

                    if (!ctx.mounted) return;
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
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: context.surfaceBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                'Akses Ditolak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Menu Registrasi Pengguna hanya dapat diakses oleh Administrator.',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final users = widget.db.users;

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 80 + MediaQuery.of(context).padding.bottom),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 540;

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.orangeLight,
                              child: Text(
                                user.namaUser.isNotEmpty ? user.namaUser[0].toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.namaUser,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: context.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isCurrentUser || user.isSubscribed) ...[
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (isCurrentUser)
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
                                        if (user.isSubscribed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF86EFAC)),
                                            ),
                                            child: const Text(
                                              'Member',
                                              style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.orangeLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.orangeBorder),
                              ),
                              child: Text(
                                user.role.label,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.orangePrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Username: @${user.username}${user.phoneNumber.isNotEmpty ? ' • ${user.phoneNumber}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        if (user.googleEmail != null && user.googleEmail!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              user.googleEmail!,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                          ),
                        if ((isAdmin || widget.db.currentUser?.role == UserRole.waiter) && !isCurrentUser) ...[
                          const SizedBox(height: 8),
                          Divider(height: 1, color: context.borderSubtle),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
                                label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                onPressed: () => _showAddUserDialog(user),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.statusRed),
                                  label: const Text('Hapus', style: TextStyle(fontSize: 12, color: AppTheme.statusRed)),
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
                        ],
                      ],
                    );
                  }

                  // Layout Wide Desktop
                  return Row(
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
                                      'Member',
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
                  );
                },
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
