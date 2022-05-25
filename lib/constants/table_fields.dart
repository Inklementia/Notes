const idColumn = 'id';
const userIdColumn = 'user_id';
const titleColumn = 'title';
const textColumn = 'text';
const isSyncedWithCloudColumn = 'is_synced_with_cloud';
const emailColumn = 'email';

const dbName = 'notes.db';
const usersTable = 'users';
const notesTable = 'notes';

const createNotesTable = '''CREATE TABLE IF NOT EXISTS "notes" (
	"id"	INTEGER NOT NULL,
	"user_id"	INTEGER NOT NULL,
	"title"	TEXT NOT NULL,
	"text"	TEXT,
	"is_synced_with_cloud"	INTEGER DEFAULT 0,
	FOREIGN KEY("user_id") REFERENCES "users"("id"),
	PRIMARY KEY("id" AUTOINCREMENT)
);''';

const createUserTable = '''CREATE TABLE IF NOT EXISTS "users" (
	"id"	INTEGER NOT NULL,
	"email"	TEXT NOT NULL UNIQUE,
	PRIMARY KEY("id" AUTOINCREMENT)
);''';
