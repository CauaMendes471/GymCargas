import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ── MÚSCULOS DISPONÍVEIS ──────────────────────────────────────────────────────
const List<Map<String, dynamic>> kMusculos = [
  {'nome': 'Peito',      'icon': '🫀', 'cor': Color(0xFFE53935)},
  {'nome': 'Costas',     'icon': '🔙', 'cor': Color(0xFF8E24AA)},
  {'nome': 'Ombro',      'icon': '💪', 'cor': Color(0xFF1E88E5)},
  {'nome': 'Bíceps',     'icon': '💪', 'cor': Color(0xFF00ACC1)},
  {'nome': 'Tríceps',    'icon': '💪', 'cor': Color(0xFF43A047)},
  {'nome': 'Pernas',     'icon': '🦵', 'cor': Color(0xFFFB8C00)},
  {'nome': 'Glúteos',    'icon': '🍑', 'cor': Color(0xFFD81B60)},
  {'nome': 'Abdômen',    'icon': '🧱', 'cor': Color(0xFF6D4C41)},
  {'nome': 'Panturrilha','icon': '🦶', 'cor': Color(0xFF00897B)},
  {'nome': 'Antebraço',  'icon': '💪', 'cor': Color(0xFF546E7A)},
  {'nome': 'Cardio',     'icon': '❤️', 'cor': Color(0xFFE53935)},
  {'nome': 'Full Body',  'icon': '🏋️', 'cor': Color(0xFFFF8F00)},
];

class NovoTreinoPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? dadosIniciais;

  const NovoTreinoPage({super.key, this.docId, this.dadosIniciais});

  bool get modoEdicao => docId != null;

  @override
  State<NovoTreinoPage> createState() => _NovoTreinoPageState();
}

class _NovoTreinoPageState extends State<NovoTreinoPage> {
  final TextEditingController _nomeTreinoController = TextEditingController();
  DateTime _dataSelecionada = DateTime.now();
  final List<Map<String, dynamic>> _exercicios = [];
  bool _salvando = false;
  bool _favorito = false;
  final Set<String> _musculosSelecionados = {};

