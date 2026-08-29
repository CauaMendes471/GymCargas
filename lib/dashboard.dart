import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'constants/app_constants.dart';
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (index == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PerfilPage()));
          } else {
            setState(() => _paginaAtual = index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: sel ? Colors.orangeAccent : Colors.white24,
                  size: 26),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.orangeAccent : Colors.white54,
                      fontSize: 10)),
            ],
          ),
        ),
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

        // Agrupa os treinos por dia (yyyy-MM-dd). Usado pelo heatmap tanto
        // para colorir as células por volume (intensidade) quanto para
        // abrir o(s) treino(s) daquele dia ao tocar na célula.
        final Map<String, List<QueryDocumentSnapshot>> treinosPorDia = {};
        for (final doc in treinos) {
          final ts = doc['data_treino'] as Timestamp?;
          if (ts == null) continue;
          final chave = DateFormat('yyyy-MM-dd').format(ts.toDate());
          treinosPorDia.putIfAbsent(chave, () => []).add(doc);
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
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PerfilPage())),
                      customBorder: const CircleBorder(),
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

              // ── CONSISTÊNCIA ANUAL (HEATMAP) ─────────────────────────
              const Text('CONSISTÊNCIA ANUAL',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 14),
              _buildHeatmapAnual(treinosPorDia),
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
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  // ── HEATMAP DE CONSISTÊNCIA ANUAL ───────────────────────────────────────────
  Widget _buildHeatmapAnual(
      Map<String, List<QueryDocumentSnapshot>> treinosPorDia) {
    const double cellSize = 12;
    const double cellMargin = 2;
    const double cellExtent = cellSize + cellMargin * 2;
    const List<String> mesesAbrev = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    // Últimos 365 dias, com o início ajustado para o domingo anterior,
    // garantindo que cada linha do grid (índice % 7) sempre corresponda
    // ao mesmo dia da semana (linha 0 = domingo ... linha 6 = sábado).
    final rawStart = hoje.subtract(const Duration(days: 364));
    final padding = rawStart.weekday % 7; // seg=1..sab=6, dom=0
    final startDate = rawStart.subtract(Duration(days: padding));
    final totalDias = hoje.difference(startDate).inDays + 1;
    final numSemanas = (totalDias / 7).ceil();

    // Descobre em qual semana (coluna) cada mês começa, para alinhar
    // os rótulos "Jan, Fev, Mar..." com o grid abaixo.
    final List<String?> labelPorSemana = List.filled(numSemanas, null);
    int? ultimoMes;
    for (int w = 0; w < numSemanas; w++) {
      final dayIndex = w * 7;
      if (dayIndex >= totalDias) break;
      final data = startDate.add(Duration(days: dayIndex));
      if (ultimoMes != data.month) {
        labelPorSemana[w] = mesesAbrev[data.month - 1];
        ultimoMes = data.month;
      }
    }

    // Volume total por dia (soma de 'volume_total' de todos os treinos
    // daquele dia), usado para graduar a intensidade da cor da célula.
    final Map<String, double> volumePorDia = {
      for (final entry in treinosPorDia.entries)
        entry.key: entry.value.fold<double>(
            0,
            (soma, doc) =>
                soma + ((doc['volume_total'] as num?)?.toDouble() ?? 0)),
    };
    final double maxVolumeDia = volumePorDia.values.isEmpty
        ? 0
        : volumePorDia.values.reduce((a, b) => a > b ? a : b);

    const List<String> diasSemanaAbrev = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    const double alturaLabelMes = 14;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── RÓTULOS DOS DIAS DA SEMANA (coluna fixa, não rola) ─────
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: [
                const SizedBox(height: alturaLabelMes + 4),
                ...List.generate(7, (i) {
                  return SizedBox(
                    height: cellExtent,
                    child: Center(
                      child: Text(
                        diasSemanaAbrev[i],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // ── MESES + GRID (rolável horizontalmente) ─────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── RÓTULOS DOS MESES ────────────────────────────
                  SizedBox(
                    height: alturaLabelMes,
                    child: Row(
                      children: List.generate(numSemanas, (w) {
                        return SizedBox(
                          width: cellExtent,
                          child: Text(
                            labelPorSemana[w] ?? '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 9),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ── GRID DE DIAS (7 linhas × N semanas) ───────────
                  SizedBox(
                    width: numSemanas * cellExtent,
                    height: 7 * cellExtent,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalDias,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisExtent: cellExtent,
                      ),
                      itemBuilder: (context, index) {
                        final data =
                            startDate.add(Duration(days: index));
                        final chave =
                            DateFormat('yyyy-MM-dd').format(data);
                        final docsDoDia = treinosPorDia[chave];
                        final treino =
                            docsDoDia != null && docsDoDia.isNotEmpty;
                        final cor = _corIntensidade(
                            treino ? (volumePorDia[chave] ?? 0) : 0,
                            maxVolumeDia,
                            treino);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: treino
                                ? () =>
                                    _abrirTreinosDoDia(docsDoDia!, data)
                                : null,
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              margin: const EdgeInsets.all(cellMargin),
                              decoration: BoxDecoration(
                                color: cor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calcula a cor da célula do heatmap com base no volume do dia,
  /// relativo ao dia de maior volume do período (graduação em 4 tons).
  /// Dias sem treino ficam cinza; dias com treino nunca ficam totalmente
  /// apagados, mesmo que o volume seja 0/desconhecido (treinos antigos
  /// sem 'volume_total').
  Color _corIntensidade(double volumeDoDia, double maxVolumeDia, bool treino) {
    if (!treino) return Colors.white.withOpacity(0.06);
    if (maxVolumeDia <= 0) return Colors.orangeAccent.withOpacity(0.6);
    final ratio = (volumeDoDia / maxVolumeDia).clamp(0.0, 1.0);
    if (ratio >= 0.75) return Colors.orangeAccent;
    if (ratio >= 0.5) return Colors.orangeAccent.withOpacity(0.75);
    if (ratio >= 0.25) return Colors.orangeAccent.withOpacity(0.5);
    return Colors.orangeAccent.withOpacity(0.3);
  }

  /// Abre o treino do dia tocado na célula do heatmap. Se houver mais de
  /// um treino no mesmo dia, mostra uma lista para o usuário escolher.
  void _abrirTreinosDoDia(
      List<QueryDocumentSnapshot> docs, DateTime data) {
    if (docs.isEmpty) return;

    if (docs.length == 1) {
      final doc = docs.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TreinoDetalhePage(
            docId: doc.id,
            dados: doc.data() as Map<String, dynamic>,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(DateFormat('dd/MM/yyyy').format(data),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text('${docs.length} treinos nesse dia',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final dadosDoc = doc.data() as Map<String, dynamic>;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TreinoDetalhePage(
                          docId: doc.id,
                          dados: dadosDoc,
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fitness_center,
                        color: Colors.orangeAccent),
                    title: Text(dadosDoc['nome_treino'] ?? 'Treino',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Toque no + para registrar seu primeiro treino!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12)),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TreinoDetalhePage(
                docId: doc.id,
                dados: data,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
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
                            color: Colors.white70, fontSize: 12)),
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
    ),
        ),
      ),
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
    // O ícone mantém a cor original (decorativa); o texto usa uma versão
    // de maior contraste quando a cor original é um branco translúcido,
    // sem alterar a cor do ícone.
    final corTexto = cor == Colors.white24
        ? Colors.white54
        : cor == Colors.white38
            ? Colors.white70
            : cor;
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
                color: corTexto, fontSize: 11, fontWeight: FontWeight.w500)),
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
              hintStyle: const TextStyle(color: Colors.white70),
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
                  // Lê o volume já calculado e persistido no Firestore
                  // (campo 'volume_total', gravado em _salvarTreino())
                  // em vez de recalcular somando carga × reps aqui.
                  treinos.sort((a, b) =>
                      ((b['volume_total'] as num?)?.toDouble() ?? 0.0)
                          .compareTo(
                              (a['volume_total'] as num?)?.toDouble() ??
                                  0.0));
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                          color: Colors.white70,
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
        borderRadius: BorderRadius.circular(20),
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