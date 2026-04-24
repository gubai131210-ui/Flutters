import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'senti.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE fragments(
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            subtitle TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            written_at TEXT NOT NULL,
            cover_path TEXT,
            dominant_color INTEGER,
            emoji TEXT NOT NULL,
            layout_hint TEXT NOT NULL,
            random_seed INTEGER NOT NULL,
            play_weight INTEGER NOT NULL,
            reading_seconds INTEGER NOT NULL,
            tags_json TEXT NOT NULL,
            metadata_json TEXT NOT NULL,
            media_json TEXT NOT NULL,
            mood_scores_json TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }
}
