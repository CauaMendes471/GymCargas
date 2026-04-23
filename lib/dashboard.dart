import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'novo_treino.dart' show NovoTreinoPage;
import 'perfil.dart';
import 'treino_detalhe.dart';
import 'comparar_treinos.dart';
import 'criar_treino_page.dart';
import 'templates_page.dart';
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

  final _buscaController = TextEditingController();
  String _termoBusca = '';
  String _ordemHistorico = 'data'; // 'data' | 'volume' | 'nome'

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

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid ?? '';

    final List<Widget> _paginas = [
      _buildHomeTab(uid),
      _buildHistoricoTab(uid),
      const EvolucaoPage(),
      const SizedBox(), // perfil — abre via push
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: IndexedStack(
          index: _paginaAtual > 2 ? 0 : _paginaAtual,
          children: [
            _buildHomeTab(uid),
            _buildHistoricoTab(uid),
            const EvolucaoPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CriarTreinoPage()));
          setState(() {});
        },
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomAppBar(
      color: const Color(0xFF161616),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard_rounded, 'Home', 0),
            _navItem(Icons.history_rounded, 'Histórico', 1),
            const SizedBox(width: 40),
            _navItem(Icons.bar_chart_rounded, 'Evolução', 2),
            _navItem(Icons.person_outline, 'Perfil', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _paginaAtual == index;
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PerfilPage()));
        } else {
          setState(() => _paginaAtual = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: sel ? Colors.orangeAccent : Colors.white24,
              size: 26),
          Text(label,
              style: TextStyle(
                  color: sel ? Colors.orangeAccent : Colors.white24,
                  fontSize: 10)),
        ],
      ),
    );
  }

  // ── ABA HOME ───────────────────────────────────────────────────────────────
  Widget _buildHomeTab(String uid) {
    final user = _auth.currentUser;
    final nome = user?.displayName?.split(' ').first ?? 'Campeão';

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('treinos')
          .where('userId', isEqualTo: uid)
          .orderBy('data_treino', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final treinos = snap.data?.docs ?? [];
        final total = treinos.length;

        // Treinos dessa semana
        final agora = DateTime.now();
        final inicioSemana =
            agora.subtract(Duration(days: agora.weekday % 7));
        final esSemana = treinos.where((doc) {
          final data = doc['data_treino'] as Timestamp?;
          if (data == null) return false;
          return data.toDate().isAfter(
              inicioSemana.subtract(const Duration(days: 1)));
        }).length;

        // Monta mapa dia-da-semana → quantidade
        final Map<int, int> porDia = {
          0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0
        };
        for (final doc in treinos) {
          final ts = doc['data_treino'] as Timestamp?;
          if (ts == null) continue;
          final d = ts.toDate();
          final diff = agora
              .difference(DateTime(d.year, d.month, d.day))
              .inDays;
          if (diff < 7) {
            // weekday: 1=seg..7=dom, adaptamos para 0=dom..6=sab
            final wd = d.weekday % 7; // dom=0
            porDia[wd] = (porDia[wd] ?? 0) + 1;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá, $nome!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const Text('Hoje é dia de bater recordes.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PerfilPage())),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white10,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person,
                              color: Colors.orangeAccent, size: 22)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── STATS CARDS ─────────────────────────────────────────
              Row(children: [
                _buildStatCard(
                  icon: Icons.fitness_center,
                  valor: '$total',
                  label: 'TREINOS\nTOTAIS',
                  cor: Colors.orangeAccent,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.calendar_today_rounded,
                  valor: '$esSemana',
                  label: 'ESSA\nSEMANA',
                  cor: Colors.blueAccent,
                ),
              ]),
              const SizedBox(height: 24),

              // ── PROGRESSO SEMANAL ────────────────────────────────────
              const Text('PROGRESSO SEMANAL',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 14),
              _buildGraficoSemanal(porDia),
              const SizedBox(height: 28),

              // ── ÚLTIMOS TREINOS ──────────────────────────────────────
              const Text('ÚLTIMOS TREINOS',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 14),
              if (!snap.hasData)
                const Center(
                    child: CircularProgressIndicator(
                        color: Colors.orangeAccent))
              else if (treinos.isEmpty)
                _buildVazio()
              else
                ...treinos
                    .take(5)
                    .map((doc) => _buildTreinoCard(doc, uid))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  // ── STAT CARD ──────────────────────────────────────────────────────────────
  Widget _buildStatCard({
    required IconData icon,
    required String valor,
    required String label,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cor, size: 26),
            const SizedBox(height: 10),
            Text(valor,
                style: TextStyle(
                    color: cor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  // ── GRÁFICO SEMANAL ────────────────────────────────────────────────────────
  Widget _buildGraficoSemanal(Map<int, int> porDia) {
    const dias = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    final hoje = DateTime.now().weekday % 7; // dom=0
    final maxVal = porDia.values.fold(0, (a, b) => a > b ? a : b);
    final maxAltura = 90.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final qtd = porDia[i] ?? 0;
        final altura = maxVal > 0
            ? (qtd / maxVal) * maxAltura
            : 0.0;
        final isHoje = i == hoje;
        final temTreino = qtd > 0;

        return Expanded(
          child: Column(
            children: [
              if (temTreino)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$qtd',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox(height: 18),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                height: temTreino ? altura.clamp(18.0, maxAltura) : 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: temTreino
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFB300),
                            Color(0xFFFF5722),
                          ],
                        )
                      : null,
                  color: temTreino ? null : Colors.white10,
                ),
              ),
              const SizedBox(height: 6),
              Text(dias[i],
                  style: TextStyle(
                      color: isHoje
                          ? Colors.orangeAccent
                          : Colors.white38,
                      fontSize: 9,
                      fontWeight: isHoje
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ],
          ),
        );
      }),
    );
  }

  // ── VAZIO ──────────────────────────────────────────────────────────────────
  Widget _buildVazio() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center,
              size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          const Text('Nenhum treino ainda',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Toque no + para registrar seu primeiro treino!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  // ── CARD DO TREINO (com editar / copiar / excluir) ─────────────────────────
  Widget _buildTreinoCard(QueryDocumentSnapshot doc, String uid) {
    final data = doc.data() as Map<String, dynamic>;
    final dataFormatada = DateFormat('dd/MM/yyyy')
        .format((data['data_treino'] as Timestamp).toDate());
    final exercicios = (data['exercicios'] as List? ?? []);
    final totalSeries = exercicios.fold<int>(
        0, (s, ex) => s + ((ex['series'] as List?)?.length ?? 0));

    // Volume em toneladas
    double volume = 0;
    for (final ex in exercicios) {
      for (final s in (ex['series'] as List? ?? [])) {
        final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
        final r = double.tryParse(s['reps']?.toString() ?? '') ?? 0;
        volume += c * r;
      }
    }
    final volumeStr =
        volume > 0 ? '${(volume / 1000).toStringAsFixed(1)}t' : null;

    final musculos = (data['musculos'] as List? ?? []).cast<String>();

    // Cor do músculo (reutilizando a mesma lógica de novo_treino.dart)
    const kMusculoCores = <String, Color>{
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TreinoDetalhePage(
            docId: doc.id,
            dados: data,
          ),
        ),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // ── LINHA PRINCIPAL ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Colors.orangeAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['nome_treino'] ?? 'Treino',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(dataFormatada,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              // ── AÇÕES ──────────────────────────────────────────
              _buildAcaoBtn(
                icon: Icons.copy_rounded,
                color: Colors.blueAccent,
                tooltip: 'Copiar',
                onTap: () => _copiarTreino(doc),
              ),
              _buildAcaoBtn(
                icon: Icons.edit_rounded,
                color: Colors.orangeAccent,
                tooltip: 'Editar',
                onTap: () => _editarTreino(doc),
              ),
              _buildAcaoBtn(
                icon: Icons.share_rounded,
                color: Colors.tealAccent,
                tooltip: 'Compartilhar',
                onTap: () => _compartilharTreino(doc),
              ),
              _buildAcaoBtn(
                icon: Icons.delete_rounded,
                color: Colors.redAccent,
                tooltip: 'Excluir',
                onTap: () => _excluirTreino(doc),
              ),
            ]),
          ),

          // ── CHIPS DE STATS ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(
                    Icons.list_alt_rounded,
                    '${exercicios.length} exercícios',
                    Colors.white24),
                _buildChip(
                    Icons.repeat_rounded,
                    '$totalSeries séries',
                    Colors.white24),
                if (volumeStr != null)
                  _buildChip(
                      Icons.monitor_weight_outlined,
                      'Volume: $volumeStr',
                      Colors.greenAccent),
                ...musculos.map((m) {
                  final cor =
                      kMusculoCores[m] ?? Colors.orangeAccent;
                  return _buildChipColor(m, cor);
                }),
              ],
            ),
          ),
        ],
      ),
    ),  // GestureDetector
    );
  }

  Widget _buildAcaoBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: cor, size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: cor, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildChipColor(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, color: cor, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: cor,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── AÇÕES DO TREINO ────────────────────────────────────────────────────────

  Future<void> _editarTreino(QueryDocumentSnapshot doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoTreinoPage(
          docId: doc.id,
          dadosIniciais: doc.data() as Map<String, dynamic>,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _copiarTreino(QueryDocumentSnapshot doc) async {
    final data = Map<String, dynamic>.from(
        doc.data() as Map<String, dynamic>);
    data['nome_treino'] = '${data['nome_treino']} (cópia)';
    data['data_treino'] = Timestamp.fromDate(DateTime.now());
    data['data_criacao'] = FieldValue.serverTimestamp();

    await _db.collection('treinos').add(data);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blueAccent,
          content: Text('Treino copiado! Edite para personalizar.'),
        ),
      );
    }
  }

  Future<void> _excluirTreino(QueryDocumentSnapshot doc) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir treino',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Tem certeza que quer excluir "${doc['nome_treino']}"?',
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Treino excluído.'),
          ),
        );
      }
    }
  }

  // ── ABA HISTÓRICO ──────────────────────────────────────────────────────────
  Widget _buildHistoricoTab(String uid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER COM ORDENAÇÃO ───────────────────────────────────
          Row(
            children: [
              const Text('HISTÓRICO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              // Botão comparar
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CompararTreinosPage())),
                icon: const Icon(Icons.compare_arrows_rounded,
                    color: Colors.white38, size: 22),
                tooltip: 'Comparar treinos',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // Botão template
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TemplatesPage())),
                icon: const Icon(Icons.bookmark_outlined,
                    color: Colors.white38, size: 22),
                tooltip: 'Templates',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              _buildOrdemSelector(),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _buscaController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar treino...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('treinos')
                  .where('userId', isEqualTo: uid)
                  .orderBy('data_treino', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Colors.orangeAccent));
                }

                // Filtra por busca
                var treinos = snap.data!.docs.where((doc) {
                  final nome = (doc['nome_treino'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nome.contains(_termoBusca);
                }).toList();

                // Ordena conforme seleção
                if (_ordemHistorico == 'nome') {
                  treinos.sort((a, b) =>
                      (a['nome_treino'] ?? '').toString()
                          .compareTo((b['nome_treino'] ?? '').toString()));
                } else if (_ordemHistorico == 'volume') {
                  double _vol(QueryDocumentSnapshot d) {
                    double v = 0;
                    for (final ex in (d['exercicios'] as List? ?? [])) {
                      for (final s in (ex['series'] as List? ?? [])) {
                        v += (double.tryParse(s['carga']?.toString() ?? '') ?? 0) *
                            (double.tryParse(s['reps']?.toString() ?? '') ?? 0);
                      }
                    }
                    return v;
                  }
                  treinos.sort((a, b) => _vol(b).compareTo(_vol(a)));
                }
                // 'data' já vem ordenado do Firestore

                if (treinos.isEmpty) {
                  return Center(child: _buildVazio());
                }
                return ListView.builder(
                  itemCount: treinos.length,
                  itemBuilder: (context, i) =>
                      _buildTreinoCard(treinos[i], uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── SELETOR DE ORDENAÇÃO ───────────────────────────────────────────────────
  Widget _buildOrdemSelector() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('ORDENAR POR',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _buildOrdemOpcao(ctx, 'data', Icons.calendar_today_rounded, 'Data (mais recente)'),
                _buildOrdemOpcao(ctx, 'volume', Icons.monitor_weight_outlined, 'Volume (maior primeiro)'),
                _buildOrdemOpcao(ctx, 'nome', Icons.sort_by_alpha_rounded, 'Nome (A → Z)'),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sort_rounded,
              color: Colors.orangeAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            _ordemHistorico == 'data'
                ? 'Data'
                : _ordemHistorico == 'volume'
                    ? 'Volume'
                    : 'Nome',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down,
              color: Colors.white38, size: 14),
        ]),
      ),
    );
  }

  Widget _buildOrdemOpcao(
      BuildContext ctx, String valor, IconData icon, String label) {
    final sel = _ordemHistorico == valor;
    return ListTile(
      onTap: () {
        setState(() => _ordemHistorico = valor);
        Navigator.pop(ctx);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: sel
              ? Colors.orangeAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: sel ? Colors.orangeAccent : Colors.white38,
            size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: sel ? Colors.orangeAccent : Colors.white70,
              fontWeight:
                  sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 14)),
      trailing: sel
          ? const Icon(Icons.check_circle_rounded,
              color: Colors.orangeAccent, size: 20)
          : null,
    );
  }

  // ── COMPARTILHAR TREINO ────────────────────────────────────────────────────
  Future<void> _compartilharTreino(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome_treino'] ?? 'Treino';
    final ts = data['data_treino'] as Timestamp?;
    final dataStr = ts != null
        ? DateFormat('dd/MM/yyyy').format(ts.toDate())
        : '-';
    final exercicios = (data['exercicios'] as List? ?? []);
    final musculos =
        (data['musculos'] as List? ?? []).cast<String>();

    double volume = 0;
    final buffer = StringBuffer();
    buffer.writeln('💪 *$nome*');
    buffer.writeln('📅 $dataStr');
    if (musculos.isNotEmpty) {
      buffer.writeln('🎯 ${musculos.join(', ')}');
    }
    buffer.writeln();

    for (final ex in exercicios) {
      final nomeEx = (ex['nome'] as String? ?? '').trim();
      if (nomeEx.isEmpty) continue;
      buffer.writeln('⚡ *$nomeEx*');
      final series = (ex['series'] as List? ?? []);
      for (int i = 0; i < series.length; i++) {
        final s = series[i];
        final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
        final r = s['reps']?.toString() ?? '0';
        final dif = (s['dificuldade'] as String? ?? '');
        final difStr = dif == 'facil'
            ? ' ✅'
            : dif == 'medio'
                ? ' ⚡'
                : dif == 'dificil'
                    ? ' 🔥'
                    : '';
        volume += c * (double.tryParse(r) ?? 0);
        buffer.writeln(
            '  ${i + 1}ª ${c % 1 == 0 ? c.toInt() : c}kg × $r reps$difStr');
      }
      buffer.writeln();
    }

    buffer.writeln(
        '📊 Volume total: ${(volume / 1000).toStringAsFixed(2)}t');
    buffer.writeln('🏋️ GYM CARGAS');

    final texto = buffer.toString();
    await Clipboard.setData(ClipboardData(text: texto));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: const [
            Icon(Icons.check_circle_rounded,
                color: Colors.tealAccent, size: 20),
            SizedBox(width: 10),
            Text('Resumo copiado! Cole onde quiser 📋',
                style: TextStyle(color: Colors.white)),
          ]),
        ),
      );
    }
  }
}
