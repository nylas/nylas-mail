import {openDatabase, databasePath} from '../database-helpers'

export default class DatabaseReader {
  constructor({configDirPath, specMode}) {
    this.databasePath = databasePath(configDirPath, specMode)
  }

  async open() {
    this.database = await openDatabase(this.databasePath)
  }

  getJSONBlob(key) {
    const q = `SELECT * FROM JSONBlob WHERE id = '${key}'`;
    try {
      const row = this.database.prepare(q).get();
      if (!row || !row.data) return null
      return (JSON.parse(row.data) || {}).json
    } catch (err) {
      return null
    }
  }
}
