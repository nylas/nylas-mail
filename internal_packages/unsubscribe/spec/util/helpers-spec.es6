import {shortenURL, shortenEmail, interpretEmail, defaultBody} from '../../lib/util/helpers';

describe("helpers", function helpers() {
  it("shortenURL", () => {
    expect(shortenURL("http://www.aweber.com/z/r/?HCwMbCwctKzsLJzqHAxMtEa0zCzMTOycrIw=")).toEqual("www.aweber.com/...");
    expect(shortenURL("https://www.aweber.com/z/r/?HCwMbCwctKzsLJzqHAxMtEa0zCzMTOycrIw=")).toEqual("www.aweber.com/...");
  });
  it("shortenEmail", () => {
    expect(shortenEmail("mailto:test@test.com")).toEqual("test@test.com");
    expect(shortenEmail("mailto:testing0123456789@test.com")).toEqual("testing01234...@test.com");
    expect(shortenEmail("mailto:test@test.testing0123456789.com")).toEqual("test@test.testing0123456789...");
  });
  it("interpretEmail", () => {
    expect(interpretEmail("mailto:thisistrue@aweber.com?subject=unsubscribe;HCwMbCwctKzsLJzqHAxMtEa0zCzMTOycrIw=")).toEqual({
      subject: "unsubscribe;HCwMbCwctKzsLJzqHAxMtEa0zCzMTOycrIw=",
      body: defaultBody,
      to: [{email: "thisistrue@aweber.com"}],
    });
    expect(interpretEmail("mailto:test@test.com?cc=test2@test.com&bcc=test3@test.com&body=end%20subscription")).toEqual({
      subject: "Unsubscribe",
      body: "end%20subscription",
      to: [{email: "test@test.com"}],
      cc: [{email: "test2@test.com"}],
      bcc: [{email: "test3@test.com"}],
    });
  });
});
