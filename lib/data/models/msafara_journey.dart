import '../json.dart';
import 'msafara_quests.dart';

/// One of the 92 towns of the journey.
class JourneyTown {
  const JourneyTown({
    required this.day,
    required this.planDay,
    required this.date,
    required this.town,
    required this.county,
    required this.lat,
    required this.lng,
    required this.leg,
    required this.special,
    required this.reached,
    required this.current,
    required this.state,
  });

  final int day;
  final int planDay;

  /// `YYYY-MM-DD`.
  final String date;
  final String town;
  final String? county;

  /// Null when the town has no coordinates, or when the map is off: such a town is listed only.
  final double? lat;
  final double? lng;
  final int? leg;
  final String? special;
  final bool reached;
  final bool current;

  /// `visited|passed|today|future`.
  final String state;

  bool get onMap => lat != null && lng != null;

  factory JourneyTown.fromJson(Map<String, dynamic> j) => JourneyTown(
        day: j.integer('day'),
        planDay: j.intOrNull('plan_day') ?? j.integer('day'),
        date: j.str('date'),
        town: j.str('town'),
        county: j.strOrNull('county'),
        lat: j.numberOrNull('lat'),
        lng: j.numberOrNull('lng'),
        leg: j.intOrNull('leg'),
        special: j.strOrNull('special'),
        reached: j.boolean('reached'),
        current: j.boolean('current'),
        state: j.str('state'),
      );
}

class JourneyLeg {
  const JourneyLeg({required this.no, required this.name, required this.from, required this.to});
  final int no;
  final String name;
  final int from;
  final int to;

  factory JourneyLeg.fromJson(Map<String, dynamic> j) =>
      JourneyLeg(no: j.integer('no'), name: j.str('name'), from: j.integer('from'), to: j.integer('to'));
}

/// `GET /msafara/journey`.
class Journey {
  const Journey({required this.today, required this.km, required this.towns, required this.legs});

  /// The current campaign day (may be past 92 after the run).
  final int today;
  final Km km;
  final List<JourneyTown> towns;
  final List<JourneyLeg> legs;

  List<JourneyTown> get mapped => towns.where((t) => t.onMap).toList();
  int get unmapped => towns.length - mapped.length;

  factory Journey.fromJson(Map<String, dynamic> j) => Journey(
        today: j.integer('today'),
        km: Km.fromJson(j.obj('km')),
        towns: j.list('towns', JourneyTown.fromJson),
        legs: j['legs'] == null ? const [] : j.list('legs', JourneyLeg.fromJson),
      );
}
