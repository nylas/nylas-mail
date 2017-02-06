import Umzug from 'umzug'
import {DatabaseConnector} from '../packages/cloud-core'

async function activate() {
  // Perform migrations before starting sync
  const db = await DatabaseConnector.forShared();

  const umzug = new Umzug({
    storage: 'sequelize',
    storageOptions: {
      sequelize: db.sequelize,
      modelName: 'migration',
      tableName: 'migrations',
    },
    migrations: {
      path: `migrations`,
      params: [db.sequelize.getQueryInterface(), db.sequelize],
      pattern: /^\d+[\w-]+\.es6$/,
    },
    logging: console.log,
  });

  return umzug;
}

async function upgrade() {
  const umzug = await activate();
  const pending = await umzug.pending();
  if (pending.length > 0) {
    console.log(`Running ${pending.length} migration(s).`)
  } else {
    console.log(`No new migrations to run.`)
  }

  return umzug.up() // run all pending migrations
}

async function downgrade() {
  const umzug = await activate();
  console.log(`Running 1 down migration.`)

  return umzug.down()
}

async function main() {
  if (process.argv.length !== 3) {
    console.log("usage: migrate-db up|down")
  } else if (process.argv[2] === 'up') {
    await upgrade();
  } else if (process.argv[2] === 'down') {
    await downgrade();
  }
}

main();
