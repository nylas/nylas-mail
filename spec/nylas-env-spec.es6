import { remote } from 'electron';

describe("the `NylasEnv` global", function nylasEnvSpec() {
  describe('window sizing methods', () => {
    describe('::getPosition and ::setPosition', () =>
      it('sets the position of the window, and can retrieve the position just set', () => {
        NylasEnv.setPosition(22, 45);
        return expect(NylasEnv.getPosition()).toEqual({x: 22, y: 45});
      })
    );

    describe('::getSize and ::setSize', () => {
      beforeEach(() => {
        this.originalSize = NylasEnv.getSize()
      });
      afterEach(() => NylasEnv.setSize(this.originalSize.width, this.originalSize.height));

      return it('sets the size of the window, and can retrieve the size just set', () => {
        NylasEnv.setSize(100, 400);
        return expect(NylasEnv.getSize()).toEqual({width: 100, height: 400});
      });
    });

    describe('::setMinimumWidth', () => {
      const win = NylasEnv.getCurrentWindow();

      it("sets the minimum width", () => {
        const inputMinWidth = 500;
        win.setMinimumSize(1000, 1000);

        NylasEnv.setMinimumWidth(inputMinWidth);

        const [actualMinWidth] = win.getMinimumSize();
        return expect(actualMinWidth).toBe(inputMinWidth);
      });

      return it("sets the current size if minWidth > current width", () => {
        const inputMinWidth = 1000;
        win.setSize(500, 500);

        NylasEnv.setMinimumWidth(inputMinWidth);

        const [actualWidth] = win.getMinimumSize();
        return expect(actualWidth).toBe(inputMinWidth);
      });
    });

    return describe('::getDefaultWindowDimensions', () => {
      it("returns primary display's work area size if it's small enough", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1440, height: 900}});

        const out = NylasEnv.getDefaultWindowDimensions();
        return expect(out).toEqual({x: 0, y: 0, width: 1440, height: 900});
      });

      it("caps width at 1440 and centers it, if wider", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1840, height: 900}});

        const out = NylasEnv.getDefaultWindowDimensions();
        return expect(out).toEqual({x: 200, y: 0, width: 1440, height: 900});
      });

      it("caps height at 900 and centers it, if taller", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1440, height: 1100}});

        const out = NylasEnv.getDefaultWindowDimensions();
        return expect(out).toEqual({x: 0, y: 100, width: 1440, height: 900});
      });

      it("returns only the max viewport size if it's smaller than the defaults", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1000, height: 800}});

        const out = NylasEnv.getDefaultWindowDimensions();
        return expect(out).toEqual({x: 0, y: 0, width: 1000, height: 800});
      });

      return it("always rounds X and Y", () => {
        spyOn(remote.screen, 'getPrimaryDisplay').andReturn({workAreaSize: { width: 1845, height: 955}});

        const out = NylasEnv.getDefaultWindowDimensions();
        return expect(out).toEqual({x: 202, y: 27, width: 1440, height: 900});
      });
    });
  });


  describe(".isReleasedVersion()", () =>
    it("returns false if the version is a SHA and true otherwise", () => {
      let version = '0.1.0';
      spyOn(NylasEnv, 'getVersion').andCallFake(() => version);
      expect(NylasEnv.isReleasedVersion()).toBe(true);
      version = '36b5518';
      return expect(NylasEnv.isReleasedVersion()).toBe(false);
    })
  );

  xdescribe("when an update becomes available", () => {
    let subscription = null;

    afterEach(() => {
      if (subscription) { subscription.dispose(); }
    });

    return it("invokes onUpdateAvailable listeners", () => {
      const updateAvailableHandler = jasmine.createSpy("update-available-handler");
      subscription = NylasEnv.onUpdateAvailable(updateAvailableHandler);

      remote.autoUpdater.emit('update-downloaded', null, "notes", "version");

      waitsFor(() => updateAvailableHandler.callCount > 0);

      return runs(() => {
        const {releaseVersion, releaseNotes} = updateAvailableHandler.mostRecentCall.args[0];
        expect(releaseVersion).toBe('version');
        return expect(releaseNotes).toBe('notes');
      });
    });
  });

  xdescribe("loading default config", () =>
    it('loads the default core config', () => {
      expect(NylasEnv.config.get('core.excludeVcsIgnoredPaths')).toBe(true);
      expect(NylasEnv.config.get('core.followSymlinks')).toBe(false);
      return expect(NylasEnv.config.get('editor.showInvisibles')).toBe(false);
    })
  );

  return xdescribe("window onerror handler", () => {
    beforeEach(() => {
      spyOn(NylasEnv, 'openDevTools');
      return spyOn(NylasEnv, 'executeJavaScriptInDevTools');
    });

    it("will open the dev tools when an error is triggered", () => {
      try {
        throw new Error("Test");
      } catch (e) {
        window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
      }

      expect(NylasEnv.openDevTools).toHaveBeenCalled();
      return expect(NylasEnv.executeJavaScriptInDevTools).toHaveBeenCalled();
    });

    describe("::onWillThrowError", () => {
      let willThrowSpy = null;
      beforeEach(() => {
        willThrowSpy = jasmine.createSpy()
      });

      it("is called when there is an error", () => {
        let error = null;
        NylasEnv.onWillThrowError(willThrowSpy);
        try {
          throw new Error("Test");
        } catch (e) {
          error = e;
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
        }

        delete willThrowSpy.mostRecentCall.args[0].preventDefault;
        return expect(willThrowSpy).toHaveBeenCalledWith({
          message: error.toString(),
          url: 'abc',
          line: 2,
          column: 3,
          originalError: error,
        });
      });

      return it("will not show the devtools when preventDefault() is called", () => {
        willThrowSpy.andCallFake(errorObject => errorObject.preventDefault());
        NylasEnv.onWillThrowError(willThrowSpy);

        try {
          throw new Error("Test");
        } catch (e) {
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
        }

        expect(willThrowSpy).toHaveBeenCalled();
        expect(NylasEnv.openDevTools).not.toHaveBeenCalled();
        return expect(NylasEnv.executeJavaScriptInDevTools).not.toHaveBeenCalled();
      });
    });

    return describe("::onDidThrowError", () => {
      let didThrowSpy = null;
      beforeEach(() => {
        didThrowSpy = jasmine.createSpy()
      });

      return it("is called when there is an error", () => {
        let error = null;
        NylasEnv.onDidThrowError(didThrowSpy);
        try {
          throw new Error("Test");
        } catch (e) {
          error = e;
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e);
        }
        return expect(didThrowSpy).toHaveBeenCalledWith({
          message: error.toString(),
          url: 'abc',
          line: 2,
          column: 3,
          originalError: error,
        });
      });
    });
  });
});
