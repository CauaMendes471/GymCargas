/// Funções utilitárias de manipulação e comparação de strings.
///
/// Extraídas de novo_treino.dart e evolucao.dart, onde existiam cópias
/// locais idênticas (_normalizarNome/_norm e _levenshtein).

/// Normaliza um nome para comparação: remove espaços nas pontas,
/// converte para minúsculas e colapsa espaços internos múltiplos em um só.
///
/// Útil para comparar nomes de exercícios digitados de formas ligeiramente
/// diferentes (ex.: "Supino Reto", "supino  reto", " Supino reto ").
String normalizarNome(String nome) =>
    nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Calcula a distância de Levenshtein entre duas strings [a] e [b]:
/// o número mínimo de inserções, remoções ou substituições de caractere
/// necessárias para transformar [a] em [b].
///
/// Usada para sugerir/agrupar nomes de exercícios parecidos mesmo quando
/// há pequenos erros de digitação.
int levenshtein(String a, String b) {
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
