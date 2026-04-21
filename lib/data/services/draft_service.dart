import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/video_project.dart';

class DraftRecord {
  const DraftRecord({
    required this.id,
    required this.project,
    required this.updatedAt,
    this.thumbnailPath,
    this.isRendering = false,
  });

  final String id;
  final VideoProject project;
  final DateTime updatedAt;
  final String? thumbnailPath;

  /// True when the export screen was last seen mid-render. If the app was
  /// killed while rendering, this flag stays true on next launch — the home
  /// screen uses it to offer a "Resume export" chip.
  final bool isRendering;
}

class DraftService {
  static Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
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
        // Safety net: some install histories produced databases where the
        // drafts table was missed by onUpgrade (transaction rolled back, etc.).
        // Running this on every open is idempotent and self-heals.
        await _ensureDraftsTable(db);
      },
    );
    return _db!;
  }

  /// Creates the `drafts` table if it doesn't exist and backfills any newer
  /// columns onto older installs. Called from `onCreate`, `onUpgrade`, and
  /// `onOpen` — all idempotent so repeat calls are safe.
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
    // If the table already existed from an older schema without
    // `is_rendering`, add that column now. ALTER errors when the column is
    // already present — swallow that specific case.
    try {
      await db.execute(
          'ALTER TABLE drafts ADD COLUMN is_rendering INTEGER NOT NULL DEFAULT 0');
    } catch (_) {
      // Column already exists — nothing to do.
    }
  }

  Future<void> saveDraft(
    VideoProject project, {
    String? thumbnailPath,
    bool isRendering = false,
  }) async {
    final db = await _database();
    await db.insert(
      'drafts',
      {
        'id': project.id,
        'project_json': jsonEncode(project.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'thumbnail_path': thumbnailPath,
        'is_rendering': isRendering ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mark a draft as "currently being rendered". If the app is killed before
  /// [clearRenderingFlag] or [deleteDraft] runs, this flag survives and lets
  /// the home screen offer a resume prompt on next launch.
  Future<void> markRendering(VideoProject project, {String? thumbnailPath}) =>
      saveDraft(project, thumbnailPath: thumbnailPath, isRendering: true);

  /// Clear the rendering flag on a draft without deleting it (e.g. render
  /// failed and the user should be able to retry).
  Future<void> clearRenderingFlag(String id) async {
    final db = await _database();
    await db.update(
      'drafts',
      {'is_rendering': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DraftRecord>> getDrafts() async {
    final db = await _database();
    final rows =
        await db.query('drafts', orderBy: 'updated_at DESC', limit: 20);
    return rows.map(_fromRow).whereType<DraftRecord>().toList();
  }

  /// Drafts that were mid-render when the app was last killed — surface
  /// these on the home screen with a "Resume export" affordance.
  Future<List<DraftRecord>> getOrphanedRenders() async {
    final db = await _database();
    final rows = await db.query(
      'drafts',
      where: 'is_rendering = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).whereType<DraftRecord>().toList();
  }

  Future<void> deleteDraft(String id) async {
    final db = await _database();
    await db.delete('drafts', where: 'id = ?', whereArgs: [id]);
  }

  DraftRecord? _fromRow(Map<String, dynamic> row) {
    try {
      final json =
          jsonDecode(row['project_json'] as String) as Map<String, dynamic>;
      return DraftRecord(
        id: row['id'] as String,
        project: VideoProject.fromJson(json),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        thumbnailPath: row['thumbnail_path'] as String?,
        isRendering: (row['is_rendering'] as int? ?? 0) == 1,
      );
    } catch (_) {
      return null;
    }
  }
}
