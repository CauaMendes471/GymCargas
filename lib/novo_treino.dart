import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'constants/app_constants.dart';
import 'utils/string_utils.dart';

class NovoTreinoPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? dadosIniciais;
  final bool modoTemplate;

  const NovoTreinoPage({
    super.key,
    this.docId,
    this.dadosIniciais,
    this.modoTemplate = false,
  });

  bool get modoEdicao => docId != null;

  @override
  State<NovoTreinoPage> createState() => _NovoTreinoPageState();
}

class _NovoTreinoPageState extends State<NovoTreinoPage> {
  final _nomeTreinoController = TextEditingController();
  final _notasController = TextEditingController();
  DateTime _dataSelecionada = DateTime.now();
  final List<Map<String, dynamic>> _exercicios = [];
  bool _salvando = false;
  bool _favorito = false;
  bool _isTemplate = false;
  final Set<String> _musculosSelecionados = {};
  List<String> _exerciciosConhecidos = [];
  List<String> _nomesTreinosConhecidos = [];

  @override
  void initState() {
    super.initState();
    _isTemplate = widget.modoTemplate;
    _carregarExerciciosConhecidos();

    if (widget.dadosIniciais != null) {
      final dados = widget.dadosIniciais!;
      _nomeTreinoController.text = dados['nome_treino'] ?? '';
      _notasController.text = dados['notas'] ?? '';
      final ts = dados['data_treino'];
      if (ts is Timestamp) _dataSelecionada = ts.toDate();
      _favorito = dados['favorito'] == true;
      _isTemplate = dados['is_template'] == true;
      final musculos = dados['musculos'] as List? ?? [];
      _musculosSelecionados.addAll(musculos.cast<String>());
      final exs = dados['exercicios'] as List? ?? [];
      for (final ex in exs) {
        final series = (ex['series'] as List? ?? []).map((s) => {
              'carga': TextEditingController(text: s['carga'] ?? ''),
              'reps': TextEditingController(text: s['reps'] ?? ''),
              'dificuldade': s['dificuldade'] ?? '',
            }).toList();
        _exercicios.add({
          'nome': TextEditingController(text: ex['nome'] ?? ''),
          'series': series,
        });
      }
      if (_exercicios.isEmpty) _adicionarExercicio();
    } else {
      _adicionarExercicio();
    }
  }

  Future<void> _carregarExerciciosConhecidos() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection('treinos')
          .where('userId', isEqualTo: uid)
          .get();

      final Set<String> nomesEx = {};
      final Set<String> nomesTreino = {};

      for (final doc in snap.docs) {
        // Nomes de treino
        final nomeTreino = (doc.data()['nome_treino'] as String? ?? '').trim();
        if (nomeTreino.isNotEmpty) nomesTreino.add(nomeTreino);
        // Nomes de exercício
        for (final ex in (doc.data()['exercicios'] as List? ?? [])) {
          final nome = (ex['nome'] as String? ?? '').trim();
          if (nome.isNotEmpty) nomesEx.add(nome);
        }
      }

      // Deduplica exercícios com fuzzy
      final List<String> resultadoEx = [];
      for (final nome in nomesEx.toList()..sort()) {
        final n = normalizarNome(nome);
        if (!resultadoEx.any((r) => levenshtein(normalizarNome(r), n) <= 2)) {
          resultadoEx.add(nome);
        }
      }

