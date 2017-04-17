const fs = require('fs');
const path = require('path');
const LocalDatabaseConnector = require('../src/shared/local-database-connector')

const FIXTURES_PATH = path.join(__dirname, 'fixtures');
const ACCOUNT_ID = 'test-account-id';

function forEachJSONFixture(relativePath, callback) {
  const fixturesDir = path.join(FIXTURES_PATH, relativePath);
  const filenames = fs.readdirSync(fixturesDir).filter(f => f.endsWith('.json'));
  filenames.forEach((filename) => {
    const json = JSON.parse(fs.readFileSync(path.join(fixturesDir, filename)));
    callback(filename, json);
  });
}

function forEachHTMLAndTXTFixture(relativePath, callback) {
  const fixturesDir = path.join(FIXTURES_PATH, relativePath);
  const filenames = fs.readdirSync(fixturesDir).filter(f => f.endsWith('.html'));
  filenames.forEach((filename) => {
    const html = fs.readFileSync(path.join(fixturesDir, filename)).toString();
    const basename = path.parse(filename).name;
    const txt = fs.readFileSync(path.join(fixturesDir, `${basename}.txt`)).toString().replace(/\n$/, '');
    callback(filename, html, txt);
  });
}

async function getTestDatabase(accountId = ACCOUNT_ID) {
  await LocalDatabaseConnector.ensureAccountDatabase(accountId)
  return LocalDatabaseConnector.forAccount(accountId)
}

function destroyTestDatabase(accountId = ACCOUNT_ID) {
  LocalDatabaseConnector.destroyAccountDatabase(accountId)
}

function mockImapBox() {
  return {
    setLabels: jasmine.createSpy('setLabels'),
    removeLabels: jasmine.createSpy('removeLabels'),
  }
}

const silentLogger = {
  info: () => {},
  warn: () => {},
  debug: () => {},
  error: () => {},
}

module.exports = {
  FIXTURES_PATH,
  ACCOUNT_ID,
  silentLogger,
  forEachJSONFixture,
  forEachHTMLAndTXTFixture,
  mockImapBox,
  getTestDatabase,
  destroyTestDatabase,
}
