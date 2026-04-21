import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class VideoRecord {
  const VideoRecord({
    required this.id,
    required this.outputPath,
    required this.thumbnailPath,
    required this.createdAt,
    required this.durationSeconds,
    this.projectJson,
  });

  final int id;
  final String outputPath;
  final String thumbnailPath;
  final DateTime createdAt;
  final int durationSeconds;
  final Map<String, dynamic>? projectJson;

  bool get fileExists => File(outputPath).existsSync();
  bool get hasProject => projectJson != null;
}

class VideoHistoryService {
  static Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    // NOTE: this service shares the `promoreel_history.db` file with
    // `DraftService`. sqflite caches open connections by path, so both
    // services MUST declare the same schema version and run the same
    // schema guards — otherwise whichever opens first locks the DB at its
    // own version and the other's onUpgrade never runs. Keep the version
    // and `onOpen` body in lockstep with `DraftService`.
    _db = await openDatabase(
      p.join(dir.path, 'promoreel_history.db'),
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE videos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            output_path TEXT NOT NULL,
            thumbnail_path TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL DEFAULT 30,
            project_json TEXT
          )
        ''');
        await _ensureDraftsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE videos ADD COLUMN project_json TEXT');
        }
        await _ensureDraftsTable(db);
      },
      onOpen: (db) async {
        await _ensureDraftsTable(db);
      },
    );
    return _db!;
  }

  /// Kept in sync with `DraftService._ensureDraftsTable`. Creating the
  /// drafts table here as well lets this service safely be the first to
  /// open the shared DB without leaving it in a state that breaks
  /// `DraftService`'s later queries.
  static Future<void> _ensureDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drafts (
        id TEXT PRIMARY KEY,
        project_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        thumbnail_path TEXT,
        is_rendering INTEGER NOT NULL DEFAULT 0
      )
    ''');
    try {
      await db.execute(
          'ALTER TABLE drafts ADD COLUMN is_rendering INTEGER NOT NULL DEFAULT 0');
    } catch (_) {
      // Column already exists.
    }
  }

  Future<int> insert({
    required String outputPath,
    required String thumbnailPath,
    int durationSeconds = 30,
    Map<String, dynamic>? projectJson,
  }) async {
    final db = await _database();
    return db.insert('videos', {
      'output_path':       outputPath,
      'thumbnail_path':    thumbnailPath,
      'created_at':        DateTime.now().millisecondsSinceEpoch,
      'duration_seconds':  durationSeconds,
      'project_json':      projectJson != null ? jsonEncode(projectJson) : null,
    });
  }

  Future<List<VideoRecord>> getAll() async {
    final db = await _database();
    final rows = await db.query('videos', orderBy: 'created_at DESC', limit: 50);
    return rows.map(_fromRow).toList();
  }

  Future<int> countToday() async {
    final db = await _database();
    final midnight = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM videos WHERE created_at >= ?',
      [midnight.millisecondsSinceEpoch],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> delete(int id) async {
    final db = await _database();
    await db.delete('videos', where: 'id = ?', whereArgs: [id]);
  }

  VideoRecord _fromRow(Map<String, dynamic> row) {
    final jsonStr = row['project_json'] as String?;
    Map<String, dynamic>? projectJson;
    if (jsonStr != null) {
      try {
        projectJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return VideoRecord(
      id:              row['id'] as int,
      outputPath:      row['output_path'] as String,
      thumbnailPath:   row['thumbnail_path'] as String,
      createdAt:       DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      durationSeconds: row['duration_seconds'] as int,
      projectJson:     projectJson,
    );
  }
}
