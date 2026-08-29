import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CustomPainters usados nos gráficos da tela de Evolução.
///
/// Extraídos de evolucao.dart (antes `_GraficoPainter` e `_VolumePainter`,
/// privados ao arquivo) para permitir reuso e manter evolucao.dart mais
/// enxuto e focado na lógica de tela.

/// Desenha o gráfico de linha de carga máxima (kg) ao longo do tempo,
/// destacando o PR (recorde pessoal) em dourado.
class GraficoCargaPainter extends CustomPainter {
  final List<Map<String, dynamic>> pontos;
  final double maxCarga, minCarga, range, alturaGrafico;

  GraficoCargaPainter({
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
          style: const TextStyle(color: Colors.white70, fontSize: 9),
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

/// Desenha o gráfico de linha de volume total (toneladas ou kg) ao longo
/// do tempo, destacando o pico de volume em dourado.
class VolumePainter extends CustomPainter {
  final List<Map<String, dynamic>> pontos;
  final double maxVol, minVol, range, alturaGrafico;
  final String unidade;
  final bool isToneladas;

  VolumePainter({
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
          style: const TextStyle(color: Colors.white70, fontSize: 9),
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