  @override
  void initState() {
    super.initState();
    if (widget.modoEdicao && widget.dadosIniciais != null) {
      final dados = widget.dadosIniciais!;
      _nomeTreinoController.text = dados['nome_treino'] ?? '';
      final ts = dados['data_treino'];
      if (ts is Timestamp) _dataSelecionada = ts.toDate();
      _favorito = dados['favorito'] == true;
      final musculos = dados['musculos'] as List? ?? [];
      _musculosSelecionados.addAll(musculos.cast<String>());
      final exs = dados['exercicios'] as List? ?? [];
      for (final ex in exs) {
        final series = (ex['series'] as List? ?? []).map((s) => {
              'carga': TextEditingController(text: s['carga'] ?? ''),
              'reps': TextEditingController(text: s['reps'] ?? ''),
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

  @override
  void dispose() {
    _nomeTreinoController.dispose();
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
        _exercicios.any((ex) =>
            (ex['nome'] as TextEditingController).text.isNotEmpty);
    if (!temConteudo) return true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Descartar treino?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Você tem dados não salvos. Quer sair mesmo assim?",
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Continuar editando",
                style: TextStyle(color: Colors.orangeAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Descartar",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? escolhida = await showDatePicker(
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
    if (escolhida != null && escolhida != _dataSelecionada) {
      setState(() => _dataSelecionada = escolhida);
    }
  }

  void _abrirSeletorMusculos() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text("GRUPOS MUSCULARES",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              const Text("Selecione todos que se aplicam",
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kMusculos.map((m) {
                  final nome = m['nome'] as String;
                  final cor = m['cor'] as Color;
                  final icon = m['icon'] as String;
                  final selecionado = _musculosSelecionados.contains(nome);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        setState(() {
                          if (selecionado) {
                            _musculosSelecionados.remove(nome);
                          } else {
                            _musculosSelecionados.add(nome);
                          }
                        });
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selecionado
                            ? cor.withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selecionado ? cor : Colors.white.withOpacity(0.1),
                          width: selecionado ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(nome,
                              style: TextStyle(
                                  color: selecionado ? cor : Colors.white60,
                                  fontSize: 13,
                                  fontWeight: selecionado
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          if (selecionado) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle, color: cor, size: 14),
                          ],
                        ],
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
                        ? "PULAR"
                        : "CONFIRMAR (${_musculosSelecionados.length})",
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
        const SnackBar(content: Text("Dê um nome ao seu treino!")),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> treinoData = {
        "userId": user?.uid ?? "anonimo",
        "nome_treino": _nomeTreinoController.text.trim(),
        "data_treino": Timestamp.fromDate(_dataSelecionada),
        "musculos": _musculosSelecionados.toList(),
        "favorito": _favorito,
        "exercicios": _exercicios.map((ex) {
          return {
            "nome": (ex['nome'] as TextEditingController).text.trim(),
            "series": (ex['series'] as List).map((s) => {
                  "carga": (s['carga'] as TextEditingController).text,
                  "reps": (s['reps'] as TextEditingController).text,
                }).toList(),
          };
        }).toList(),
      };
      if (widget.modoEdicao) {
        await FirebaseFirestore.instance
            .collection('treinos')
            .doc(widget.docId)
            .update(treinoData);
      } else {
        treinoData["data_criacao"] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('treinos').add(treinoData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(widget.modoEdicao
                ? "Treino atualizado!"
                : "Treino salvo com sucesso!"),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
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
          {'carga': TextEditingController(), 'reps': TextEditingController()}
        ],
      });
    });
  }

  void _adicionarSerie(int i) {
    setState(() {
      _exercicios[i]['series'].add({
        'carga': TextEditingController(),
        'reps': TextEditingController(),
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

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            widget.modoEdicao ? "EDITAR TREINO" : "NOVO TREINO",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.orangeAccent),
            onPressed: () async {
              final pode = await _confirmarSaida();
              if (pode && mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _favorito ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _favorito ? Colors.amber : Colors.white38,
                size: 26,
              ),
              onPressed: () => setState(() => _favorito = !_favorito),
              tooltip: _favorito ? "Remover dos favoritos" : "Favoritar",
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _salvando ? null : _salvarTreino,
                child: _salvando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.orangeAccent, strokeWidth: 2))
                    : const Text("SALVAR",
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
              _buildSectionTitle("INFORMAÇÕES DO TREINO"),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nomeTreinoController,
                label: "Ex: Treino A - Peito e Tríceps",
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 12),
              _buildDatePickerField(),
              const SizedBox(height: 12),
              _buildMusculosSeletor(),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("EXERCÍCIOS (${_exercicios.length})"),
                  TextButton.icon(
                    onPressed: _adicionarExercicio,
                    icon: const Icon(Icons.add,
                        color: Colors.orangeAccent, size: 16),
                    label: const Text("ADICIONAR",
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercicios.length,
                itemBuilder: (context, index) => _buildCardExercicio(index),
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

  Widget _buildMusculosSeletor() {
    return GestureDetector(
      onTap: _abrirSeletorMusculos,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text("💪", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _musculosSelecionados.isEmpty
                  ? const Text("Toque para selecionar os músculos",
                      style: TextStyle(color: Colors.white38, fontSize: 14))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _musculosSelecionados.map((nome) {
                        final m = kMusculos.firstWhere(
                            (km) => km['nome'] == nome,
                            orElse: () =>
                                {'cor': Colors.orangeAccent, 'icon': '💪'});
                        final cor = m['cor'] as Color;
                        final icon = m['icon'] as String;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(icon,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(nome,
                                  style: TextStyle(
                                      color: cor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () => _selecionarData(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
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
                const Text("DATA DO TREINO",
                    style: TextStyle(
                        color: Colors.white38,
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
            const Icon(Icons.keyboard_arrow_down, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildCardExercicio(int exIdx) {
    return Container(
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
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
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
                  child: TextField(
                    controller: _exercicios[exIdx]['nome'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: "Nome do Exercício",
                      hintStyle: TextStyle(
                          color: Colors.white24,
                          fontSize: 14,
                          fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: () => _removerExercicio(exIdx),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                SizedBox(width: 28),
                SizedBox(width: 10),
                Expanded(
                    child: Text("CARGA (kg)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                Expanded(
                    child: Text("REPETIÇÕES",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
                SizedBox(width: 40),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exercicios[exIdx]['series'].length,
              itemBuilder: (context, sIdx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text("${sIdx + 1}",
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildMiniField(
                              _exercicios[exIdx]['series'][sIdx]['carga'],
                              "0")),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildMiniField(
                              _exercicios[exIdx]['series'][sIdx]['reps'],
                              "0")),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white24, size: 18),
                        onPressed: () => _removerSerie(exIdx, sIdx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
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
              label: const Text("nova série",
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white12, fontSize: 14),
        filled: true,
        fillColor: Colors.black26,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Colors.orangeAccent, width: 1.5)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3));
  }

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
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.orangeAccent, size: 20),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Colors.orangeAccent, width: 1.5)),
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
              ? LinearGradient(
                  colors: [Colors.grey.shade700, Colors.grey.shade600])
              : const LinearGradient(
                  colors: [Color(0xFFFF8F00), Color(0xFFFF5722)]),
          boxShadow: _salvando
              ? null
              : [
                  BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.35),
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
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text("SALVANDO...",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ])
              : Text(
                  widget.modoEdicao ? "SALVAR ALTERAÇÕES" : "SALVAR TREINO",
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
