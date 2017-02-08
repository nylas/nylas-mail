const {createLogger} = require('../logger');
const {testStream} = require('../log-streams');

describe("createLogger", () => {
  it("should log msgs correctly", () => {
    const globalLogger = createLogger("specs");

    globalLogger.info('default log');
    let logOutput = testStream.stream.toString();
    let parsedLog = JSON.parse(logOutput);
    expect(parsedLog.msg).toEqual('default log');
    testStream.stream.reset();

    const childLogger = globalLogger.child({child: true});
    childLogger.info('child logger');
    logOutput = testStream.stream.toString();
    parsedLog = JSON.parse(logOutput);
    expect(parsedLog.child).toEqual(true);
    testStream.stream.reset();

    const fakeAccount = {
      id: 'abcde',
      emailAddress: 'ben.bitdiddle@mit.edu',
      provider: 'imap',
    };
    const loggerForAccount = globalLogger.forAccount(fakeAccount, childLogger);
    loggerForAccount.info('log for account');
    logOutput = testStream.stream.toString();
    parsedLog = JSON.parse(logOutput);
    expect(parsedLog.account_id).toEqual(fakeAccount.id);
    expect(parsedLog.account_email).toEqual(fakeAccount.emailAddress);
    expect(parsedLog.account_provider).toEqual(fakeAccount.provider);
    expect(parsedLog.n1_id).toEqual('Not available');
    expect(parsedLog.child).toEqual(true);
    testStream.stream.reset();
  });
});
