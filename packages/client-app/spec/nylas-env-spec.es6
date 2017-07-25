import { remote } from 'electron';

describe("the `NylasEnv` global", function nylasEnvSpec() {
  describe('window sizing methods', () => {
    describe('::getPosition and ::setPosition', () =>
      it('sets the position of the window, and can retrieve the position just set', () => {
        NylasEnv.setPosition(22, 45);
        expect(NylasEnv.getPosition()).toEqual({x: 22, y: 45});
      })
    );

    describe('::getSize and ::setSize', () => {
      beforeEach(() => {
        this.originalSize = NylasEnv.getSize()
      });
      afterEach(() => NylasEnv.setSize(this.originalSize.width, this.originalSize.height));

      it('sets the size of the window, and can retrieve the size just set', () => {
        NylasEnv.setSize(100, 400);
        expect(NylasEnv.getSize()).toEqual({width: 100, height: 400});
      });
    });

    describe('::setMinimumWidth', () => {
      const win = NylasEnv.getCurrentWindow();

      it("sets the minimum width", () => {
        const inputMinWidth = 500;
        win.setMinimumSize(1000, 1000);

        NylasEnv.setMinimumWidth(inputMinWidth);

        const [actualMinWidth] = win.getMinimumSize();
        expect(actualMinWidth).toBe(inputMinWidth);
      });

      it("sets the current size if minWidth > current width", () => {
        const inputMinWidth = 1000;
        win.setSize(500, 500);

        NylasEnv.setMinimumWidth(inputMinWidth);

        const [actualWidth] = win.getMinimumSize();
        expect(actualWidth).toBe(inputMinWidth);
      });
    });

    describe('::getDefaultWindowDimensions', () => {
      it("returns primary display's work area size if it's small enough", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1440, height: 900}});

        const out = NylasEnv.getDefaultWindowDimensions();
        expect(out).toEqual({x: 0, y: 0, width: 1440, height: 900});
      });

      it("caps width at 1440 and centers it, if wider", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1840, height: 900}});

        const out = NylasEnv.getDefaultWindowDimensions();
        expect(out).toEqual({x: 200, y: 0, width: 1440, height: 900});
      });

      it("caps height at 900 and centers it, if taller", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1440, height: 1100}});

        const out = NylasEnv.getDefaultWindowDimensions();
        expect(out).toEqual({x: 0, y: 100, width: 1440, height: 900});
      });

      it("returns only the max viewport size if it's smaller than the defaults", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1000, height: 800}});

        const out = NylasEnv.getDefaultWindowDimensions();
        expect(out).toEqual({x: 0, y: 0, width: 1000, height: 800});
      });

      it("always rounds X and Y", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1845, height: 955}});

        const out = NylasEnv.getDefaultWindowDimensions();
        expect(out).toEqual({x: 202, y: 27, width: 1440, height: 900});
      });
    });
  });


  describe(".isReleasedVersion()", () =>
    it("returns false if the version is a SHA and true otherwise", () => {
      let version = '0.1.0';
      spyOn(NylasEnv, 'getVersion').andCallFake(() => version);
      expect(NylasEnv.isReleasedVersion()).toBe(true);
      version = '36b5518';
      expect(NylasEnv.isReleasedVersion()).toBe(false);
    })
  );

  describe("error handling", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "inSpecMode").andReturn(false)
      spyOn(NylasEnv, "inDevMode").andReturn(false);
      spyOn(NylasEnv, "openDevTools")
      spyOn(NylasEnv, "executeJavaScriptInDevTools")
      spyOn(NylasEnv.errorLogger, "reportError");
    });

    it("Catches errors that make it to window.onerror", () => {
      spyOn(NylasEnv, "reportError");
      const e = new Error("Test Error")
      window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
      expect(NylasEnv.reportError).toHaveBeenCalled();
      expect(NylasEnv.reportError.calls[0].args[0]).toBe(e);
      const extra = NylasEnv.reportError.calls[0].args[1]
      expect(extra.url).toBe("abc")
      expect(extra.line).toBe(2)
      expect(extra.column).toBe(3)
    });

    it("Catches unhandled rejections", async () => {
      spyOn(NylasEnv, "reportError");
      const err = new Error("TEST");

      const p = new Promise((resolve, reject) => {
        reject(err);
      })
      p.then(() => {
        throw new Error("Shouldn't resolve")
      })

      /**
       * This test was started from within the `setTimeout` block of the
       * Node event loop. The unhandled rejection will not get caught
       * until the "pending callbacks" block (which happens next). Since
       * that happens immediately next it's important that we don't use:
       *
       * await new Promise(setImmediate)
       *
       * Because of setImmediate's position in the Node event loop
       * relative to this test and process.on('unhandledRejection'), using
       * setImmediate would require us to await for it twice.
       *
       * We can use the original, no-stubbed-out `setTimeout` to put our
       * test in the correct spot in the Node event loop relative to
       * unhandledRejection.
       */
      await new Promise((resolve) => {
        window.originalSetTimeout(resolve, 0)
      })

      expect(NylasEnv.reportError.callCount).toBe(1);
      expect(NylasEnv.reportError.calls[0].args[0]).toBe(err);
    });

    describe("reportError", () => {
      beforeEach(() => {
        this.testErr = new Error("Test");
        spyOn(console, "error")
      });

      it("emits will-throw-error", () => {
        spyOn(NylasEnv.emitter, "emit")
        NylasEnv.reportError(this.testErr);
        expect(NylasEnv.emitter.emit).toHaveBeenCalled();
        expect(NylasEnv.emitter.emit.callCount).toBe(2);
        expect(NylasEnv.emitter.emit.calls[0].args[0]).toBe("will-throw-error")
        expect(NylasEnv.emitter.emit.calls[1].args[0]).toBe("did-throw-error")
      });

      it("returns if the event has its default prevented", () => {
        spyOn(NylasEnv.emitter, "emit").andCallFake((name, event) => {
          event.preventDefault()
        })
        NylasEnv.reportError(this.testErr);
        expect(NylasEnv.emitter.emit).toHaveBeenCalled();
        expect(NylasEnv.emitter.emit.callCount).toBe(1);
        expect(NylasEnv.emitter.emit.calls[0].args[0]).toBe("will-throw-error")
      });

      it("opens dev tools in dev mode", () => {
        jasmine.unspy(NylasEnv, "inDevMode")
        spyOn(NylasEnv, "inDevMode").andReturn(true);
        NylasEnv.reportError(this.testErr);
        expect(NylasEnv.openDevTools).toHaveBeenCalled();
        expect(NylasEnv.executeJavaScriptInDevTools).toHaveBeenCalled();
      });

      it("sends the error report to the error logger", () => {
        NylasEnv.reportError(this.testErr);
        expect(NylasEnv.errorLogger.reportError).toHaveBeenCalled();
        expect(NylasEnv.errorLogger.reportError.callCount).toBe(1);
        expect(NylasEnv.errorLogger.reportError.calls[0].args[0]).toBe(this.testErr);
      });

      it("emits did-throw-error", () => {
        spyOn(NylasEnv.emitter, "emit")
        NylasEnv.reportError(this.testErr);
        expect(NylasEnv.openDevTools).not.toHaveBeenCalled();
        expect(NylasEnv.executeJavaScriptInDevTools).not.toHaveBeenCalled();
        expect(NylasEnv.emitter.emit.callCount).toBe(2);
        expect(NylasEnv.emitter.emit.calls[0].args[0]).toBe("will-throw-error")
        expect(NylasEnv.emitter.emit.calls[1].args[0]).toBe("did-throw-error")
      });
    });
  });
});
