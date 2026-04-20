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
  });

  final String id;
  final VideoProject project;
  final DateTime updatedAt;
  final String? thumbnailPath;
}

class DraftService {
  static Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'promoreel_history.db'),
      version: 3,
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
        await db.execute('''
          CREATE TABLE drafts (
            id TEXT PRIMARY KEY,
            project_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            thumbnail_path TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE videos ADD COLUMN project_json TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS drafts (
              id TEXT PRIMARY KEY,
              project_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              thumbnail_path TEXT
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> saveDraft(VideoProject project, {String? thumbnailPath}) async {
    final db = await _database();
    await db.insert(
      'drafts',
      {
        'id': project.id,
        'project_json': jsonEncode(project.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'thumbnail_path': thumbnailPath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DraftRecord>> getDrafts() async {
    final db = await _database();
    final rows =
        await db.query('drafts', orderBy: 'updated_at DESC', limit: 20);
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
      );
    } catch (_) {
      return null;
    }
  }
}
