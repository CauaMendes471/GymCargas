import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'novo_treino.dart' show NovoTreinoPage, kMusculos;
import 'perfil.dart';
import 'evolucao.dart';

class GymDashboard extends StatefulWidget {
  const GymDashboard({super.key});

  @override
  State<GymDashboard> createState() => _GymDashboardState();
}

class _GymDashboardState extends State<GymDashboard> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  int _paginaAtual = 0;

  // Cache
  List<QueryDocumentSnapshot> _cacheHistorico = [];
  List<QueryDocumentSnapshot> _cacheHome = [];

  // Busca
  final _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() => _termoBusca = _buscaController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // ── STREAK ────────────────────────────────────────────────────────────────
  int _calcularStreak(List<QueryDocumentSnapshot> docs) {
    final Set<String> dias = {};
    for (final doc in docs) {
      final ts = (doc.data() as Map)['data_treino'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        dias.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      }
    }
    int streak = 0;
    DateTime dia = DateTime.now();
    while (true) {
      final key = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      if (dias.contains(key)) {
        streak++;
        dia = dia.subtract(const Duration(days: 1));
      } else {
        if (streak == 0) {
          dia = dia.subtract(const Duration(days: 1));
          final k2 = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
          if (dias.contains(k2)) continue;
        }
        break;
      }
    }
    return streak;
  }

  // ── VOLUME TOTAL ──────────────────────────────────────────────────────────
  double _calcularVolume(List exercicios) {
    double total = 0;
    for (final ex in exercicios) {
      for (final s in (ex['series'] as List? ?? [])) {
        final carga = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
        final reps = double.tryParse(s['reps']?.toString() ?? '') ?? 0;
        total += carga * reps;
      }
    }
    return total;
  }

  // ── ORDENAÇÃO LOCAL ───────────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _ordenarPorData(List<QueryDocumentSnapshot> docs) {
    final lista = List<QueryDocumentSnapshot>.from(docs);
    lista.sort((a, b) {
      final ta = (a.data() as Map)['data_treino'];
      final tb = (b.data() as Map)['data_treino'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return lista;
  }

  // ── FILTRO DE BUSCA ───────────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _filtrar(List<QueryDocumentSnapshot> docs) {
    if (_termoBusca.isEmpty) return docs;
    return docs.where((doc) {
      final nome = ((doc.data() as Map)['nome_treino'] ?? '').toString().toLowerCase();
      return nome.contains(_termoBusca);
    }).toList();
  }

  // ── DELETAR ───────────────────────────────────────────────────────────────
  Future<void> _deletarTreino(String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Apagar treino", style: TextStyle(color: Colors.white)),
        content: const Text("Tem certeza? Esta ação não pode ser desfeita.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Apagar", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmar == true) await _db.collection('treinos').doc(docId).delete();
  }

  // ── EDITAR ────────────────────────────────────────────────────────────────
  void _editarTreino(QueryDocumentSnapshot doc) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NovoTreinoPage(
        docId: doc.id,
        dadosIniciais: doc.data() as Map<String, dynamic>,
      ),
    ));
  }

  // ── DUPLICAR ──────────────────────────────────────────────────────────────
  Future<void> _duplicarTreino(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final uid = _auth.currentUser?.uid ?? '';

    final novo = Map<String, dynamic>.from(data);
    novo['nome_treino'] = '${data['nome_treino']} (cópia)';
    novo['data_treino'] = Timestamp.now();
    novo['data_criacao'] = FieldValue.serverTimestamp();
    novo['userId'] = uid;

    await _db.collection('treinos').add(novo);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Treino duplicado! Edite como quiser."),
        ),
      );
    }
  }

  // ── PERFIL ────────────────────────────────────────────────────────────────
  void _abrirPerfil() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PerfilPage()),
    );
    if (atualizado == true) setState(() {});
  }

  void _abrirEvolucao() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EvolucaoPage()));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final uid = user?.uid ?? '';
    final nome = user?.displayName?.split(' ').first ?? 'Atleta';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NovoTreinoPage()));
        },
        backgroundColor: const Color(0xFFFF5722),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _paginaAtual,
          children: [
            _buildHomePage(uid, nome),
            _buildHistoricoPage(uid),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HOME
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHomePage(String uid, String nome) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(nome),
          const SizedBox(height: 28),
          _buildStatsRow(uid),
          const SizedBox(height: 28),
          _buildGraficoSemanal(uid),
          const SizedBox(height: 28),
          const Text("ÚLTIMOS TREINOS",
              style: TextStyle(color: Colors.white54, fontSize: 12,
                  fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 14),
          _buildUltimosTreinos(uid),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(String nome) {
    final user = _auth.currentUser;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Olá, $nome!",
              style: const TextStyle(color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const Text("Hoje é dia de bater recordes.",
              style: TextStyle(color: Colors.white54, fontSize: 14)),
        ]),
        GestureDetector(
          onTap: _abrirPerfil,
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white10,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? const Icon(Icons.person, color: Colors.orangeAccent) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('treinos').where('userId', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        List<QueryDocumentSnapshot> docs = [];
        if (snap.hasData) { docs = snap.data!.docs; _cacheHome = docs; }
        else if (snap.hasError) { docs = _cacheHome; }

        final total = docs.length;
        final semanaPassada = DateTime.now().subtract(const Duration(days: 7));
        final naSemana = docs.where((doc) {
          final d = (doc.data() as Map)['data_treino'];
          return d is Timestamp && d.toDate().isAfter(semanaPassada);
        }).length;
        final streak = _calcularStreak(docs);

        return Column(children: [
          Row(children: [
            _buildStatCard("TREINOS\nTOTAIS", "$total",
                Icons.fitness_center, Colors.orangeAccent),
            const SizedBox(width: 12),
            _buildStatCard("ESSA\nSEMANA", "$naSemana",
                Icons.calendar_today, Colors.blueAccent),
            const SizedBox(width: 12),
            _buildStatCard("STREAK", "$streak 🔥",
                Icons.local_fire_department, Colors.deepOrangeAccent),
          ]),
          if (streak >= 3) ...[
            const SizedBox(height: 12),
            _buildStreakBanner(streak),
          ],
        ]);
      },
    );
  }

  Widget _buildStatCard(String label, String valor, IconData icon, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: cor, size: 22),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: cor, fontSize: 20,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 9,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildStreakBanner(int streak) {
    String msg;
    if (streak >= 30) msg = "🏆 $streak dias! Você é uma máquina!";
    else if (streak >= 14) msg = "💪 $streak dias seguidos! Incrível!";
    else if (streak >= 7) msg = "🔥 $streak dias na sequência! Continue!";
    else msg = "⚡ $streak dias seguidos! Bom ritmo!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.deepOrange.withOpacity(0.2),
          Colors.orangeAccent.withOpacity(0.1),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.orangeAccent,
              fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildGraficoSemanal(String uid) {
    final hoje = DateTime.now();
    final diasSemana = List.generate(7, (i) => hoje.subtract(Duration(days: 6 - i)));
    final diasLabel = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PROGRESSO SEMANAL",
            style: TextStyle(color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('treinos').where('userId', isEqualTo: uid).snapshots(),
          builder: (context, snap) {
            List<QueryDocumentSnapshot> docs = snap.hasData
                ? snap.data!.docs : _cacheHome;
            final Map<String, int> porDia = {};
            for (final doc in docs) {
              final d = (doc.data() as Map)['data_treino'];
              if (d is Timestamp) {
                final dt = d.toDate();
                final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                porDia[key] = (porDia[key] ?? 0) + 1;
              }
            }
            return SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final dia = diasSemana[i];
                  final key = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
                  final temTreino = (porDia[key] ?? 0) > 0;
                  final isHoje = i == 6;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (temTreino)
                        Container(
                          width: 30, height: 18,
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(child: Text('${porDia[key]}',
                              style: const TextStyle(color: Colors.orangeAccent,
                                  fontSize: 9, fontWeight: FontWeight.bold))),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: temTreino ? 100.0 : 20.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: temTreino ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFF8F00), Color(0xFFFF5722)],
                          ) : null,
                          color: temTreino ? null : Colors.white10,
                          border: isHoje ? Border.all(
                              color: Colors.orangeAccent, width: 1.5) : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(diasLabel[dia.weekday % 7],
                          style: TextStyle(
                              color: isHoje ? Colors.orangeAccent : Colors.white38,
                              fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUltimosTreinos(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('treinos').where('userId', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && _cacheHome.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
        }
        List<QueryDocumentSnapshot> docs = [];
        if (snap.hasData) { docs = _ordenarPorData(snap.data!.docs); _cacheHome = docs; }
        else { docs = _cacheHome; }
        if (docs.isEmpty) return _buildEmptyState();
        return Column(
          children: docs.take(5).map((doc) => _buildTreinoCard(doc, compact: true)).toList(),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HISTÓRICO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoricoPage(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: const Text("HISTÓRICO COMPLETO",
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ),

        // ── CAMPO DE BUSCA ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _buscaController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              hintText: "Buscar treino...",
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _termoBusca.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () => _buscaController.clear(),
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.orangeAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('treinos').where('userId', isEqualTo: uid).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  _cacheHistorico.isEmpty) {
                return const Center(child: CircularProgressIndicator(
                    color: Colors.orangeAccent));
              }
              List<QueryDocumentSnapshot> docs = [];
              if (snap.hasData) {
                docs = _ordenarPorData(snap.data!.docs);
                _cacheHistorico = docs;
              } else {
                docs = _cacheHistorico;
              }

              // Aplica filtro de busca
              final filtrados = _filtrar(docs);

              if (filtrados.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _termoBusca.isNotEmpty
                            ? Icons.search_off : Icons.fitness_center,
                        size: 56,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _termoBusca.isNotEmpty
                            ? "Nenhum treino encontrado\npara \"$_termoBusca\""
                            : "Nenhum treino ainda",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filtrados.length,
                itemBuilder: (context, i) =>
                    _buildTreinoCard(filtrados[i], compact: false),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── CARD DE TREINO ────────────────────────────────────────────────────────
  Widget _buildTreinoCard(QueryDocumentSnapshot doc, {required bool compact}) {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome_treino'] ?? 'Treino';
    final exercicios = data['exercicios'] as List? ?? [];
    final timestamp = data['data_treino'];
    final dataTreino = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    final dataFormatada = DateFormat('dd/MM/yyyy').format(dataTreino);
    final totalSeries = exercicios.fold<int>(
        0, (sum, ex) => sum + ((ex['series'] as List?)?.length ?? 0));
    final volume = _calcularVolume(exercicios);
    final volumeLabel = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}t'
        : '${volume.toStringAsFixed(0)}kg';
    final musculos = (data['musculos'] as List? ?? []).cast<String>();
    final favorito = data['favorito'] == true;

    return GestureDetector(
      onTap: () => _mostrarDetalhesTreino(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Colors.orangeAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (favorito)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      ),
                    Expanded(child: Text(nome,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 2),
                  Text(dataFormatada,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ),
              // ── DUPLICAR ──
              IconButton(
                icon: const Icon(Icons.copy_outlined,
                    color: Colors.blueAccent, size: 20),
                onPressed: () => _duplicarTreino(doc),
                tooltip: "Duplicar",
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.orangeAccent, size: 20),
                onPressed: () => _editarTreino(doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () => _deletarTreino(doc.id),
              ),
            ]),
            const SizedBox(height: 12),

            // ── CHIPS ────────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(Icons.list_alt, '${exercicios.length} exercícios'),
                _buildChip(Icons.repeat, '$totalSeries séries'),
                if (volume > 0)
                  _buildChip(Icons.monitor_weight_outlined,
                      'Volume: $volumeLabel',
                      cor: Colors.greenAccent),
              ],
            ),
            // ── TAGS DE MÚSCULOS ──────────────────────────────────────
            if (musculos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: musculos.map((m) {
                  final mi = kMusculos.firstWhere(
                      (km) => km['nome'] == m,
                      orElse: () => {'cor': Colors.orangeAccent, 'icon': '💪', 'nome': m});
                  final cor = mi['cor'] as Color;
                  final icon = mi['icon'] as String;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cor.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(icon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(m, style: TextStyle(color: cor, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                    ]),
                  );
                }).toList(),
              ),
            ],

            if (!compact && exercicios.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white10),
              const SizedBox(height: 6),
              ...exercicios.take(3).map((ex) {
                final series = ex['series'] as List? ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.bolt, color: Colors.orangeAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ex['nome'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                    Text('${series.length}x',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
                );
              }),
              if (exercicios.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ${exercicios.length - 3} exercício(s)...',
                      style: const TextStyle(color: Colors.white24, fontSize: 11)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, {Color cor = const Color(0xFFFFFFFF)}) {
    final color = cor == const Color(0xFFFFFFFF) ? Colors.white38 : cor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── MODAL DETALHES ────────────────────────────────────────────────────────
  void _mostrarDetalhesTreino(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome_treino'] ?? 'Treino';
    final exercicios = data['exercicios'] as List? ?? [];
    final timestamp = data['data_treino'];
    final dataTreino = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    final volume = _calcularVolume(exercicios);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome, style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yyyy').format(dataTreino),
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
                if (volume > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Volume total: ${volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.toStringAsFixed(0)}kg'}',
                    style: const TextStyle(color: Colors.greenAccent,
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ])),
              TextButton.icon(
                onPressed: () { Navigator.pop(ctx); _editarTreino(doc); },
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.orangeAccent, size: 18),
                label: const Text("Editar",
                    style: TextStyle(color: Colors.orangeAccent)),
              ),
            ]),
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: exercicios.length,
              itemBuilder: (_, i) {
                final ex = exercicios[i];
                final series = ex['series'] as List? ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.bolt, color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(ex['nome'] ?? 'Exercício',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: const [
                      SizedBox(width: 30),
                      Expanded(child: Text('CARGA', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orangeAccent,
                              fontSize: 10, fontWeight: FontWeight.bold))),
                      Expanded(child: Text('REPS', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orangeAccent,
                              fontSize: 10, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 6),
                    ...List.generate(series.length, (si) {
                      final s = series[si];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          SizedBox(width: 30,
                              child: Text('${si + 1}º',
                                  style: const TextStyle(color: Colors.white38,
                                      fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(child: Text('${s['carga']} kg',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.bold))),
                          Expanded(child: Text('${s['reps']} reps',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14))),
                        ]),
                      );
                    }),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.fitness_center, size: 64, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        const Text("Nenhum treino ainda",
            style: TextStyle(color: Colors.white38, fontSize: 16)),
        const SizedBox(height: 8),
        const Text("Toque no + para registrar seu primeiro treino!",
            style: TextStyle(color: Colors.white24, fontSize: 13)),
      ]),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: const Color(0xFF1A1A1A),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.grid_view_rounded,
                  color: _paginaAtual == 0 ? Colors.orangeAccent : Colors.white38),
              onPressed: () => setState(() => _paginaAtual = 0),
            ),
            IconButton(
              icon: Icon(Icons.history_rounded,
                  color: _paginaAtual == 1 ? Colors.orangeAccent : Colors.white38),
              onPressed: () => setState(() => _paginaAtual = 1),
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white38),
              onPressed: _abrirEvolucao,
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded, color: Colors.white38),
              onPressed: _abrirPerfil,
            ),
          ],
        ),
      ),
    );
  }
}
