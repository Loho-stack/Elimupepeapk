import 'package:flutter/material.dart';

import '../../data/models/msafara_journey.dart';

/// Kenya's bounds in degrees. Towns are plotted from their latitude and longitude over this box, so
/// the map needs no outline asset.
abstract final class KenyaBounds {
  static const double south = -4.7;
  static const double north = 5.0;
  static const double west = 33.9;
  static const double east = 41.9;

  /// Width over height of the box (one degree is about the same distance both ways near the equator).
  static const double aspect = (east - west) / (north - south);

  /// The point of [lat], [lng] inside a box of [size].
  static Offset project(double lat, double lng, Size size) => Offset(
        (lng - west) / (east - west) * size.width,
        (north - lat) / (north - south) * size.height,
      );
}

/// Colours the painter needs, taken from the Clay palette by the widget.
class JourneyMapColors {
  const JourneyMapColors({
    required this.land,
    required this.grid,
    required this.route,
    required this.ahead,
    required this.visited,
    required this.missed,
    required this.today,
    required this.halo,
  });

  final Color land;
  final Color grid;
  final Color route;
  final Color ahead;
  final Color visited;
  final Color missed;
  final Color today;
  final Color halo;
}

/// Draws the towns that have coordinates, the route through them in day order, and the current town
/// bigger with a halo. State is not told by colour alone: a visited town is a filled dot, a missed one
/// a ring, one ahead a small dot, today a large dot inside a ring.
class JourneyMapPainter extends CustomPainter {
  JourneyMapPainter({required this.towns, required this.colors});

  /// Only towns with coordinates, in day order.
  final List<JourneyTown> towns;
  final JourneyMapColors colors;

  static const double hitRadius = 24;

  /// The town nearest to [point] within [hitRadius] logical pixels, or null.
  static JourneyTown? nearest(List<JourneyTown> towns, Size size, Offset point) {
    JourneyTown? best;
    var bestDistance = hitRadius;
    for (final t in towns) {
      if (!t.onMap) continue;
      final d = (KenyaBounds.project(t.lat!, t.lng!, size) - point).distance;
      if (d <= bestDistance) {
        bestDistance = d;
        best = t;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = colors.land;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)), land);

    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var lat = -4.0; lat <= 4.0; lat += 2) {
      final y = KenyaBounds.project(lat, KenyaBounds.west, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var lng = 34.0; lng <= 41.0; lng += 2) {
      final x = KenyaBounds.project(0, lng, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final points = [for (final t in towns) KenyaBounds.project(t.lat!, t.lng!, size)];

    // The route: solid up to the current town, thin and faint beyond it.
    for (var i = 1; i < towns.length; i++) {
      final travelled = towns[i].reached;
      final paint = Paint()
        ..color = travelled ? colors.route : colors.ahead
        ..strokeWidth = travelled ? 3 : 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(points[i - 1], points[i], paint);
    }

    for (var i = 0; i < towns.length; i++) {
      final t = towns[i];
      final p = points[i];
      switch (t.state) {
        case 'visited':
          canvas.drawCircle(p, 5, Paint()..color = colors.visited);
        case 'passed':
          canvas.drawCircle(
            p,
            5,
            Paint()
              ..color = colors.missed
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case 'today':
          break;
        default:
          canvas.drawCircle(p, 3, Paint()..color = colors.ahead);
      }
    }

    // Today last, so nothing covers it.
    for (var i = 0; i < towns.length; i++) {
      if (!(towns[i].current || towns[i].state == 'today')) continue;
      final p = points[i];
      canvas.drawCircle(p, 16, Paint()..color = colors.halo);
      canvas.drawCircle(p, 9, Paint()..color = colors.today);
      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = colors.visited
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(JourneyMapPainter old) => old.towns != towns || old.colors != colors;
}
