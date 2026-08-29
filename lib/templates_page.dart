import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'constants/app_constants.dart';
import 'novo_treino.dart' show NovoTreinoPage;

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // null = carregando, [] = carregado vazio, [...] = tem dados
  List<QueryDocumentSnapshot>? _templates;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final lista = snap.docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['is_template'] == true;
      }).toList();

      if (mounted) setState(() => _templates = lista);
    } catch (e) {
      if (mounted) setState(() => _templates = []);
    }
  }

  Future<void> _excluir(QueryDocumentSnapshot doc) async {
    final nome =
        (doc.data() as Map<String, dynamic>)['nome_treino'] ?? 'Template';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir template',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Excluir "$nome"? Esta ação não pode ser desfeita.',
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _db.collection('treinos').doc(doc.id).delete();
      // Recarrega a lista após excluir
      setState(() => _templates = null);
      await _carregar();
    }
  }

  Future<void> _editar(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoTreinoPage(
          docId: doc.id,
          dadosIniciais: data,
        ),
      ),
    );
    // Recarrega após editar
    setState(() => _templates = null);
    await _carregar();
  }

  Future<void> _usar(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final dadosBase = Map<String, dynamic>.from(data);
    dadosBase['is_template'] = false;
    dadosBase.remove('data_treino');
    dadosBase.remove('data_criacao');

    await Navigator.push(
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
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.orangeAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('TEMPLATES',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const NovoTreinoPage(modoTemplate: true)),
              );
              // Recarrega após criar novo template
              setState(() => _templates = null);
              await _carregar();
            },
            icon: const Icon(Icons.add,
                color: Colors.purpleAccent, size: 18),
            label: const Text('NOVO',
                style: TextStyle(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Ainda carregando
    if (_templates == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    // Carregado mas vazio
    if (_templates!.isEmpty) {
      return _buildVazio();
    }

    // Tem templates
    return RefreshIndicator(
      color: Colors.purpleAccent,
      onRefresh: () async {
        setState(() => _templates = null);
        await _carregar();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _templates!.length,
        itemBuilder: (_, i) => _buildCard(_templates![i]),
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome_treino'] ?? 'Template';
    final exercicios = (data['exercicios'] as List? ?? []);
    final musculos = (data['musculos'] as List? ?? []).cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Colors.purpleAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
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
                    Text(
                      '${exercicios.length} exercício${exercicios.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // ── BOTÃO EDITAR ──────────────────────────────────
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.orangeAccent, size: 20),
                tooltip: 'Editar',
                onPressed: () => _editar(doc),
              ),
              // ── BOTÃO EXCLUIR ─────────────────────────────────
              IconButton(
                icon: const Icon(Icons.delete_rounded,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Excluir',
                onPressed: () => _excluir(doc),
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
                  final cor = kMusculoCores[m] ?? Colors.purpleAccent;
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
                children: exercicios.take(4).map((ex) {
                  final nomeEx =
                      ((ex as Map)['nome'] as String? ?? '').trim();
                  final qtd =
                      ((ex['series'] as List?) ?? []).length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.fiber_manual_record,
                          color: Colors.purpleAccent, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(nomeEx,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13))),
                      Text('$qtd x',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12)),
                    ]),
                  );
                }).toList(),
              ),
            ),

          if (exercicios.length > 4)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 14, 8),
              child: Text(
                '+ ${exercicios.length - 4} exercício(s)...',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
            ),

          const Divider(color: Colors.white10, height: 1),

          // ── BOTÃO USAR COMO BASE ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
              onPressed: () => _usar(doc),
              icon: const Icon(Icons.play_arrow_rounded,
                  color: Colors.purpleAccent, size: 18),
              label: const Text('USAR COMO BASE',
                  style: TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('Nenhum template ainda',
                style: TextStyle(
                    color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Crie um template para reutilizar\numa estrutura de treino sem digitar\ntudo de novo toda vez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NovoTreinoPage(
                          modoTemplate: true)),
                );
                setState(() => _templates = null);
                await _carregar();
              },
              icon: const Icon(Icons.add),
              label: const Text('CRIAR TEMPLATE',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}