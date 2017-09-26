import { remote } from 'electron';

describe('the `AppEnv` global', function nylasEnvSpec() {
  describe('window sizing methods', () => {
    describe('::getPosition and ::setPosition', () =>
      it('sets the position of the window, and can retrieve the position just set', () => {
        AppEnv.setPosition(22, 45);
        expect(AppEnv.getPosition()).toEqual({ x: 22, y: 45 });
      }));

    describe('::getSize and ::setSize', () => {
      beforeEach(() => {
        this.originalSize = AppEnv.getSize();
      });
      afterEach(() => AppEnv.setSize(this.originalSize.width, this.originalSize.height));

      it('sets the size of the window, and can retrieve the size just set', () => {
        AppEnv.setSize(100, 400);
        expect(AppEnv.getSize()).toEqual({ width: 100, height: 400 });
      });
    });

    describe('::setMinimumWidth', () => {
      const win = AppEnv.getCurrentWindow();

      it('sets the minimum width', () => {
        const inputMinWidth = 500;
        win.setMinimumSize(1000, 1000);

        AppEnv.setMinimumWidth(inputMinWidth);

        const [actualMinWidth] = win.getMinimumSize();
        expect(actualMinWidth).toBe(inputMinWidth);
      });

      it('sets the current size if minWidth > current width', () => {
        const inputMinWidth = 1000;
        win.setSize(500, 500);

        AppEnv.setMinimumWidth(inputMinWidth);

        const [actualWidth] = win.getMinimumSize();
        expect(actualWidth).toBe(inputMinWidth);
      });
    });

    describe('::getDefaultWindowDimensions', () => {
      it("returns primary display's work area size if it's small enough", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({
          workAreaSize: { width: 1440, height: 900 },
        });

        const out = AppEnv.getDefaultWindowDimensions();
        expect(out).toEqual({ x: 0, y: 0, width: 1440, height: 900 });
      });

      it('caps width at 1440 and centers it, if wider', () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({
          workAreaSize: { width: 1840, height: 900 },
        });

        const out = AppEnv.getDefaultWindowDimensions();
        expect(out).toEqual({ x: 200, y: 0, width: 1440, height: 900 });
      });

      it('caps height at 900 and centers it, if taller', () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({
          workAreaSize: { width: 1440, height: 1100 },
        });

        const out = AppEnv.getDefaultWindowDimensions();
        expect(out).toEqual({ x: 0, y: 100, width: 1440, height: 900 });
      });

      it("returns only the max viewport size if it's smaller than the defaults", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({
          workAreaSize: { width: 1000, height: 800 },
        });

        const out = AppEnv.getDefaultWindowDimensions();
        expect(out).toEqual({ x: 0, y: 0, width: 1000, height: 800 });
      });

      it('always rounds X and Y', () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({
          workAreaSize: { width: 1845, height: 955 },
        });

        const out = AppEnv.getDefaultWindowDimensions();
        expect(out).toEqual({ x: 202, y: 27, width: 1440, height: 900 });
      });
    });
  });

  describe('.isReleasedVersion()', () =>
    it('returns false if the version is a SHA and true otherwise', () => {
      let version = '0.1.0';
      spyOn(AppEnv, 'getVersion').andCallFake(() => version);
      expect(AppEnv.isReleasedVersion()).toBe(true);
      version = '36b5518';
      expect(AppEnv.isReleasedVersion()).toBe(false);
    }));

  describe('when an update becomes available', () => {
    let subscription = null;

    afterEach(() => {
      if (subscription) {
        subscription.dispose();
      }
    });

    it('invokes onUpdateAvailable listeners', () => {
      if (process.platform === 'linux') {
        return;
      }

      const updateAvailableHandler = jasmine.createSpy('update-available-handler');
      subscription = AppEnv.onUpdateAvailable(updateAvailableHandler);

      remote.autoUpdater.emit('update-downloaded', null, 'notes', 'version');

      waitsFor(() => updateAvailableHandler.callCount > 0);

      runs(() => {
        const { releaseVersion, releaseNotes } = updateAvailableHandler.mostRecentCall.args[0];
        expect(releaseVersion).toBe('version');
        expect(releaseNotes).toBe('notes');
      });
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      spyOn(AppEnv, 'inSpecMode').andReturn(false);
      spyOn(AppEnv, 'inDevMode').andReturn(false);
      spyOn(AppEnv, 'openDevTools');
      spyOn(AppEnv, 'executeJavaScriptInDevTools');
      spyOn(AppEnv.errorLogger, 'reportError');
    });

    it('Catches errors that make it to window.onerror', () => {
      spyOn(AppEnv, 'reportError');
      const e = new Error('Test Error');
      window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
      expect(AppEnv.reportError).toHaveBeenCalled();
      expect(AppEnv.reportError.calls[0].args[0]).toBe(e);
      const extra = AppEnv.reportError.calls[0].args[1];
      expect(extra.url).toBe('abc');
      expect(extra.line).toBe(2);
      expect(extra.column).toBe(3);
    });

    it('Catches unhandled rejections', async () => {
      spyOn(AppEnv, 'reportError');
      const err = new Error('TEST');

      const p = new Promise((resolve, reject) => {
        reject(err);
      });
      p.then(() => {
        throw new Error("Shouldn't resolve");
      });

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
      await new Promise(resolve => {
        window.originalSetTimeout(resolve, 0);
      });

      expect(AppEnv.reportError.callCount).toBe(1);
      expect(AppEnv.reportError.calls[0].args[0]).toBe(err);
    });

    describe('reportError', () => {
      beforeEach(() => {
        this.testErr = new Error('Test');
        spyOn(console, 'error');
      });

      it('opens dev tools in dev mode', () => {
        jasmine.unspy(AppEnv, 'inDevMode');
        spyOn(AppEnv, 'inDevMode').andReturn(true);
        AppEnv.reportError(this.testErr);
        expect(AppEnv.openDevTools).toHaveBeenCalled();
        expect(AppEnv.executeJavaScriptInDevTools).toHaveBeenCalled();
      });

      it('sends the error report to the error logger', () => {
        AppEnv.reportError(this.testErr);
        expect(AppEnv.errorLogger.reportError).toHaveBeenCalled();
        expect(AppEnv.errorLogger.reportError.callCount).toBe(1);
        expect(AppEnv.errorLogger.reportError.calls[0].args[0]).toBe(this.testErr);
      });
    });
  });
});
