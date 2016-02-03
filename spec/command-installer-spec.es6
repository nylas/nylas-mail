import CommandInstaller from '../src/command-installer'
import fs from 'fs-plus'

describe("CommandInstaller", () => {
  beforeEach(() => {
    this.resourcePath = "/resourcePath";
    this.callback = jasmine.createSpy('callback')

    spyOn(CommandInstaller, "symlinkCommand").andCallFake((sourcePath, destinationPath, callback) => {
      callback()
    })
  });

  it("Installs N1 if it doesn't already exist", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/N1")
      fn(new Error("not found"), undefined)
    })
    CommandInstaller.installN1Command(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
    expect(this.callback.calls[0].args[0]).toBeUndefined()
  });

  it("Leaves the N1 link alone if exists and is already correct", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/N1")
      fn(null, this.resourcePath + "/N1.sh")
    })
    CommandInstaller.installN1Command(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).not.toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
  });

  it("Overrides the N1 link if it exists but is not correct", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/N1")
      fn(null, this.resourcePath + "/totally/wrong/path")
    })
    CommandInstaller.installN1Command(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
  });

  it("Installs apm if it doesn't already exist", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/apm")
      fn(new Error("not found"), undefined)
    })
    CommandInstaller.installApmCommand(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
    expect(this.callback.calls[0].args[0]).toBeUndefined()
  });

  it("Leaves the apm link alone if exists and is already correct", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/apm")
      fn(null, this.resourcePath + "/apm/node_modules/.bin/apm")
    })
    CommandInstaller.installApmCommand(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).not.toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
  });

  it("Leaves the apm link alone it exists and is not correct since it likely refers to Atom's apm", () => {
    spyOn(fs, "readlink").andCallFake((path, fn) => {
      expect(path).toBe("/usr/local/bin/apm")
      fn(null, this.resourcePath + "/pointing/to/Atom/apm")
    })
    CommandInstaller.installApmCommand(this.resourcePath, false, this.callback)
    expect(CommandInstaller.symlinkCommand).not.toHaveBeenCalled()
    expect(this.callback).toHaveBeenCalled()
  });
});
