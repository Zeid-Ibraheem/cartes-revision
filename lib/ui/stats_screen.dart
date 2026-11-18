import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/stats.dart';
import 'common.dart';
import 'theme.dart';

/// Les statistiques de tout, d'un dossier ou d'un paquet : aujourd'hui,
/// réussite, activité jour par jour, progression et cartes à venir.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.store, required this.scope});

  final AppStore store;
  final StudyScope scope;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _periods = {7: '7 jours', 30: '30 jours', 365: '1 an'};
  int _period = 30;
  StatsReport? _report;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _report = null;
      _error = null;
    });
    try {
      final report = await widget.store.stats(widget.scope, periodDays: _period);
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistiques'),
            Text(
              widget.scope.label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _error != null
          ? Center(child: Text('Erreur : ${errorMessage(_error!)}'))
          : report == null
              ? const Center(child: CircularProgressIndicator())
              : _content(context, report),
    );
  }

  Widget _content(BuildContext context, StatsReport r) {
    final scheme = Theme.of(context).colorScheme;
    final signal = Signal.of(context);
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final todayDay = r.days.last;
    final activeDays = r.days.where((d) => d.answers > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final entry in _periods.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {_period},
          onSelectionChanged: (value) {
            _period = value.first;
            _load();
          },
        ),
        const SizedBox(height: 20),

        // -------------------------------------------------- Aujourd'hui
        const Caption('Aujourd’hui'),
        Panel(
          child: Row(
            children: [
              _Big('${r.today.answers}', 'cartes'),
              _Big(formatStudyTime(r.today.durationMs), 'de révision'),
              _Big(
                formatPercent(todayDay.answers == 0
                    ? null
                    : todayDay.passed / todayDay.answers),
                'réussite',
              ),
              _Big('${r.streak}', r.streak > 1 ? 'jours d’affilée' : 'jour d’affilée'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // -------------------------------------------------- Réussite
        Caption('Réussite · ${_periods[_period]}'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RateRow(
                label: 'Cartes apprises',
                rate: r.reviewRate,
                target: r.desiredRetention,
                good: signal.review,
                bad: signal.hard,
              ),
              const SizedBox(height: 14),
              _RateRow(
                label: 'Nouvelles et en apprentissage',
                rate: r.learningRate,
                good: signal.fresh,
                bad: signal.fresh,
              ),
              const SizedBox(height: 12),
              Text(
                'Une réponse est réussie si ce n’est pas « À revoir ». Pour '
                'les cartes apprises, le bon chiffre est proche de la '
                'mémorisation visée (${formatPercent(r.desiredRetention)}) : '
                'bien plus haut, tu révises trop souvent ; bien plus bas, '
                'tu oublies trop.',
                style: muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // -------------------------------------------------- Activité
        Caption('Révisions par jour · ${_periods[_period]}'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarChart(
                bars: _groupDays(r.days, _period > 60 ? 7 : 1),
                firstLabel: _period == 7 ? 'il y a 6 j' : 'il y a ${_periods[_period]}',
                lastLabel: 'aujourd’hui',
              ),
              const SizedBox(height: 10),
              _Legend([
                (signal.review, 'réussies'),
                (signal.learning, 'à revoir'),
              ]),
              const SizedBox(height: 14),
              _Line('Réponses', '${r.period.answers}'),
              _Line('Temps total', formatStudyTime(r.period.durationMs)),
              _Line('Temps moyen par carte',
                  '${r.period.secondsPerAnswer.toStringAsFixed(1).replaceAll('.', ',')} s'),
              _Line('Jours de révision', '$activeDays sur $_period'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // -------------------------------------------------- Progression
        const Caption('Progression'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StackBar(parts: [
                (r.collection.fresh, signal.fresh),
                (r.collection.learning, signal.learning),
                (r.collection.young, signal.review.withAlpha(150)),
                (r.collection.mature, signal.review),
              ]),
              const SizedBox(height: 12),
              _Line('Nouvelles (jamais vues)', '${r.collection.fresh}', color: signal.fresh),
              _Line('En apprentissage', '${r.collection.learning}', color: signal.learning),
              _Line('Apprises, moins de 21 j', '${r.collection.young}',
                  color: signal.review.withAlpha(150)),
              _Line('Mûres, 21 j et plus', '${r.collection.mature}', color: signal.review),
              const Divider(height: 24),
              _Line('Déjà vues', formatPercent(r.collection.seenRatio)),
              const SizedBox(height: 16),
              Text('Cartes nouvelles apprises (cumul) · ${_periods[_period]}',
                  style: muted),
              const SizedBox(height: 8),
              _LineChart(values: r.learnedPerDay, color: signal.fresh),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // -------------------------------------------------- À venir
        const Caption('À venir · 14 jours'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarChart(
                bars: [
                  for (final n in r.forecast) [(n.toDouble(), signal.review)],
                ],
                firstLabel: 'aujourd’hui',
                lastLabel: 'dans 13 j',
              ),
              const SizedBox(height: 14),
              _Line('Aujourd’hui', '${r.forecast.first}'),
              _Line('Demain', '${r.forecast.length > 1 ? r.forecast[1] : 0}'),
              _Line('7 prochains jours',
                  '${r.forecast.take(7).fold(0, (a, b) => a + b)}'),
            ],
          ),
        ),
      ],
    );
  }

  /// Une barre par jour, ou par semaine sur une longue période.
  List<List<(double, Color)>> _groupDays(List<DayActivity> days, int size) {
    final signal = Signal.of(context);
    final bars = <List<(double, Color)>>[];
    for (var i = 0; i < days.length; i += size) {
      final group = days.sublist(i, math.min(i + size, days.length));
      final passed = group.fold(0, (sum, d) => sum + d.passed);
      final failed = group.fold(0, (sum, d) => sum + d.failed);
      bars.add([
        (passed.toDouble(), signal.review),
        (failed.toDouble(), signal.learning),
      ]);
    }
    return bars;
  }
}

// ---------------------------------------------------------------- Morceaux

/// Un grand chiffre avec son nom dessous.
class _Big extends StatelessWidget {
  const _Big(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Une ligne « nom ……… valeur », avec une pastille de couleur facultative.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Légende : pastilles de couleur et leur sens.
class _Legend extends StatelessWidget {
  const _Legend(this.items);

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
      ],
    );
  }
}

/// Un taux de réussite : grand pourcentage et barre de progression, avec
/// l'objectif marqué si [target] est donné.
class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.rate,
    required this.good,
    required this.bad,
    this.target,
  });

  final String label;
  final SuccessRate rate;
  final double? target;
  final Color good;
  final Color bad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = rate.ratio;
    final target = this.target;
    final color = ratio == null || target == null || ratio >= target - 0.05
        ? good
        : bad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            Text(
              formatPercent(ratio),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _RatePainter(
              ratio: ratio ?? 0,
              target: target,
              color: color,
              track: scheme.surfaceContainerHighest,
              marker: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          rate.total == 0
              ? 'aucune réponse sur la période'
              : '${rate.passed} réussies sur ${rate.total}'
                  '${target == null ? '' : ' · objectif ${formatPercent(target)}'}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RatePainter extends CustomPainter {
  _RatePainter({
    required this.ratio,
    required this.target,
    required this.color,
    required this.track,
    required this.marker,
  });

  final double ratio;
  final double? target;
  final Color color;
  final Color track;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * ratio.clamp(0.0, 1.0), size.height),
          radius),
      Paint()..color = color,
    );
    final t = target;
    if (t != null) {
      final x = size.width * t;
      canvas.drawLine(Offset(x, -3), Offset(x, size.height + 3),
          Paint()
            ..color = marker
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_RatePainter old) =>
      old.ratio != ratio || old.target != target || old.color != color;
}

