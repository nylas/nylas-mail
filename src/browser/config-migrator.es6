export default class ConfigMigrator {
  constructor(config, database) {
    this.config = config;
    this.database = database;
  }

  migrate() {
    /**
     * In version before 1.0.21 we stored the Nylas ID Identity in the Config.
     * After 1.0.21 we moved it into the JSONBlob Database Store.
     */
    const oldIdentity = this.config.get("nylas.identity") || {};
    if (!oldIdentity.id) return;
    const key = "NylasID"
    const q = `REPLACE INTO JSONBlob (id, data, client_id) VALUES (?,?,?)`;
    const jsonBlobData = {
      id: key,
      clientId: key,
      serverId: key,
      json: oldIdentity,
    }
    this.database.database.prepare(q).run([key, JSON.stringify(jsonBlobData), key])
    this.config.set("nylas.identity", null)
  }
}
