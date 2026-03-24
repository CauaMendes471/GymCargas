import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _auth = FirebaseAuth.instance;
  late TextEditingController _nomeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nomeController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nomeController.text.trim().isEmpty) {
      _snack("O nome não pode ser vazio!");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser!;
      await user.updateDisplayName(_nomeController.text.trim());
      await user.reload();
      if (mounted) {
        _snack("Nome atualizado!", cor: Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack("Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Sair", style: TextStyle(color: Colors.white)),
        content: const Text("Deseja realmente sair?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sair", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmar == true) await _auth.signOut();
  }

  void _snack(String msg, {Color cor = Colors.redAccent}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: cor, content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("MEU PERFIL",
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orangeAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── AVATAR ────────────────────────────────────────────────
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white10,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person,
                  color: Colors.orangeAccent, size: 55)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 32),

            // ── NOME ──────────────────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("NOME DE EXIBIÇÃO",
                  style: TextStyle(color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                hintText: "Seu nome",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.person_outline,
                    color: Colors.orangeAccent),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.orangeAccent),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ── SALVAR ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFFF5722)]),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isLoading ? null : _salvar,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                      : const Text("SALVAR ALTERAÇÕES",
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── LOGOUT ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("SAIR DA CONTA",
                    style: TextStyle(color: Colors.redAccent,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),

            // ── INFO DA CONTA ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(children: [
                _buildInfoRow(Icons.email_outlined, "E-mail",
                    user?.email ?? '-'),
                const Divider(color: Colors.white10, height: 20),
                _buildInfoRow(
                  Icons.local_fire_department,
                  "E-mail verificado",
                  user?.emailVerified == true ? "Verificado 🔥" : "Não verificado",
                  cor: user?.emailVerified == true
                      ? Colors.orangeAccent : Colors.white38,
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildInfoRow(
                  Icons.login_outlined, "Provedor",
                  user?.providerData.isNotEmpty == true
                      ? user!.providerData.first.providerId
                      .replaceAll('.com', '') : '-',
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String valor,
      {Color cor = Colors.white70}) {
    return Row(children: [
      Icon(icon, color: Colors.white38, size: 18),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      const Spacer(),
      Flexible(
        child: Text(valor, textAlign: TextAlign.right,
            style: TextStyle(color: cor, fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}
