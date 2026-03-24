import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'google_auth_service.dart';

class GymRegisterPage extends StatefulWidget {
  const GymRegisterPage({super.key});

  @override
  State<GymRegisterPage> createState() => _GymRegisterPageState();
}

class _GymRegisterPageState extends State<GymRegisterPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;

  Future<void> _cadastrar() async {
    if (_nomeController.text.trim().isEmpty) {
      _snack("Preencha seu nome!");
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _snack("As senhas não coincidem!");
      return;
    }
    if (_senhaController.text.length < 6) {
      _snack("A senha deve ter pelo menos 6 caracteres!");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
      await cred.user?.updateDisplayName(_nomeController.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GymDashboard()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _snack(_traduzirErro(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);
    try {
      await GoogleAuthService.signIn();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GymDashboard()),
        (_) => false,
      );
    } catch (e) {
      _snack("Erro no login com Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _traduzirErro(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Este e-mail já está cadastrado.';
      case 'invalid-email': return 'E-mail inválido.';
      case 'weak-password': return 'Senha muito fraca.';
      default: return 'Erro: $code';
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orangeAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Column(
          children: [
            // ── BÍCEPS ALINHADOS ──────────────────────────────────────
            // Usa SizedBox fixo para cada lado para evitar inclinação
            SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bíceps esquerdo — sem transform, alinhado ao centro
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Image.asset(
                      'assets/bicepsesquerdo.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),

                  // Título central
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "CRIAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        "CONTA",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),

                  // Bíceps direito
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Image.asset(
                      'assets/bicepsdireito.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Comece sua jornada hoje.",
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),

            _buildGoogleButton(),
            const SizedBox(height: 20),

            Row(
              children: const [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text("ou cadastre com e-mail",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 20),

            _buildField(controller: _nomeController,
                label: "Nome Completo", icon: Icons.person_outline),
            const SizedBox(height: 14),
            _buildField(controller: _emailController,
                label: "E-mail", icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _buildPasswordField(controller: _senhaController,
                label: "Senha", obscure: _obscureSenha,
                onToggle: () => setState(() => _obscureSenha = !_obscureSenha)),
            const SizedBox(height: 14),
            _buildPasswordField(controller: _confirmarSenhaController,
                label: "Confirmar Senha", obscure: _obscureConfirmar,
                onToggle: () => setState(() => _obscureConfirmar = !_obscureConfirmar)),
            const SizedBox(height: 12),

            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (val) => setState(() => _acceptTerms = val!),
              title: const Text("Aceito os termos de uso",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Colors.orangeAccent,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: (_acceptTerms && !_isLoading)
                        ? [const Color(0xFFFF8F00), const Color(0xFFFF5722)]
                        : [Colors.grey.shade700, Colors.grey.shade600],
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: (_acceptTerms && !_isLoading) ? _cadastrar : null,
                  child: Text(_isLoading ? "CRIANDO..." : "CADASTRAR",
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Já tem conta? ",
                    style: TextStyle(color: Colors.white54)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("Entrar",
                      style: TextStyle(color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.orangeAccent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white38),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white12),
          backgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: _isLoading ? null : _loginGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Center(child: Text("G",
                  style: TextStyle(color: Color(0xFF4285F4),
                      fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            const Text("Continuar com Google",
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
