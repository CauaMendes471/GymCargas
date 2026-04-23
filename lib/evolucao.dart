import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'novo_treino.dart' show NovoTreinoPage;

// ── Distância de Levenshtein ──────────────────────────────────────────────────
int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
  for (int i = 0; i <= m; i++) dp[i][0] = i;
  for (int j = 0; j <= n; j++) dp[0][j] = j;
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
              .reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[m][n];
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class EvolucaoPage extends StatefulWidget {
  const EvolucaoPage({super.key});

  @override
  State<EvolucaoPage> createState() => _EvolucaoPageState();
}

class _EvolucaoPageState extends State<EvolucaoPage> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _searchController = TextEditingController();

  List<String> _exercicios = [];
  List<String> _exerciciosFiltrados = [];
  String? _exercicioSelecionado;

  List<Map<String, dynamic>> _pontos = [];
  List<Map<String, dynamic>> _pontosVolume = [];
  bool _carregando = true;
  int _abaGrafico = 0; // 0=carga, 1=toneladas

  // Filtro de treino para o gráfico de toneladas
  List<String> _nomesTreinos = [];
  String? _treinoFiltro; // null = todos

  @override
  void initState() {
    super.initState();
    _carregarExercicios();
    _searchController.addListener(_filtrarExercicios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarExercicios() {
    final query = _norm(_searchController.text);
    if (query.isEmpty) {
      setState(() => _exerciciosFiltrados = List.from(_exercicios));
      return;
    }
    final resultado = _exercicios.where((nome) {
      final n = _norm(nome);
      return n.contains(query) || _levenshtein(n, query) <= 3;
    }).toList();
    setState(() => _exerciciosFiltrados = resultado);
  }

  Future<void> _carregarExercicios() async {
    setState(() => _carregando = true);
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final Map<String, int> contagem = {};
      for (final doc in snap.docs) {
        final exs = (doc.data()['exercicios'] as List? ?? []);
        for (final ex in exs) {
          final nome = (ex['nome'] as String? ?? '').trim();
          if (nome.isEmpty) continue;
          contagem[nome] = (contagem[nome] ?? 0) + 1;
        }
      }

      final List<String> resultado = [];
      final List<String> lista = contagem.keys.toList()
        ..sort((a, b) =>
            (contagem[b] ?? 0).compareTo(contagem[a] ?? 0));

      for (final nome in lista) {
        final normalizado = _norm(nome);
        final jaExiste = resultado
            .any((r) => _levenshtein(_norm(r), normalizado) <= 2);
        if (!jaExiste) resultado.add(nome);
      }
      resultado.sort();

      setState(() {
        _exercicios = resultado;
        _exerciciosFiltrados = List.from(resultado);
        _carregando = false;
        if (resultado.isNotEmpty) {
          _exercicioSelecionado = resultado.first;
          _carregarEvolucao(resultado.first);
        }
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarEvolucao(String exercicio) async {
    setState(() => _carregando = true);
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final List<Map<String, dynamic>> pontos = [];
      final List<Map<String, dynamic>> pontosVolume = [];
      final Set<String> nomesTreinos = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['data_treino'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        final nomeTreino = (data['nome_treino'] as String? ?? '').trim();
        if (nomeTreino.isNotEmpty) nomesTreinos.add(nomeTreino);

        // Volume por treino — respeita filtro de nome de treino
        final dentroDoFiltro =
            _treinoFiltro == null || _treinoFiltro == nomeTreino;
        if (dentroDoFiltro) {
          double volumeTreino = 0;
          final exsVol = (data['exercicios'] as List? ?? []);
          for (final ex in exsVol) {
            for (final s in (ex['series'] as List? ?? [])) {
              final c =
                  double.tryParse(s['carga']?.toString() ?? '') ?? 0;
              final r =
                  double.tryParse(s['reps']?.toString() ?? '') ?? 0;
              volumeTreino += c * r;
            }
          }
          if (volumeTreino > 0) {
            pontosVolume.add({
              'data': date,
              'volume': volumeTreino,
              'nome_treino': nomeTreino,
            });
          }
        }

        // Carga máx por exercício (sem filtro de treino)
        final exs = (data['exercicios'] as List? ?? []);
        for (final ex in exs) {
          final nome = (ex['nome'] as String? ?? '').trim();
          if (_levenshtein(_norm(nome), _norm(exercicio)) > 2) continue;
          double cargaMax = 0;
          for (final s in (ex['series'] as List? ?? [])) {
            final c =
                double.tryParse(s['carga']?.toString() ?? '') ?? 0;
            if (c > cargaMax) cargaMax = c;
          }
          if (cargaMax > 0) {
            pontos.add({'data': date, 'carga': cargaMax});
          }
        }
      }

      pontos.sort((a, b) =>
          (a['data'] as DateTime).compareTo(b['data'] as DateTime));
      pontosVolume.sort((a, b) =>
          (a['data'] as DateTime).compareTo(b['data'] as DateTime));

      final nomesSorted = nomesTreinos.toList()..sort();

      setState(() {
        _pontos = pontos;
        _pontosVolume = pontosVolume;
        _nomesTreinos = nomesSorted;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('EVOLUÇÃO',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _carregando
          ? const Center(
              child:
                  CircularProgressIndicator(color: Colors.orangeAccent))
          : _exercicios.isEmpty
              ? _buildVazio()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BUSCAR EXERCÍCIO',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      if (_exerciciosFiltrados.isNotEmpty)
                        _buildExercicioChips(),
                      const SizedBox(height: 24),
                      if (_exercicioSelecionado != null) ...[
                        Row(children: [
                          const Icon(Icons.fitness_center,
                              color: Colors.orangeAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _exercicioSelecionado!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                      ],
                      if (_pontos.isEmpty)
                        _buildSemDados()
                      else ...[
                        _buildResumo(),
                        const SizedBox(height: 24),
                        _buildSeletorGrafico(),
                        const SizedBox(height: 16),
                        if (_abaGrafico == 0)
                          _buildGraficoCarga()
                        else ...[
                          _buildFiltroDeTreino(),
                          const SizedBox(height: 12),
                          _buildGraficoVolume(),
                        ],
                        const SizedBox(height: 24),
                        const Text('HISTÓRICO DETALHADO',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        _buildListaHistorico(),
                      ],
                      const SizedBox(height: 24),
                      _buildBotaoAdicionarExercicio(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ── AUTOCOMPLETE DE BUSCA ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const [];
        final query = _norm(value.text);
        return _exercicios.where((nome) {
          final n = _norm(nome);
          return n.contains(query) || _levenshtein(n, query) <= 3;
        });
      },
      displayStringForOption: (opt) => opt,
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
        ctrl.addListener(() => _searchController.text = ctrl.text);
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            hintText: 'Ex: leg press, supino, agachamento...',
            hintStyle:
                const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                color: Colors.orangeAccent, size: 20),
            suffixIcon: ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: () {
                      ctrl.clear();
                      _searchController.clear();
                      setState(() => _exerciciosFiltrados =
                          List.from(_exercicios));
                    },
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Colors.orangeAccent),
            ),
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            elevation: 10,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 220, maxWidth: 340),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (ctx, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Row(children: [
                        const Icon(Icons.history,
                            color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 10),
                        Text(opt,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (String selected) {
        setState(() {
          _exercicioSelecionado = selected;
          _exerciciosFiltrados = _exercicios
              .where((e) =>
                  _norm(e).contains(_norm(selected)) ||
                  _levenshtein(_norm(e), _norm(selected)) <= 3)
              .toList();
        });
        _carregarEvolucao(selected);
      },
    );
  }

  // ── CHIPS DE EXERCÍCIOS FILTRADOS ───────────────────────────────────────────
  Widget _buildExercicioChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _exerciciosFiltrados.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final nome = _exerciciosFiltrados[i];
          final sel = nome == _exercicioSelecionado;
          return GestureDetector(
            onTap: () {
              setState(() => _exercicioSelecionado = nome);
              _carregarEvolucao(nome);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.orangeAccent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel
                        ? Colors.orangeAccent
                        : Colors.white12,
                    width: sel ? 1.5 : 1),
              ),
              child: Text(nome,
                  style: TextStyle(
                      color: sel
                          ? Colors.orangeAccent
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  // ── BOTÃO ADICIONAR EXERCÍCIO ───────────────────────────────────────────────
  Widget _buildBotaoAdicionarExercicio() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
        color: Colors.orangeAccent.withOpacity(0.05),
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NovoTreinoPage()),
            ),
        icon: const Icon(Icons.add_circle_outline,
            color: Colors.orangeAccent, size: 20),
        label: const Text('REGISTRAR NOVO TREINO',
            style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8)),
      ),
    );
  }

  // ── CARDS DE RESUMO ─────────────────────────────────────────────────────────
  Widget _buildResumo() {
    final cargas =
        _pontos.map((p) => p['carga'] as double).toList();
    final cargaMax = cargas.reduce((a, b) => a > b ? a : b);
    final cargaInicial = cargas.first;
    final evolucao = cargaMax - cargaInicial;
    final evolucaoPct =
        cargaInicial > 0 ? (evolucao / cargaInicial * 100) : 0.0;

    return Row(children: [
      _buildResumoCard('RECORDE', '${cargaMax.toStringAsFixed(1)} kg',
          Icons.emoji_events, Colors.amberAccent),
      const SizedBox(width: 12),
      _buildResumoCard(
          'EVOLUÇÃO',
          '${evolucao >= 0 ? '+' : ''}${evolucao.toStringAsFixed(1)} kg\n(${evolucaoPct.toStringAsFixed(0)}%)',
          evolucao >= 0 ? Icons.trending_up : Icons.trending_down,
          evolucao >= 0 ? Colors.greenAccent : Colors.redAccent),
      const SizedBox(width: 12),
      _buildResumoCard('SESSÕES', '${_pontos.length}', Icons.repeat,
          Colors.blueAccent),
    ]);
  }

  Widget _buildResumoCard(
      String label, String valor, IconData icon, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: cor, size: 20),
          const SizedBox(height: 6),
          Text(valor,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  // ── SELETOR DE GRÁFICO (2 abas) ─────────────────────────────────────────────
  Widget _buildSeletorGrafico() {
    const opcoes = ['Carga Máx', 'Toneladas'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: List.generate(opcoes.length, (i) {
          final sel = _abaGrafico == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _abaGrafico = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      sel ? Colors.orangeAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(opcoes[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sel ? Colors.black : Colors.white54,
                      fontSize: 12,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── GRÁFICO DE CARGA ────────────────────────────────────────────────────────
  Widget _buildGraficoCarga() {
    final cargas =
        _pontos.map((p) => p['carga'] as double).toList();
    final maxCarga = cargas.reduce((a, b) => a > b ? a : b);
    final minCarga = cargas.reduce((a, b) => a < b ? a : b);
    final range = (maxCarga - minCarga).clamp(1.0, double.infinity);
    const double alturaGrafico = 180;
    const double larguraPonto = 48;
    final double larguraTotal = _pontos.length * larguraPonto;

    return Container(
      height: alturaGrafico + 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SizedBox(
          width: larguraTotal.clamp(300, double.infinity),
          height: alturaGrafico + 60,
          child: CustomPaint(
            painter: _GraficoPainter(
              pontos: _pontos,
              maxCarga: maxCarga,
              minCarga: minCarga,
              range: range,
              alturaGrafico: alturaGrafico,
            ),
          ),
        ),
      ),
    );
  }

  // ── FILTRO DE TREINO (para o gráfico de toneladas) ─────────────────────────
  Widget _buildFiltroDeTreino() {
    if (_nomesTreinos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FILTRAR POR TREINO',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTreinoChip(null),
              const SizedBox(width: 8),
              ..._nomesTreinos.map((nome) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildTreinoChip(nome),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreinoChip(String? nome) {
    final sel = _treinoFiltro == nome;
    final label = nome ?? 'Todos';
    return GestureDetector(
      onTap: () {
        setState(() => _treinoFiltro = nome);
        if (_exercicioSelecionado != null) {
          _carregarEvolucao(_exercicioSelecionado!);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? Colors.orangeAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? Colors.orangeAccent : Colors.white12,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.orangeAccent : Colors.white54,
                fontSize: 12,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // ── GRÁFICO DE TONELADAS ────────────────────────────────────────────────────
  Widget _buildGraficoVolume() {
    if (_pontosVolume.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Nenhum dado disponível.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ),
      );
    }

    const divisor = 1000.0;
    const unidade = 't';

    final volumes = _pontosVolume
        .map((p) => (p['volume'] as double) / divisor)
        .toList();
    final maxVol = volumes.reduce((a, b) => a > b ? a : b);
    final minVol = volumes.reduce((a, b) => a < b ? a : b);
    final range = (maxVol - minVol).clamp(0.001, double.infinity);

    final pontosAjustados = _pontosVolume
        .map((p) => {
              'data': p['data'],
              'volume': (p['volume'] as double) / divisor,
            })
        .toList();

    const double alturaGrafico = 180;
    const double larguraPonto = 56;
    final double larguraTotal = _pontosVolume.length * larguraPonto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _buildResumoCard(
            'PICO',
            '${maxVol.toStringAsFixed(2)}t',
            Icons.emoji_events,
            Colors.amberAccent,
          ),
          const SizedBox(width: 12),
          _buildResumoCard('TREINOS', '${_pontosVolume.length}',
              Icons.repeat, Colors.blueAccent),
          const SizedBox(width: 12),
          _buildResumoCard(
            'EVOLUÇÃO',
            () {
              if (volumes.length < 2) return '-';
              final diff = volumes.last - volumes.first;
              return '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}$unidade';
            }(),
            volumes.length >= 2 && volumes.last >= volumes.first
                ? Icons.trending_up
                : Icons.trending_down,
            volumes.length >= 2 && volumes.last >= volumes.first
                ? Colors.greenAccent
                : Colors.redAccent,
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          height: alturaGrafico + 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: larguraTotal.clamp(300, double.infinity),
              height: alturaGrafico + 60,
              child: CustomPaint(
                painter: _VolumePainter(
                  pontos: pontosAjustados,
                  maxVol: maxVol,
                  minVol: minVol,
                  range: range,
                  alturaGrafico: alturaGrafico,
                  unidade: unidade,
                  isToneladas: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── LISTA HISTÓRICO ─────────────────────────────────────────────────────────
  Widget _buildListaHistorico() {
    final cargaMax = _pontos
        .map((p) => p['carga'] as double)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: _pontos.reversed.map((p) {
        final data = p['data'] as DateTime;
        final carga = p['carga'] as double;
        final isPR = carga == cargaMax;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isPR
                ? Colors.amberAccent.withOpacity(0.07)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isPR
                    ? Colors.amberAccent.withOpacity(0.3)
                    : Colors.white10),
          ),
          child: Row(children: [
            Icon(
              isPR ? Icons.emoji_events : Icons.fitness_center,
              color: isPR ? Colors.amberAccent : Colors.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(DateFormat('dd/MM/yyyy').format(data),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
            ),
            Text('${carga.toStringAsFixed(1)} kg',
                style: TextStyle(
                    color: isPR ? Colors.amberAccent : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (isPR) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('PR',
                    style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildVazio() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('Nenhum treino registrado ainda',
                style:
                    TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Registre treinos para ver sua evolução!',
                style:
                    TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );

  Widget _buildSemDados() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Nenhum dado encontrado para este exercício.\nVerifique se as cargas foram preenchidas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
} // fim de _EvolucaoPageState

// ── CUSTOM PAINTERS ──────────────────────────────────────────────────────────

class _GraficoPainter extends CustomPainter {
  final List<Map<String, dynamic>> pontos;
  final double maxCarga, minCarga, range, alturaGrafico;

  _GraficoPainter({
    required this.pontos,
    required this.maxCarga,
    required this.minCarga,
    required this.range,
    required this.alturaGrafico,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.isEmpty) return;
    final larguraPonto = size.width / pontos.length;
    List<Offset> offsets = [];
    for (int i = 0; i < pontos.length; i++) {
      final carga = pontos[i]['carga'] as double;
      final x = i * larguraPonto + larguraPonto / 2;
      final y = alturaGrafico -
          ((carga - minCarga) / range) * (alturaGrafico - 20) - 10;
      offsets.add(Offset(x, y));
    }

    final paintGrade = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = (alturaGrafico / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrade);
    }

    if (offsets.length > 1) {
      final pathArea = Path()
        ..moveTo(offsets.first.dx, alturaGrafico);
      for (final o in offsets) pathArea.lineTo(o.dx, o.dy);
      pathArea.lineTo(offsets.last.dx, alturaGrafico);
      pathArea.close();
      canvas.drawPath(
          pathArea,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFF8F00).withOpacity(0.3),
                const Color(0xFFFF5722).withOpacity(0.0),
              ],
            ).createShader(
                Rect.fromLTWH(0, 0, size.width, alturaGrafico)));

      final pathLinha = Path()
        ..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        pathLinha.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(
          pathLinha,
          Paint()
            ..color = const Color(0xFFFF8F00)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }

    for (int i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      final carga = pontos[i]['carga'] as double;
      final data = pontos[i]['data'] as DateTime;
      final isPR = carga == maxCarga;

      canvas.drawCircle(
          o,
          isPR ? 7 : 5,
          Paint()
            ..color =
                isPR ? Colors.amberAccent : const Color(0xFFFF8F00)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          o,
          isPR ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      final tp = TextPainter(
        text: TextSpan(
          text: '${carga.toStringAsFixed(0)}kg',
          style: TextStyle(
              color: isPR ? Colors.amberAccent : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - 22));

      final dp = TextPainter(
        text: TextSpan(
          text: DateFormat('dd/MM').format(data),
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      dp.paint(
          canvas, Offset(o.dx - dp.width / 2, alturaGrafico + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _VolumePainter extends CustomPainter {
  final List<Map<String, dynamic>> pontos;
  final double maxVol, minVol, range, alturaGrafico;
  final String unidade;
  final bool isToneladas;

  _VolumePainter({
    required this.pontos,
    required this.maxVol,
    required this.minVol,
    required this.range,
    required this.alturaGrafico,
    required this.unidade,
    required this.isToneladas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.isEmpty) return;
    final larguraPonto = size.width / pontos.length;

    List<Offset> offsets = [];
    for (int i = 0; i < pontos.length; i++) {
      final vol = pontos[i]['volume'] as double;
      final x = i * larguraPonto + larguraPonto / 2;
      final y = alturaGrafico -
          ((vol - minVol) / range) * (alturaGrafico - 20) - 10;
      offsets.add(Offset(x, y));
    }

    final paintGrade = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = (alturaGrafico / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrade);
    }

    if (offsets.length > 1) {
      final pathArea = Path()
        ..moveTo(offsets.first.dx, alturaGrafico);
      for (final o in offsets) pathArea.lineTo(o.dx, o.dy);
      pathArea.lineTo(offsets.last.dx, alturaGrafico);
      pathArea.close();
      canvas.drawPath(
          pathArea,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF43A047).withOpacity(0.3),
                const Color(0xFF43A047).withOpacity(0.0),
              ],
            ).createShader(
                Rect.fromLTWH(0, 0, size.width, alturaGrafico)));

      final pathLinha = Path()
        ..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        pathLinha.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(
          pathLinha,
          Paint()
            ..color = const Color(0xFF66BB6A)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }

    for (int i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      final vol = pontos[i]['volume'] as double;
      final data = pontos[i]['data'] as DateTime;
      final isPeak = vol == maxVol;

      canvas.drawCircle(
          o,
          isPeak ? 7 : 5,
          Paint()
            ..color = isPeak
                ? Colors.amberAccent
                : const Color(0xFF66BB6A)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          o,
          isPeak ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      final label = isToneladas
          ? '${vol.toStringAsFixed(2)}t'
          : '${vol.toStringAsFixed(0)}kg';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: isPeak ? Colors.amberAccent : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - 20));

      final dp = TextPainter(
        text: TextSpan(
          text:
              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      dp.paint(
          canvas, Offset(o.dx - dp.width / 2, alturaGrafico + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}