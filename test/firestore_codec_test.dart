import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_codec.dart';

/// JSON-safe copy of a codec map; DateTimes become {"__ts": iso} for the
/// seed script to turn back into Firestore timestamps.
dynamic _jsonable(dynamic v) {
  if (v is DateTime) return {'__ts': v.toUtc().toIso8601String()};
  if (v is Map) return {for (final e in v.entries) e.key: _jsonable(e.value)};
  if (v is List) return [for (final e in v) _jsonable(e)];
  return v;
}

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

void main() {
  group('codec round trips', () {
    test('vendors', () {
      for (final v in MockData.vendors) {
        final back = Codec.vendorFromMap(v.id, Codec.vendorToMap(v));
        expect(Codec.vendorToMap(back), Codec.vendorToMap(v));
        expect(back.active, v.active);
      }
    });

    test('drivers', () {
      for (final d in MockData.drivers) {
        expect(Codec.driverToMap(Codec.driverFromMap(d.id, Codec.driverToMap(d))), Codec.driverToMap(d));
      }
    });

    test('buses keep their weekly availability to the minute and an unassigned driver', () {
      for (final b in MockData.buses) {
        final back = Codec.busFromMap(b.id, Codec.busToMap(b));
        expect(Codec.busToMap(back), Codec.busToMap(b));
        expect(back.driverId, b.driverId);
        expect(back.weeklyAvailability.length, 7);
      }
      final unassigned = MockData.buses.firstWhere((b) => b.driverId == null);
      expect(Codec.busFromMap(unassigned.id, Codec.busToMap(unassigned)).driverId, isNull);
    });

    test('blackouts keep their dates', () {
      for (final e in MockData.blackouts) {
        final back = Codec.blackoutFromMap(e.id, Codec.blackoutToMap(e));
        expect(back.from, e.from);
        expect(back.to, e.to);
        expect(back.isMaintenance, e.isMaintenance);
      }
    });

    test('locations, templates, config, packages and faqs', () {
      for (final l in MockData.locations) {
        expect(Codec.locationToMap(Codec.locationFromMap(l.id, Codec.locationToMap(l))), Codec.locationToMap(l));
      }
      for (final t in MockData.templates) {
        expect(Codec.templateToMap(Codec.templateFromMap(t.id, Codec.templateToMap(t))), Codec.templateToMap(t));
      }
      const config = AppConfig(holdMinutes: 20, supportPhone: '+91 1', capacities: [10, 20]);
      final backConfig = Codec.configFromMap(Codec.configToMap(config));
      expect(backConfig.holdMinutes, 20);
      expect(backConfig.capacities, [10, 20]);
      for (final p in MockData.packageLocations) {
        expect(Codec.packageToMap(Codec.packageFromMap(Codec.packageToMap(p))), Codec.packageToMap(p));
      }
      for (final f in MockData.faqs) {
        expect(Codec.faqFromMap(Codec.faqToMap(f)).question, f.question);
      }
    });

    test('a missing config field falls back to the default', () {
      expect(Codec.configFromMap({'holdMinutes': 45}).defaultAdvancePercent, const AppConfig().defaultAdvancePercent);
    });
  });

  // Regenerates tools/seed/seed.json from MockData:
  //   EXPORT_SEED=1 flutter test test/firestore_codec_test.dart
  test('export the starting data for Firestore', () {
    if (Platform.environment['EXPORT_SEED'] != '1') return;
    final stamp = {'updatedBy': 'system:seed', 'updatedAt': MockData.now};
    final seed = <String, dynamic>{
      'vendors': {for (final v in MockData.vendors) v.id: {...Codec.vendorToMap(v), ...stamp}},
      'drivers': {for (final d in MockData.drivers) d.id: {...Codec.driverToMap(d), ...stamp}},
      'buses': {for (final b in MockData.buses) b.id: {...Codec.busToMap(b), ...stamp}},
      'busAdmin': {
        for (final b in MockData.buses)
          if (b.gpsLink != null) b.id: {'gpsLink': b.gpsLink, ...stamp},
      },
      'locations': {for (final l in MockData.locations) l.id: {...Codec.locationToMap(l), ...stamp}},
      'blackouts': {for (final e in MockData.blackouts) e.id: {...Codec.blackoutToMap(e), ...stamp}},
      'templates': {for (final t in MockData.templates) t.id: {...Codec.templateToMap(t), ...stamp}},
      'packages': {
        for (var i = 0; i < MockData.packageLocations.length; i++)
          _slug(MockData.packageLocations[i].city): {
            ...Codec.packageToMap(MockData.packageLocations[i], order: i),
            ...stamp,
          },
      },
      'faqs': {
        for (var i = 0; i < MockData.faqs.length; i++)
          'faq-${(i + 1).toString().padLeft(2, '0')}': {...Codec.faqToMap(MockData.faqs[i], order: i), ...stamp},
      },
      'config': {'app': {...Codec.configToMap(const AppConfig()), ...stamp}},
    };
    File('tools/seed/seed.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(_jsonable(seed))}\n');
  });
}
