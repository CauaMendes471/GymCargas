import 'package:flutter/material.dart';

/// Constantes compartilhadas do app Gym Cargas.
///
/// Centraliza listas e mapas de músculos, dificuldades e cores que antes
/// estavam duplicados em vários arquivos (novo_treino.dart, dashboard.dart,
/// treino_detalhe.dart, templates_page.dart, criar_treino_page.dart).

// ── MÚSCULOS ────────────────────────────────────────────────────────────────
/// Lista de grupos musculares com nome e cor associada.
/// Usada em seletores (chips) onde nome e cor precisam vir juntos.
const List<Map<String, dynamic>> kMusculos = [
  {'nome': 'Peito', 'cor': Color(0xFFE53935)},
  {'nome': 'Costas', 'cor': Color(0xFF8E24AA)},
  {'nome': 'Ombro', 'cor': Color(0xFF1E88E5)},
  {'nome': 'Bíceps', 'cor': Color(0xFF00ACC1)},
  {'nome': 'Tríceps', 'cor': Color(0xFF43A047)},
  {'nome': 'Pernas', 'cor': Color(0xFFFB8C00)},
  {'nome': 'Glúteos', 'cor': Color(0xFFD81B60)},
  {'nome': 'Abdômen', 'cor': Color(0xFF6D4C41)},
  {'nome': 'Panturrilha', 'cor': Color(0xFF00897B)},
  {'nome': 'Antebraço', 'cor': Color(0xFF546E7A)},
  {'nome': 'Cardio', 'cor': Color(0xFFE53935)},
  {'nome': 'Full Body', 'cor': Color(0xFFFF8F00)},
];

/// Mesmo mapeamento de [kMusculos], mas em formato de lookup rápido
/// (nome do músculo → cor). Usado em cards, chips e badges onde só a cor
/// é necessária a partir do nome.
const Map<String, Color> kMusculoCores = {
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

// ── DIFICULDADE ─────────────────────────────────────────────────────────────
/// Lista de dificuldades com valor interno, label curto (usado em chips
/// compactos, ex.: seletor de dificuldade por série) e cor associada.
const List<Map<String, dynamic>> kDificuldades = [
  {'valor': 'facil', 'label': 'F', 'cor': Color(0xFF43A047)},
  {'valor': 'medio', 'label': 'M', 'cor': Color(0xFFFB8C00)},
  {'valor': 'dificil', 'label': 'D', 'cor': Color(0xFFE53935)},
];

/// Label por extenso de cada dificuldade (valor interno → texto completo).
/// Usado em telas de detalhe, onde o espaço permite o nome completo.
const Map<String, String> kDificuldadeLabel = {
  'facil': 'Fácil',
  'medio': 'Médio',
  'dificil': 'Difícil',
};

/// Cor de cada dificuldade (valor interno → cor). Equivale ao campo 'cor'
/// de [kDificuldades], disponibilizado também como mapa de lookup direto.
const Map<String, Color> kDificuldadeCor = {
  'facil': Color(0xFF43A047),
  'medio': Color(0xFFFB8C00),
  'dificil': Color(0xFFE53935),
};
