import '../models/music_track.dart';

// Free tracks: first 10. Pro: all 50.
// Audio files live at assets/music/<id>.mp3 — add royalty-free tracks there.
class MusicLibrary {
  static const List<MusicTrack> tracks = [
    // Upbeat (15)
    MusicTrack(id: 'upbeat_01', bpm: 120, nameEn: 'Morning Hustle',       nameHi: 'मॉर्निंग हसल',    category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_01.mp3', isPro: false),
    MusicTrack(id: 'upbeat_02', bpm: 120, nameEn: 'Shop Opening',         nameHi: 'दुकान खोलना',      category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_02.mp3', isPro: false),
    MusicTrack(id: 'upbeat_03', bpm: 120, nameEn: 'Business Boost',       nameHi: 'बिज़नेस बूस्ट',    category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_03.mp3', isPro: false),
    MusicTrack(id: 'upbeat_04', bpm: 120, nameEn: 'Sale Day',             nameHi: 'सेल डे',           category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_04.mp3', isPro: false),
    MusicTrack(id: 'upbeat_05', bpm: 120, nameEn: 'New Arrivals',         nameHi: 'नए आइटम',          category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_05.mp3', isPro: false),
    MusicTrack(id: 'upbeat_06', bpm: 120, nameEn: 'Weekend Vibes',        nameHi: 'वीकेंड वाइब्स',   category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_06.mp3', isPro: true),
    MusicTrack(id: 'upbeat_07', bpm: 120, nameEn: 'Grand Opening',        nameHi: 'ग्रैंड ओपनिंग',   category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_07.mp3', isPro: true),
    MusicTrack(id: 'upbeat_08', bpm: 120, nameEn: 'Offer Alert',          nameHi: 'ऑफर अलर्ट',       category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_08.mp3', isPro: true),
    MusicTrack(id: 'upbeat_09', bpm: 120, nameEn: 'Flash Sale',           nameHi: 'फ्लैश सेल',       category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_09.mp3', isPro: true),
    MusicTrack(id: 'upbeat_10', bpm: 120, nameEn: 'Power Hour',           nameHi: 'पावर आवर',        category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_10.mp3', isPro: true),
    MusicTrack(id: 'upbeat_11', bpm: 120, nameEn: 'Trending Now',         nameHi: 'ट्रेंडिंग',       category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_11.mp3', isPro: true),
    MusicTrack(id: 'upbeat_12', bpm: 120, nameEn: 'Shop Anthem',          nameHi: 'शॉप एंथम',       category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_12.mp3', isPro: true),
    MusicTrack(id: 'upbeat_13', bpm: 120, nameEn: 'Deal Time',            nameHi: 'डील टाइम',       category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_13.mp3', isPro: true),
    MusicTrack(id: 'upbeat_14', bpm: 120, nameEn: 'Market Buzz',          nameHi: 'मार्केट बज़',    category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_14.mp3', isPro: true),
    MusicTrack(id: 'upbeat_15', bpm: 120, nameEn: 'Closing Bell',         nameHi: 'क्लोजिंग बेल',  category: MusicCategory.upbeat,      assetPath: 'assets/music/upbeat_15.mp3', isPro: true),

    // Devotional (10)
    MusicTrack(id: 'devotional_01', bpm: 72, nameEn: 'Morning Mantra',   nameHi: 'प्रभात मंत्र',   category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_01.mp3', isPro: false),
    MusicTrack(id: 'devotional_02', bpm: 72, nameEn: 'Ganesh Vandana',   nameHi: 'गणेश वंदना',     category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_02.mp3', isPro: false),
    MusicTrack(id: 'devotional_03', bpm: 72, nameEn: 'Shubh Prabhat',    nameHi: 'शुभ प्रभात',    category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_03.mp3', isPro: true),
    MusicTrack(id: 'devotional_04', bpm: 72, nameEn: 'Aarti',            nameHi: 'आरती',           category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_04.mp3', isPro: true),
    MusicTrack(id: 'devotional_05', bpm: 72, nameEn: 'Bhajan Beat',      nameHi: 'भजन बीट',       category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_05.mp3', isPro: true),
    MusicTrack(id: 'devotional_06', bpm: 72, nameEn: 'Shloka',           nameHi: 'श्लोक',         category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_06.mp3', isPro: true),
    MusicTrack(id: 'devotional_07', bpm: 72, nameEn: 'Kirtan',           nameHi: 'कीर्तन',        category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_07.mp3', isPro: true),
    MusicTrack(id: 'devotional_08', bpm: 72, nameEn: 'Navratri Special', nameHi: 'नवरात्रि स्पेशल',category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_08.mp3', isPro: true),
    MusicTrack(id: 'devotional_09', bpm: 72, nameEn: 'Diwali Bells',     nameHi: 'दिवाली घंटी',  category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_09.mp3', isPro: true),
    MusicTrack(id: 'devotional_10', bpm: 72, nameEn: 'Holi Colors',      nameHi: 'होली रंग',     category: MusicCategory.devotional,  assetPath: 'assets/music/devotional_10.mp3', isPro: true),

    // Festive (10)
    MusicTrack(id: 'festive_01', bpm: 115, nameEn: 'Celebration',         nameHi: 'उत्सव',         category: MusicCategory.festive,     assetPath: 'assets/music/festive_01.mp3', isPro: false),
    MusicTrack(id: 'festive_02', bpm: 115, nameEn: 'Festival Beat',       nameHi: 'त्यौहार बीट',  category: MusicCategory.festive,     assetPath: 'assets/music/festive_02.mp3', isPro: false),
    MusicTrack(id: 'festive_03', bpm: 115, nameEn: 'Diwali Special',      nameHi: 'दिवाली स्पेशल',category: MusicCategory.festive,     assetPath: 'assets/music/festive_03.mp3', isPro: true),
    MusicTrack(id: 'festive_04', bpm: 115, nameEn: 'Independence Day',    nameHi: 'स्वतंत्रता दिवस',category: MusicCategory.festive,   assetPath: 'assets/music/festive_04.mp3', isPro: true),
    MusicTrack(id: 'festive_05', bpm: 115, nameEn: 'Republic Day',        nameHi: 'गणतंत्र दिवस', category: MusicCategory.festive,    assetPath: 'assets/music/festive_05.mp3', isPro: true),
    MusicTrack(id: 'festive_06', bpm: 115, nameEn: 'Eid Mubarak',         nameHi: 'ईद मुबारक',    category: MusicCategory.festive,    assetPath: 'assets/music/festive_06.mp3', isPro: true),
    MusicTrack(id: 'festive_07', bpm: 115, nameEn: 'Christmas Joy',       nameHi: 'क्रिसमस',      category: MusicCategory.festive,    assetPath: 'assets/music/festive_07.mp3', isPro: true),
    MusicTrack(id: 'festive_08', bpm: 115, nameEn: 'New Year',            nameHi: 'नया साल',      category: MusicCategory.festive,    assetPath: 'assets/music/festive_08.mp3', isPro: true),
    MusicTrack(id: 'festive_09', bpm: 115, nameEn: 'Birthday Special',    nameHi: 'बर्थडे स्पेशल',category: MusicCategory.festive,   assetPath: 'assets/music/festive_09.mp3', isPro: true),
    MusicTrack(id: 'festive_10', bpm: 115, nameEn: 'Anniversary',         nameHi: 'सालगिरह',     category: MusicCategory.festive,    assetPath: 'assets/music/festive_10.mp3', isPro: true),

    // Calm (10)
    MusicTrack(id: 'calm_01', bpm: 65, nameEn: 'Peaceful Morning',       nameHi: 'शांत सुबह',    category: MusicCategory.calm,        assetPath: 'assets/music/calm_01.mp3', isPro: false),
    MusicTrack(id: 'calm_02', bpm: 65, nameEn: 'Soft Piano',             nameHi: 'सॉफ्ट पियानो', category: MusicCategory.calm,        assetPath: 'assets/music/calm_02.mp3', isPro: false),
    MusicTrack(id: 'calm_03', bpm: 65, nameEn: 'Serene',                 nameHi: 'शांति',        category: MusicCategory.calm,        assetPath: 'assets/music/calm_03.mp3', isPro: true),
    MusicTrack(id: 'calm_04', bpm: 65, nameEn: 'Trust & Care',           nameHi: 'विश्वास',      category: MusicCategory.calm,        assetPath: 'assets/music/calm_04.mp3', isPro: true),
    MusicTrack(id: 'calm_05', bpm: 65, nameEn: 'Professional',           nameHi: 'प्रोफेशनल',   category: MusicCategory.calm,        assetPath: 'assets/music/calm_05.mp3', isPro: true),
    MusicTrack(id: 'calm_06', bpm: 65, nameEn: 'Luxury',                 nameHi: 'लक्ज़री',      category: MusicCategory.calm,        assetPath: 'assets/music/calm_06.mp3', isPro: true),
    MusicTrack(id: 'calm_07', bpm: 65, nameEn: 'Jewelry Glam',           nameHi: 'ज्वेलरी ग्लैम',category: MusicCategory.calm,       assetPath: 'assets/music/calm_07.mp3', isPro: true),
    MusicTrack(id: 'calm_08', bpm: 65, nameEn: 'Fashion Boutique',       nameHi: 'फैशन बुटीक',  category: MusicCategory.calm,        assetPath: 'assets/music/calm_08.mp3', isPro: true),
    MusicTrack(id: 'calm_09', bpm: 65, nameEn: 'Spa & Salon',            nameHi: 'सैलून',        category: MusicCategory.calm,        assetPath: 'assets/music/calm_09.mp3', isPro: true),
    MusicTrack(id: 'calm_10', bpm: 65, nameEn: 'Real Estate',            nameHi: 'रियल एस्टेट', category: MusicCategory.calm,        assetPath: 'assets/music/calm_10.mp3', isPro: true),

    // Sound Effects (5)
    MusicTrack(id: 'sfx_01', nameEn: 'Cash Register',           nameHi: 'कैश रजिस्टर', category: MusicCategory.soundEffects, assetPath: 'assets/music/sfx_01.mp3', isPro: false),
    MusicTrack(id: 'sfx_02', nameEn: 'Whoosh & Reveal',         nameHi: 'हूश रिवील',  category: MusicCategory.soundEffects, assetPath: 'assets/music/sfx_02.mp3', isPro: true),
    MusicTrack(id: 'sfx_03', nameEn: 'Bell Ding',               nameHi: 'बेल डिंग',   category: MusicCategory.soundEffects, assetPath: 'assets/music/sfx_03.mp3', isPro: true),
    MusicTrack(id: 'sfx_04', nameEn: 'Drum Roll',               nameHi: 'ड्रम रोल',  category: MusicCategory.soundEffects, assetPath: 'assets/music/sfx_04.mp3', isPro: true),
    MusicTrack(id: 'sfx_05', nameEn: 'Applause',                nameHi: 'तालियां',   category: MusicCategory.soundEffects, assetPath: 'assets/music/sfx_05.mp3', isPro: true),
  ];

  static MusicTrack? findById(String id) {
    try {
      return tracks.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<MusicTrack> byCategory(MusicCategory cat) =>
      tracks.where((t) => t.category == cat).toList();
}
