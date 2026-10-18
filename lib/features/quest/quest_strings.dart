/// UI copy of Elimu Quest, English and Kiswahili. Taken from the web lang files
/// (`Modules/Msafara/Resources/lang/{en,sw}/msafara.php`, keys kept). The terms text is NOT here:
/// it is DP-approved and is rendered only from `GET /msafara/terms`.
///
/// Strings marked "app" have no web key (the web page is English only or has no such control); they
/// are the app's own and need a copy review before the Kiswahili ones ship.
class QuestStrings {
  const QuestStrings._(this.lang, this._m);

  final String lang;
  final Map<String, String> _m;

  static const supported = ['en', 'sw'];

  static QuestStrings of(String lang) => lang == 'sw' ? sw : en;

  /// The first supported language of the device, else English.
  static String fromLocale(String? languageCode) => languageCode == 'sw' ? 'sw' : 'en';

  static const en = QuestStrings._('en', _en);
  static const sw = QuestStrings._('sw', _sw);

  /// Every key, for the parity test.
  static Iterable<String> get keys => _en.keys;
  Iterable<String> get ownKeys => _m.keys;

  /// The string for [key] with `:name` placeholders replaced from [args].
  String t(String key, [Map<String, Object> args = const {}]) {
    var s = _m[key] ?? _en[key] ?? key;
    args.forEach((k, v) => s = s.replaceAll(':$k', '$v'));
    return s;
  }

  /// The "n learners have reserved a seat" line: one form for 1, another for the rest.
  String seats(int n) => t(n == 1 ? 'boarding.count_one' : 'boarding.count_many', {'n': _thousands(n)});

  static String _thousands(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  static const _en = <String, String>{
    'title': 'Elimu Quest',
    'back': 'Back',
    'states.offline': 'You are offline. Your answer will not be saved. Check your connection, then try again.',
    'states.loading': 'Loading',
    'states.retry': 'Try again',
    'boarding.kicker': 'Now boarding',
    'boarding.title': 'The matatu is at the stage',
    'boarding.scene': 'The Elimu Quest matatu at the stage, loading passengers',
    'boarding.days': 'Days',
    'boarding.hours': 'Hours',
    'boarding.minutes': 'Minutes',
    'boarding.seconds': 'Seconds',
    'boarding.leaves': 'Leaves :date at midnight',
    'boarding.starting': 'Twende! The journey is starting...',
    'boarding.ticket_kicker': 'Your ticket',
    'boarding.reserve': 'Reserve your seat',
    'boarding.reserve_text':
        'Read the Elimu Quest terms with your parent or guardian and say yes. It takes a minute, and your seat is kept for the whole journey.',
    'boarding.profile_title': 'One more step',
    'boarding.profile_text': 'Tell us your grade and your county to finish your ticket.',
    'boarding.profile': 'Choose grade and county',
    'boarding.reserved': 'Seat reserved',
    'boarding.reserved_text': 'Your seat is waiting. Come back on :date to unlock your first town.',
    'boarding.departure': 'Departure',
    'boarding.count_one': ':n learner has reserved a seat',
    'boarding.count_many': ':n learners have reserved a seat',
    'boarding.countdown_label': ':d days, :h hours and :m minutes to go',
    // app: the web profile page is English only.
    'profile.title': 'Tell us about you',
    'profile.grade': 'Your grade',
    'profile.county': 'Your county',
    'profile.choose': 'Choose',
    'profile.start': 'Start my journey',
    // app
    'terms.language': 'Language',
    'terms.parent_note_title': 'Read this with your parent or guardian',
    'terms.accept_needed': 'Tick both boxes to continue.',
    'closed.title': 'Elimu Quest is not open yet',
    'closed.text': 'There is nothing to show here for now. Check again soon.',
    'gate.checking': 'Opening Elimu Quest',
  };

  static const _sw = <String, String>{
    'title': 'Elimu Quest',
    'back': 'Rudi',
    'states.offline': 'Huna mtandao. Jibu lako halitahifadhiwa. Angalia mtandao wako, kisha jaribu tena.',
    'states.loading': 'Inapakia',
    'states.retry': 'Jaribu tena',
    'boarding.kicker': 'Abiria wanapanda',
    'boarding.title': 'Matatu iko kituoni',
    'boarding.scene': 'Matatu ya Elimu Quest kituoni, ikipakia abiria',
    'boarding.days': 'Siku',
    'boarding.hours': 'Saa',
    'boarding.minutes': 'Dakika',
    'boarding.seconds': 'Sekunde',
    'boarding.leaves': 'Inaondoka :date saa sita usiku',
    'boarding.starting': 'Twende! Safari inaanza...',
    'boarding.ticket_kicker': 'Tiketi yako',
    'boarding.reserve': 'Hifadhi kiti chako',
    'boarding.reserve_text':
        'Soma masharti ya Elimu Quest pamoja na mzazi au mlezi wako kisha mkubali. Ni dakika moja tu, na kiti chako kinahifadhiwa kwa safari nzima.',
    'boarding.profile_title': 'Hatua moja zaidi',
    'boarding.profile_text': 'Tuambie darasa lako na kaunti yako ili kukamilisha tiketi yako.',
    'boarding.profile': 'Chagua darasa na kaunti',
    'boarding.reserved': 'Kiti kimehifadhiwa',
    'boarding.reserved_text': 'Kiti chako kinakusubiri. Rudi :date ufungue mji wako wa kwanza.',
    'boarding.departure': 'Kuondoka',
    'boarding.count_one': 'Mwanafunzi :n amehifadhi kiti',
    'boarding.count_many': 'Wanafunzi :n wamehifadhi kiti',
    'boarding.countdown_label': 'Siku :d, saa :h na dakika :m zimebaki',
    'profile.title': 'Tuambie kuhusu wewe',
    'profile.grade': 'Darasa lako',
    'profile.county': 'Kaunti yako',
    'profile.choose': 'Chagua',
    'profile.start': 'Anza safari yangu',
    'terms.language': 'Lugha',
    'terms.parent_note_title': 'Soma hii pamoja na mzazi au mlezi wako',
    'terms.accept_needed': 'Weka alama kwenye visanduku vyote viwili ili uendelee.',
    'closed.title': 'Elimu Quest bado haijafunguliwa',
    'closed.text': 'Hakuna cha kuonyesha hapa kwa sasa. Angalia tena hivi karibuni.',
    'gate.checking': 'Inafungua Elimu Quest',
  };
}
