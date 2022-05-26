import 'dart:async';

import 'package:notes/constants/table_fields.dart';
import 'package:notes/services/crud/database_exceptions.dart';
import 'package:notes/services/crud/database_note.dart';
import 'package:notes/services/crud/database_user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as devtools show log;
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' show join;

class NotesService {
  Database? _db;
  List<DatabaseNote> _notes = [];
//singleton
  static final NotesService _shared = NotesService._sharedInstance();
  NotesService._sharedInstance();
  factory NotesService() => _shared;

  final _notesStreamController =
      StreamController<List<DatabaseNote>>.broadcast();

  Stream<List<DatabaseNote>> get allNotes => _notesStreamController.stream;

  Future<DatabaseUser> getOrCreateUser({required String email}) async {
    try {
      final user = await getUser(email: email);
      return user;
    } on CouldNotFindUserException {
      final createdUser = await createUser(email: email);
      return createdUser;
    } catch (e) {
      rethrow;
      //for debugging
    }
  }

  Future<void> _cacheNotes() async {
    final allNotes = await getAllNotes();

    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Database _getDatabaseOrThrow() {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpenException();
    } else {
      return db;
    }
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }

    try {
      final docsPath = await getApplicationDocumentsDirectory();
      devtools.log(docsPath.toString());
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);
      _db = db;

      //create user table
      await db.execute(createUserTable);
      //create notes table
      await db.execute(createNotesTable);

      await _cacheNotes();
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectoryException();
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpenException();
    } else {
      await db.close();
      _db = null;
    }
  }

  Future<void> _ensureThatDbIsOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {}
  }

//users methods
  Future<void> deleteUser({required String email}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();
    // deletedCount = 1 or 0
    final deletedCount = await db.delete(
      usersTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (deletedCount != 1) {
      throw CouldNotDeleteUserException();
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();

    final results = await db.query(
      usersTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (results.isNotEmpty) {
      throw UserAlreadyExistsException();
    }
    final userId = await db.insert(usersTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(id: userId, email: email);
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();

    final results = await db.query(
      usersTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (results.isNotEmpty) {
      throw CouldNotFindUserException();
    } else {
      return DatabaseUser.fromRow(results.first);
    }
  }

//notes methods
  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();

    final dbUser = await getUser(email: owner.email);

    if (dbUser != owner) {
      throw CouldNotFindUserException();
    }

    const text = '';
    const title = '';
    final noteId = await db.insert(notesTable, {
      userIdColumn: owner.id,
      titleColumn: title,
      textColumn: text,
      isSyncedWithCloudColumn: 1,
    });

    final note = DatabaseNote(
      id: noteId,
      userId: owner.id,
      title: title,
      text: text,
      isSyncedWithCloud: true,
    );

    _notes.add(note);
    _notesStreamController.add(_notes);

    return note;
  }

  Future<void> deleteNote({required int id}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();
    // deletedCount = 1 or 0
    final deletedCount = await db.delete(
      notesTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedCount != 1) {
      throw CouldNotDeleteNoteException();
    } else {
      _notes.removeWhere((note) => note.id == id);
      _notesStreamController.add(_notes);
    }
  }

  Future<int> deleteAllNotes() async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();
    final deleteCount = await db.delete(notesTable);
    _notes = [];
    _notesStreamController.add(_notes);
    return deleteCount;
  }

  Future<DatabaseNote> getNote({required int id}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();

    final results = await db.query(
      notesTable,
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      throw CouldNotFindNoteException();
    } else {
      final note = DatabaseNote.fromRow(results.first);

      _notes.removeWhere((none) => note.id == id);
      _notes.add(note);
      _notesStreamController.add(_notes);

      return note;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();

    final results = await db.query(notesTable);

    return results.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  Future<DatabaseNote> updateNote(
      {required DatabaseNote note,
      required String title,
      required String text}) async {
    await _ensureThatDbIsOpen();
    final db = _getDatabaseOrThrow();
    //m,ake sure note exist
    await getNote(id: note.id);

    //update DB
    final updateCount = await db.update(notesTable, {
      titleColumn: title,
      textColumn: text,
      isSyncedWithCloudColumn: 0,
    });

    if (updateCount == 0) {
      throw CouldNotUpdateNoteException();
    } else {
      final updateNote = await getNote(id: note.id);

      _notes.removeWhere((note) => note.id == updateNote.id);
      _notes.add(updateNote);
      _notesStreamController.add(_notes);

      return updateNote;
    }
  }
}
