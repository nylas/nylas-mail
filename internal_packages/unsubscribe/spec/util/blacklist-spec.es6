import {electronCantOpen, blacklistedEmail} from '../../lib/util/blacklist';

describe("blacklist", function blacklist() {
  it("electronCantOpen", () => {
    expect(electronCantOpen("https://github.com/unsubscribe")).toBe(true);
    expect(electronCantOpen("https://test.com/wf/click?upn=iwbeg538ht938h3gnio")).toBe(true);
    expect(electronCantOpen("https://test.com/unsubscribe")).toBe(false);
  });
  it("blacklistedEmail", () => {
    expect(blacklistedEmail("mailto:sympa@test.com")).toBe(true);
    expect(blacklistedEmail("mailto:test@test.com")).toBe(false);
  });
});
