import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'novo_treino.dart' show NovoTreinoPage;

class CriarTreinoPage extends StatefulWidget {
  const CriarTreinoPage({super.key});

  @override
  State<CriarTreinoPage> createState() => _CriarTreinoPageState();
}

class _CriarTreinoPageState extends State<CriarTreinoPage> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // null = ainda carregando, [] = carregado (pode ser vazio)
  List<QueryDocumentSnapshot>? _templates;
  bool _mostrandoTemplates = false;

  @override
  void initState() {
    super.initState();
    _carregarTemplates();
  }

  Future<void> _carregarTemplates() async {
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final lista = snap.docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['is_template'] == true;
      }).toList();

      if (mounted) {
        setState(() => _templates = lista);
      }
    } catch (e) {
      if (mounted) {
        // Em caso de erro, define lista vazia para não ficar travado
        setState(() => _templates = []);
      }
    }
  }

  void _irParaDoZero() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NovoTreinoPage()),
    );
  }

  void _irParaCriarTemplate() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const NovoTreinoPage(modoTemplate: true)),
    );
  }

  void _usarTemplate(Map<String, dynamic> templateData) {
    final dadosBase = Map<String, dynamic>.from(templateData);
    dadosBase['is_template'] = false;
    dadosBase.remove('data_treino');
    dadosBase.remove('data_criacao');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoTreinoPage(dadosIniciais: dadosBase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white38),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _mostrandoTemplates ? 'ESCOLHER TEMPLATE' : 'NOVO TREINO',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
        // Botão voltar quando estiver na lista de templates
        actions: [
          if (_mostrandoTemplates)
            TextButton(
              onPressed: () =>
                  setState(() => _mostrandoTemplates = false),
              child: const Text('VOLTAR',
                  style: TextStyle(color: Colors.white38)),
            ),
        ],
      ),
      body: _mostrandoTemplates
          ? _buildListaTemplates()
          : _buildEscolhaInicial(),
    );
  }

  // ── TELA DE ESCOLHA ───────────────────────────────────────────────────────
  Widget _buildEscolhaInicial() {
    final carregando = _templates == null;
    final qtd = _templates?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center,
                size: 40, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 24),
          const Text('Como quer começar?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Crie do zero ou use um template\ncomo ponto de partida.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 48),

          // ── OPÇÃO: DO ZERO ─────────────────────────────────────────
          _buildOpcaoCard(
            icon: Icons.add_circle_outline_rounded,
            cor: Colors.orangeAccent,
            titulo: 'Criar do zero',
            descricao: 'Começa com uma folha em branco',
            onTap: _irParaDoZero,
          ),
          const SizedBox(height: 16),

          // ── OPÇÃO: TEMPLATE ────────────────────────────────────────
          _buildOpcaoCard(
            icon: Icons.bookmark_rounded,
            cor: Colors.purpleAccent,
            titulo: 'Usar template salvo',
            descricao: carregando
                ? 'Verificando templates...'
                : qtd == 0
                    ? 'Nenhum template salvo ainda'
                    : '$qtd template${qtd > 1 ? 's' : ''} disponível${qtd > 1 ? 'is' : ''}',
            badge: carregando
                ? null
                : qtd > 0
                    ? '$qtd'
                    : null,
            carregando: carregando,
            // Só permite clicar após carregar E se tiver templates
            onTap: carregando
                ? null
                : qtd == 0
                    ? null
                    : () => setState(() => _mostrandoTemplates = true),
          ),

          const SizedBox(height: 48),

          // ── LINK: CRIAR TEMPLATE ───────────────────────────────────
          GestureDetector(
            onTap: _irParaCriarTemplate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bookmark_add_outlined,
                      color: Colors.white38, size: 16),
                  SizedBox(width: 8),
                  Text('Criar novo template',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcaoCard({
    required IconData icon,
    required Color cor,
    required String titulo,
    required String descricao,
    required VoidCallback? onTap,
    String? badge,
    bool carregando = false,
  }) {
    final disabled = onTap == null && !carregando;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.white.withOpacity(0.02)
              : cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: disabled
                ? Colors.white10
                : cor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.white.withOpacity(0.04)
                  : cor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: carregando
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                        color: cor, strokeWidth: 2),
                  )
                : Icon(icon,
                    color: disabled ? Colors.white24 : cor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        color:
                            disabled ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(descricao,
                    style: TextStyle(
                        color: disabled
                            ? Colors.white24
                            : Colors.white54,
                        fontSize: 12)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(badge,
                  style: TextStyle(
                      color: cor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            )
          else if (!disabled && !carregando)
            Icon(Icons.chevron_right_rounded,
                color: cor.withOpacity(0.6), size: 24),
        ]),
      ),
    );
  }

  // ── LISTA DE TEMPLATES ────────────────────────────────────────────────────
  Widget _buildListaTemplates() {
    final templates = _templates ?? [];

    if (templates.isEmpty) {
      // Não deveria chegar aqui, mas por segurança
      return _buildVazioTemplates();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (_, i) => _buildTemplateCard(templates[i]),
    );
  }

  Widget _buildTemplateCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome_treino'] ?? 'Template';
    final exercicios = (data['exercicios'] as List? ?? []);
    final musculos = (data['musculos'] as List? ?? []).cast<String>();

    const kCores = <String, Color>{
      'Peito': Color(0xFFE53935),
      'Costas': Color(0xFF8E24AA),
      'Ombro': Color(0xFF1E88E5),
      'Bíceps': Color(0xFF00ACC1),
      'Tríceps': Color(0xFF43A047),
      'Pernas': Color(0xFFFB8C00),
      'Glúteos': Color(0xFFD81B60),
      'Abdômen': Color(0xFF6D4C41),
      'Panturrilha': Color(0xFF00897B),
      'Antebraço': Color(0xFF546E7A),
      'Cardio': Color(0xFFE53935),
      'Full Body': Color(0xFFFF8F00),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bookmark_rounded,
                    color: Colors.purpleAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${exercicios.length} exercícios',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),

          // ── MÚSCULOS ────────────────────────────────────────────
          if (musculos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: musculos.map((m) {
                  final cor = kCores[m] ?? Colors.purpleAccent;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: cor.withOpacity(0.3)),
                    ),
                    child: Text(m,
                        style: TextStyle(
                            color: cor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),

          // ── EXERCÍCIOS PREVIEW ───────────────────────────────────
          if (exercicios.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                children: exercicios.take(3).map((ex) {
                  final nomeEx =
                      ((ex as Map)['nome'] as String? ?? '').trim();
                  final qtd =
                      ((ex['series'] as List?) ?? []).length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.fiber_manual_record,
                          color: Colors.purpleAccent, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(nomeEx,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13))),
                      Text('$qtd séries',
                          style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 11)),
                    ]),
                  );
                }).toList(),
              ),
            ),

          if (exercicios.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text('+ ${exercicios.length - 3} mais...',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 12)),
            ),

          // ── BOTÃO USAR ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.purpleAccent.withOpacity(0.15),
                  foregroundColor: Colors.purpleAccent,
                  elevation: 0,
                  side: BorderSide(
                      color: Colors.purpleAccent.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _usarTemplate(data),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('USAR COMO BASE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazioTemplates() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('Nenhum template encontrado',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            onPressed: _irParaCriarTemplate,
            icon: const Icon(Icons.add),
            label: const Text('CRIAR TEMPLATE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}