/// Barre horizontale découpée en parts colorées (répartition des cartes).
class _StackBar extends StatelessWidget {
  const _StackBar({required this.parts});

  final List<(int, Color)> parts;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold(0, (sum, p) => sum + p.$1);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 14,
        child: total == 0
            ? ColoredBox(color: scheme.surfaceContainerHighest)
            : Row(
                children: [
                  for (final (count, color) in parts)
                    if (count > 0)
                      Expanded(flex: count, child: ColoredBox(color: color)),
                ],
              ),
      ),
    );
  }
}

/// Histogramme : une barre par entrée, chaque barre faite de parts empilées.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.bars,
    required this.firstLabel,
    required this.lastLabel,
  });

  final List<List<(double, Color)>> bars;
  final String firstLabel;
  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = bars.fold<double>(
        0, (m, bar) => math.max(m, bar.fold<double>(0, (s, p) => s + p.$1)));
    final small = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('max ${maxValue.round()}', style: small),
        const SizedBox(height: 4),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _BarsPainter(
              bars: bars,
              maxValue: maxValue,
              axis: scheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(firstLabel, style: small), Text(lastLabel, style: small)],
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.bars, required this.maxValue, required this.axis});

  final List<List<(double, Color)>> bars;
  final double maxValue;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height),
        Paint()
          ..color = axis
          ..strokeWidth = 1);
    if (bars.isEmpty || maxValue <= 0) return;
    final slot = size.width / bars.length;
    final gap = math.min(slot * 0.25, 4.0);
    for (var i = 0; i < bars.length; i++) {
      var bottom = size.height;
      for (final (value, color) in bars[i]) {
        if (value <= 0) continue;
        final h = size.height * value / maxValue;
        canvas.drawRect(
          Rect.fromLTWH(i * slot + gap / 2, bottom - h, slot - gap, h),
          Paint()..color = color,
        );
        bottom -= h;
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.bars != bars || old.maxValue != maxValue;
}

/// Courbe simple (cumul jour après jour), avec la valeur finale.
class _LineChart extends StatelessWidget {
  const _LineChart({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = values.isEmpty ? 0 : values.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 90,
          child: CustomPaint(
            painter: _LinePainter(
                values: values, color: color, axis: scheme.outlineVariant),
          ),
        ),
        const SizedBox(height: 4),
        Text('$last carte(s) nouvelle(s) apprise(s) sur la période',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.color, required this.axis});

  final List<int> values;
  final Color color;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height),
        Paint()
          ..color = axis
          ..strokeWidth = 1);
    if (values.length < 2) return;
    final maxValue = values.reduce(math.max);
    if (maxValue == 0) return;
    final path = Path();
    final area = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - size.height * values[i] / maxValue;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      area.lineTo(x, y);
    }
    area
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withAlpha(45));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
