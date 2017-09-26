/* eslint no-irregular-whitespace: 0 */
import fs from 'fs';
import { removeTrackingPixels } from '../lib/main';

const readFixture = name => {
  return fs
    .readFileSync(`${__dirname}/fixtures/${name}`)
    .toString()
    .trim();
};

describe('TrackingPixelsExtension', function trackingPixelsExtension() {
  it("should splice all tracking pixels from emails I've sent", () => {
    const before = readFixture('a-before.txt');
    const expected = readFixture('a-after.txt');

    const message = {
      body: before,
      accountId: '1234',
      isFromMe: () => true,
    };
    removeTrackingPixels(message);
    expect(message.body).toEqual(expected);
  });

  it('should always splice Nylas read receipts for the current account id ', () => {
    const before = readFixture('b-before.txt');
    const expected = readFixture('b-after.txt');

    const message = {
      body: before,
      accountId: '1234',
      isFromMe: () => false,
    };
    removeTrackingPixels(message);
    expect(message.body).toEqual(expected);
  });
});
