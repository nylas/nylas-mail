import path from 'path';
import Sqlite3 from 'better-sqlite3';

export function setupDatabase(dbPath) {
  return new Promise((resolve, reject) => {
    const db = new Sqlite3(dbPath, {});
    db.on('close', reject)
    db.on('open', () => {
      // https://www.sqlite.org/wal.html
      // WAL provides more concurrency as readers do not block writers and a writer
      // does not block readers. Reading and writing can proceed concurrently.
      db.pragma(`journal_mode = WAL`);

      // Note: These are properties of the connection, so they must be set regardless
      // of whether the database setup queries are run.

      // https://www.sqlite.org/intern-v-extern-blob.html
      // A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
      db.pragma(`main.page_size = 8192`);
      db.pragma(`main.cache_size = 20000`);
      db.pragma(`main.synchronous = NORMAL`);

      resolve(db);
    });
  })
}

export function databasePath(configDirPath, specMode = false) {
  let dbPath = path.join(configDirPath, 'edgehill.db');
  if (specMode) {
    dbPath = path.join(configDirPath, 'edgehill.test.db');
  }
  return dbPath
}
