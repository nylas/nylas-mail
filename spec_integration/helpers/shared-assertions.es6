export function assertBasicWindow() {
  it("has main window visible", (done)=> {
    this.app.client.isWindowVisible()
    .then((result)=>{ expect(result).toBe(true) })
    .finally(done)
  });

  it("has main window focused", (done)=> {
    this.app.client.isWindowFocused()
    .then((result)=>{ expect(result).toBe(true) })
    .finally(done)
  });

  it("isn't minimized", (done)=> {
    this.app.client.isWindowMinimized()
    .then((result)=>{ expect(result).toBe(false) })
    .finally(done)
  });

  it("doesn't have the dev tools open", (done)=> {
    this.app.client.isWindowDevToolsOpened()
    .then((result)=>{ expect(result).toBe(false) })
    .finally(done)
  });
}
