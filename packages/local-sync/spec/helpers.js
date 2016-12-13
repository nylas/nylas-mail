const fs = require('fs');
const path = require('path');

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
}
