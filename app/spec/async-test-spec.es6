const foo = () => {
  return new Promise(resolve => {
    setTimeout(() => {
      console.log('---------------------------------- RESOLVING');
      resolve();
    }, 100);
  });
};

xdescribe('test spec', function testSpec() {
  // it("has 1 failure", () => {
  //   expect(false).toBe(true)
  // });

  it('is async', () => {
    const p = foo().then(() => {
      console.log('THEN');
      expect(true).toBe(true);
    });
    advanceClock(200);
    return p;
  });

  // it("has another failure", () => {
  //   expect(false).toBe(true)
  // });
});