      if (mounted) {
        setState(() {
          _exerciciosConhecidos = resultadoEx..sort();
          _nomesTreinosConhecidos = nomesTreino.toList()..sort();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nomeTreinoController.dispose();
    _notasController.dispose();
    for (final ex in _exercicios) {
      (ex['nome'] as TextEditingController).dispose();
      for (final s in (ex['series'] as List)) {
        (s['carga'] as TextEditingController).dispose();
        (s['reps'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  Future<bool> _confirmarSaida() async {
    final temConteudo = _nomeTreinoController.text.isNotEmpty ||
        _exercicios
            .any((ex) => (ex['nome'] as TextEditingController).text.isNotEmpty);
    if (!temConteudo) return true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Descartar treino?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Você tem dados não salvos. Quer sair mesmo assim?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando',
                style: TextStyle(color: Colors.orangeAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  Future<void> _selecionarData(BuildContext context) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.orangeAccent,
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (escolhida != null) setState(() => _dataSelecionada = escolhida);
  }

  void _abrirSeletorMusculos() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('GRUPOS MUSCULARES',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              const Text('Selecione todos que se aplicam',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kMusculos.map((m) {
                  final nome = m['nome'] as String;
                  final cor = m['cor'] as Color;
                  final sel = _musculosSelecionados.contains(nome);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setModal(() => setState(() => sel
                          ? _musculosSelecionados.remove(nome)
                          : _musculosSelecionados.add(nome))),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? cor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? cor
                                  : Colors.white.withOpacity(0.1),
                              width: sel ? 1.5 : 1),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(nome,
                                  style: TextStyle(
                                      color: sel ? cor : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: sel
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                              if (sel) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.check_circle,
                                    color: cor, size: 14),
                              ],
                            ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _musculosSelecionados.isEmpty
                        ? 'PULAR'
                        : 'CONFIRMAR (${_musculosSelecionados.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvarTreino() async {
    if (_nomeTreinoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome ao seu treino!')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Volume total do treino (Σ carga × reps de todas as séries).
      // Persistido no Firestore para não precisar ser recalculado
      // no cliente toda vez (ex.: ordenação por volume no histórico).
      double volumeTotal = 0;
      for (final ex in _exercicios) {
        for (final s in (ex['series'] as List)) {
          final carga = double.tryParse(
                  (s['carga'] as TextEditingController).text) ??
              0;
          final reps = double.tryParse(
                  (s['reps'] as TextEditingController).text) ??
              0;
          volumeTotal += carga * reps;
        }
      }

      final Map<String, dynamic> treinoData = {
        'userId': user?.uid ?? 'anonimo',
        'nome_treino': _nomeTreinoController.text.trim(),
        'notas': _notasController.text.trim(),
        'musculos': _musculosSelecionados.toList(),
        'favorito': _favorito,
        'is_template': _isTemplate,
        'volume_total': volumeTotal,
        'exercicios': _exercicios
            .map((ex) => {
                  'nome':
                      (ex['nome'] as TextEditingController).text.trim(),
                  'series': (ex['series'] as List)
                      .map((s) => {
                            'carga': (s['carga'] as TextEditingController)
                                .text,
                            'reps':
                                (s['reps'] as TextEditingController).text,
                            'dificuldade': s['dificuldade'] ?? '',
                          })
                      .toList(),
                })
            .toList(),
      };

      if (!_isTemplate) {
        treinoData['data_treino'] = Timestamp.fromDate(_dataSelecionada);
      }

      if (widget.modoEdicao) {
        await FirebaseFirestore.instance
            .collection('treinos')
            .doc(widget.docId)
            .update(treinoData);
      } else {
        treinoData['data_criacao'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('treinos')
            .add(treinoData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text(_isTemplate
              ? 'Template salvo!'
              : widget.modoEdicao
                  ? 'Treino atualizado!'
                  : 'Treino salvo com sucesso!'),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _adicionarExercicio() {
    setState(() {
      _exercicios.add({
        'nome': TextEditingController(),
        'series': [
          {
            'carga': TextEditingController(),
            'reps': TextEditingController(),
            'dificuldade': '',
          }
        ],
      });
    });
  }

  void _adicionarSerie(int i) {
    setState(() {
      _exercicios[i]['series'].add({
        'carga': TextEditingController(),
        'reps': TextEditingController(),
        'dificuldade': '',
      });
    });
  }

  void _removerSerie(int exIdx, int sIdx) {
    setState(() {
      if (_exercicios[exIdx]['series'].length > 1) {
        final s = _exercicios[exIdx]['series'][sIdx];
        (s['carga'] as TextEditingController).dispose();
        (s['reps'] as TextEditingController).dispose();
        _exercicios[exIdx]['series'].removeAt(sIdx);
      }
    });
  }

  void _removerExercicio(int index) {
    setState(() {
      if (_exercicios.length > 1) {
        final ex = _exercicios[index];
        (ex['nome'] as TextEditingController).dispose();
        for (final s in (ex['series'] as List)) {
          (s['carga'] as TextEditingController).dispose();
          (s['reps'] as TextEditingController).dispose();
        }
        _exercicios.removeAt(index);
      }
    });
  }

  void _setDificuldade(int exIdx, int sIdx, String valor) {
    setState(() {
      final atual = _exercicios[exIdx]['series'][sIdx]['dificuldade'];
      _exercicios[exIdx]['series'][sIdx]['dificuldade'] =
          atual == valor ? '' : valor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _isTemplate
        ? 'TEMPLATE'
        : widget.modoEdicao
            ? 'EDITAR TREINO'
            : 'NOVO TREINO';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final pode = await _confirmarSaida();
        if (pode && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          title: Text(titulo,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          centerTitle: true,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.orangeAccent),
            onPressed: () async {
              final pode = await _confirmarSaida();
              if (pode && mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _favorito
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _favorito ? Colors.amber : Colors.white38,
                size: 26,
              ),
              onPressed: () => setState(() => _favorito = !_favorito),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _salvando ? null : _salvarTreino,
                child: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.orangeAccent, strokeWidth: 2))
                    : const Text('SALVAR',
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOGGLE TEMPLATE ──────────────────────────────────────
              _buildTemplateToggle(),
              const SizedBox(height: 16),

              _buildSectionTitle('INFORMAÇÕES DO TREINO'),
              const SizedBox(height: 12),
              _buildNomeTreinoAutocomplete(),
              const SizedBox(height: 12),

              if (!_isTemplate) ...[
                _buildDatePickerField(),
                const SizedBox(height: 12),
              ],

              _buildMusculosSeletor(),
              const SizedBox(height: 12),

              // ── NOTAS ────────────────────────────────────────────────
              _buildNotasField(),
              const SizedBox(height: 28),

              // ── EXERCÍCIOS ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(
                      'EXERCÍCIOS (${_exercicios.length})'),
                  Row(children: const [
                    Icon(Icons.drag_indicator,
                        color: Colors.white24, size: 14),
                    SizedBox(width: 4),
                    Text('arraste para reordenar',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ]),
                ],
              ),
              const SizedBox(height: 8),

              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercicios.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _exercicios.removeAt(oldIndex);
                    _exercicios.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) =>
                    AnimatedBuilder(
                  animation: animation,
                  builder: (_, child) => Material(
                    color: Colors.transparent,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(18),
                    child: child,
                  ),
                  child: child,
                ),
                itemBuilder: (context, index) =>
                    _buildCardExercicio(index),
              ),

              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _adicionarExercicio,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.3),
                          width: 1.5),
                      color: Colors.orangeAccent.withOpacity(0.05),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 10),
                        Text('ADICIONAR EXERCÍCIO',
                            style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(child: _buildSaveButton()),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOGGLE TEMPLATE ────────────────────────────────────────────────────────
  Widget _buildTemplateToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isTemplate = !_isTemplate),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isTemplate
                ? Colors.purpleAccent.withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _isTemplate
                    ? Colors.purpleAccent.withOpacity(0.5)
                    : Colors.white10),
          ),
          child: Row(children: [
            Icon(
              _isTemplate
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline,
              color:
                  _isTemplate ? Colors.purpleAccent : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTemplate
                        ? 'Modo Template ativado'
                        : 'Salvar como template',
                    style: TextStyle(
                        color: _isTemplate
                            ? Colors.purpleAccent
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  Text(
                    _isTemplate
                        ? 'Sem data — use como base para treinos futuros'
                        : 'Cria um modelo reutilizável sem data',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isTemplate,
              onChanged: (v) => setState(() => _isTemplate = v),
              activeColor: Colors.purpleAccent,
            ),
          ]),
        ),
      ),
    );
  }

  // ── NOTAS ──────────────────────────────────────────────────────────────────
  Widget _buildNotasField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('NOTAS DO TREINO'),
        const SizedBox(height: 8),
        TextField(
          controller: _notasController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            hintText:
                'Ex: joelho doendo, dormi mal, PR no supino... (opcional)',
            hintStyle:
                const TextStyle(color: Colors.white54, fontSize: 13),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.notes_rounded,
                  color: Colors.white38, size: 20),
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Colors.orangeAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // ── CARD DO EXERCÍCIO ──────────────────────────────────────────────────────
  Widget _buildCardExercicio(int exIdx) {
    final nomeCtrl =
        _exercicios[exIdx]['nome'] as TextEditingController;

    return Container(
      key: ValueKey('ex_$exIdx'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 8, 0),
            child: Row(children: [
              const Icon(Icons.drag_indicator,
                  color: Colors.white24, size: 20),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${exIdx + 1}',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue value) {
                    if (value.text.isEmpty) return const [];
                    final query = normalizarNome(value.text);
                    return _exerciciosConhecidos.where((nome) {
                      final n = normalizarNome(nome);
                      return n.contains(query) ||
                          levenshtein(n, query) <= 2;
                    });
                  },
                  displayStringForOption: (opt) => opt,
                  fieldViewBuilder:
                      (ctx, ctrl, focusNode, onSubmitted) {
                    ctrl.text = nomeCtrl.text;
                    ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: ctrl.text.length));
                    ctrl.addListener(() => nomeCtrl.text = ctrl.text);
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Nome do Exercício',
                        hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 4),
                      ),
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 8,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxHeight: 200, maxWidth: 280),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const Divider(
                                color: Colors.white10, height: 1),
                            itemBuilder: (ctx, i) {
                              final opt = options.elementAt(i);
                              return InkWell(
                                onTap: () => onSelected(opt),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    const Icon(Icons.history,
                                        color: Colors.white38,
                                        size: 14),
                                    const SizedBox(width: 8),
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
                  onSelected: (String selected) =>
                      setState(() => nomeCtrl.text = selected),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () => _removerExercicio(exIdx),
              ),
            ]),
          ),

          const Divider(color: Colors.white10, height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: const [
              SizedBox(width: 38),
              Expanded(
                  child: Text('CARGA (kg)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              SizedBox(width: 10),
              Expanded(
                  child: Text('REPS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              SizedBox(width: 10),
              SizedBox(
                  width: 90,
                  child: Text('DIFICULDADE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              SizedBox(width: 36),
            ]),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exercicios[exIdx]['series'].length,
              itemBuilder: (context, sIdx) {
                final serie = _exercicios[exIdx]['series'][sIdx];
                final dif = serie['dificuldade'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text('${sIdx + 1}',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildMiniField(
                            serie['carga'] as TextEditingController,
                            '0')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildMiniField(
                            serie['reps'] as TextEditingController,
                            '0')),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: kDificuldades.map((d) {
                          final val = d['valor'] as String;
                          final label = d['label'] as String;
                          final cor = d['cor'] as Color;
                          final ativo = dif == val;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _setDificuldade(exIdx, sIdx, val),
                              customBorder: const CircleBorder(),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: ativo
                                      ? cor.withOpacity(0.25)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          ativo ? cor : Colors.white12,
                                      width: ativo ? 1.5 : 1),
                                ),
                                child: Center(
                                  child: Text(label,
                                      style: TextStyle(
                                          color: ativo
                                              ? cor
                                              : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: ativo
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white24, size: 18),
                      onPressed: () => _removerSerie(exIdx, sIdx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                  ]),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: TextButton.icon(
              onPressed: () => _adicionarSerie(exIdx),
              icon: const Icon(Icons.add_circle_outline,
                  size: 16, color: Colors.white38),
              label: const Text('nova série',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── AUTOCOMPLETE NOME DO TREINO ───────────────────────────────────────────
  Widget _buildNomeTreinoAutocomplete() {
    final hint = _isTemplate
        ? 'Ex: Treino A - Peito (Template)'
        : 'Ex: Treino A - Peito e Tríceps';

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _nomeTreinoController.text),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const [];
        final query = value.text.toLowerCase();
        return _nomesTreinosConhecidos.where((nome) =>
            nome.toLowerCase().contains(query));
      },
      displayStringForOption: (opt) => opt,
      onSelected: (String selected) {
        _nomeTreinoController.text = selected;
      },
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
        // Sincroniza o controller interno com o real
        if (ctrl.text != _nomeTreinoController.text) {
          ctrl.text = _nomeTreinoController.text;
          ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: ctrl.text.length));
        }
        ctrl.addListener(() => _nomeTreinoController.text = ctrl.text);

        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            hintText: hint,
            hintStyle:
                const TextStyle(color: Colors.white54, fontSize: 14),
            prefixIcon: const Icon(Icons.edit_note_rounded,
                color: Colors.orangeAccent, size: 20),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Colors.orangeAccent, width: 1.5)),
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
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.history_rounded,
                            color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(opt,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMusculosSeletor() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _abrirSeletorMusculos,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.orangeAccent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _musculosSelecionados.isEmpty
                  ? const Text('Toque para selecionar os músculos',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _musculosSelecionados.map((nome) {
                        final m = kMusculos.firstWhere(
                            (km) => km['nome'] == nome,
                            orElse: () =>
                                {'cor': Colors.orangeAccent});
                        final cor = m['cor'] as Color;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: cor.withOpacity(0.4)),
                          ),
                          child: Text(nome,
                              style: TextStyle(
                                  color: cor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white24),
          ]),
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selecionarData(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month,
                  color: Colors.orangeAccent, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DATA DO TREINO',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy').format(_dataSelecionada),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white24),
          ]),
        ),
      ),
    );
  }

  Widget _buildMiniField(
      TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.white12, fontSize: 14),
        filled: true,
        fillColor: Colors.black26,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Colors.orangeAccent, width: 1.5)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3));

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintText: label,
        hintStyle:
            const TextStyle(color: Colors.white54, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.orangeAccent, size: 20),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Colors.orangeAccent, width: 1.5)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: _salvando
              ? LinearGradient(colors: [
                  Colors.grey.shade700,
                  Colors.grey.shade600
                ])
              : _isTemplate
                  ? const LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)])
                  : const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFFF5722)]),
          boxShadow: _salvando
              ? null
              : [
                  BoxShadow(
                      color: (_isTemplate
                              ? const Color(0xFF9C27B0)
                              : const Color(0xFFFF5722))
                          .withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: _salvando ? null : _salvarTreino,
          child: _salvando
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('SALVANDO...',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ])
              : Text(
                  _isTemplate
                      ? 'SALVAR TEMPLATE'
                      : widget.modoEdicao
                          ? 'SALVAR ALTERAÇÕES'
                          : 'SALVAR TREINO',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5)),
        ),
      ),
    );
  }
}