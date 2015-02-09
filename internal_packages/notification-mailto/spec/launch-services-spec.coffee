_ = require 'underscore-plus'
proxyquire = require 'proxyquire'

stubDefaultsJSON = null
stubDefaults = null
execHitory = []

ChildProcess =
  exec: (command, callback) ->
    execHitory.push(arguments)
    if command is "defaults read com.apple.launchservices LSHandlers"
      callback(null, stubDefaults, null)
    else
      callback(null, '', null)

LaunchServices = proxyquire "../lib/launch-services",
  "child_process":  ChildProcess

describe "LaunchServices", ->
  beforeEach ->
    stubDefaultsJSON = [
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcdoc'
      },
      {
          LSHandlerRoleAll: 'com.fournova.tower',
          LSHandlerURLScheme: 'github-mac'
      },
      {
          LSHandlerRoleAll: 'com.fournova.tower',
          LSHandlerURLScheme: 'sourcetree'
      },
      {
          LSHandlerRoleAll: 'com.google.chrome',
          LSHandlerURLScheme: 'http'
      },
      {
          LSHandlerRoleAll: 'com.google.chrome',
          LSHandlerURLScheme: 'https'
      },
      {
          LSHandlerContentType: 'public.html',
          LSHandlerRoleViewer: 'com.google.chrome'
      },
      {
          LSHandlerContentType: 'public.url',
          LSHandlerRoleViewer: 'com.google.chrome'
      },
      {
          LSHandlerContentType: 'com.apple.ical.backup',
          LSHandlerRoleAll: 'com.apple.ical'
      },
      {
          LSHandlerContentTag: 'icalevent',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.apple.ical'
      },
      {
          LSHandlerContentTag: 'icaltodo',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.apple.reminders'
      },
      {
          LSHandlerRoleAll: 'com.apple.ical',
          LSHandlerURLScheme: 'webcal'
      },
      {
          LSHandlerContentTag: 'coffee',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerRoleAll: 'com.apple.facetime',
          LSHandlerURLScheme: 'facetime'
      },
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcdevice'
      },
      {
          LSHandlerContentType: 'public.png',
          LSHandlerRoleAll: 'com.macromedia.fireworks'
      },
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcbot'
      },
      {
          LSHandlerRoleAll: 'com.microsoft.rdc.mac',
          LSHandlerURLScheme: 'rdp'
      },
      {
          LSHandlerContentTag: 'rdp',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.microsoft.rdc.mac'
      },
      {
          LSHandlerContentType: 'public.json',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerContentTag: 'cson',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerRoleAll: 'com.apple.mail',
          LSHandlerURLScheme: 'mailto'
      }
    ]
    stubDefaults = """
    (
            {
            LSHandlerRoleAll = "com.apple.dt.xcode";
            LSHandlerURLScheme = xcdoc;
        },
            {
            LSHandlerRoleAll = "com.fournova.tower";
            LSHandlerURLScheme = "github-mac";
        },
            {
            LSHandlerRoleAll = "com.fournova.tower";
            LSHandlerURLScheme = sourcetree;
        },
            {
            LSHandlerRoleAll = "com.google.chrome";
            LSHandlerURLScheme = http;
        },
            {
            LSHandlerRoleAll = "com.google.chrome";
            LSHandlerURLScheme = https;
        },
            {
            LSHandlerContentType = "public.html";
            LSHandlerRoleViewer = "com.google.chrome";
        },
            {
            LSHandlerContentType = "public.url";
            LSHandlerRoleViewer = "com.google.chrome";
        },
            {
            LSHandlerContentType = "com.apple.ical.backup";
            LSHandlerRoleAll = "com.apple.ical";
        },
            {
            LSHandlerContentTag = icalevent;
            LSHandlerContentTagClass = "public.filename-extension";
            LSHandlerRoleAll = "com.apple.ical";
        },
            {
            LSHandlerContentTag = icaltodo;
            LSHandlerContentTagClass = "public.filename-extension";
            LSHandlerRoleAll = "com.apple.reminders";
        },
            {
            LSHandlerRoleAll = "com.apple.ical";
            LSHandlerURLScheme = webcal;
        },
            {
            LSHandlerContentTag = coffee;
            LSHandlerContentTagClass = "public.filename-extension";
            LSHandlerRoleAll = "com.sublimetext.2";
        },
            {
            LSHandlerRoleAll = "com.apple.facetime";
            LSHandlerURLScheme = facetime;
        },
            {
            LSHandlerRoleAll = "com.apple.dt.xcode";
            LSHandlerURLScheme = xcdevice;
        },
            {
            LSHandlerContentType = "public.png";
            LSHandlerRoleAll = "com.macromedia.fireworks";
        },
            {
            LSHandlerRoleAll = "com.apple.dt.xcode";
            LSHandlerURLScheme = xcbot;
        },
            {
            LSHandlerRoleAll = "com.microsoft.rdc.mac";
            LSHandlerURLScheme = rdp;
        },
            {
            LSHandlerContentTag = rdp;
            LSHandlerContentTagClass = "public.filename-extension";
            LSHandlerRoleAll = "com.microsoft.rdc.mac";
        },
            {
            LSHandlerContentType = "public.json";
            LSHandlerRoleAll = "com.sublimetext.2";
        },
            {
            LSHandlerContentTag = cson;
            LSHandlerContentTagClass = "public.filename-extension";
            LSHandlerRoleAll = "com.sublimetext.2";
        },
            {
            LSHandlerRoleAll = "com.apple.mail";
            LSHandlerURLScheme = mailto;
        }
    )
    """

  describe "when the platform is darwin", ->
    beforeEach ->
      execHitory = []
      @services = new LaunchServices()
      @services.getPlatform = -> 'darwin'

    describe "available", ->
      it "should return true", ->
        expect(@services.available()).toEqual(true)

    describe "pre-Yosemite", ->
      beforeEach ->
        @services.isYosemiteOrGreater = (callback) -> callback(false)

      describe "readDefaults", ->
        it "should return the user defaults registered with the system via `defaults`", ->
          response = null
          runs ->
            @services.readDefaults (defaults) ->
              response = defaults
          waitsFor ->
            response
          runs ->
            expect(response).toEqual(stubDefaultsJSON)

      describe "writeDefaults", ->
        it "should covert the defaults to the plist format and call `defaults write`", ->
          callback = jasmine.createSpy('callback')
          @services.writeDefaults(stubDefaultsJSON, callback)
          command = execHitory[0][0]
          expect(command).toBe("""defaults write ~/Library/Preferences/com.apple.LaunchServices.plist LSHandlers '({LSHandlerRoleAll = "com.apple.dt.xcode";LSHandlerURLScheme = "xcdoc";},{LSHandlerRoleAll = "com.fournova.tower";LSHandlerURLScheme = "github-mac";},{LSHandlerRoleAll = "com.fournova.tower";LSHandlerURLScheme = "sourcetree";},{LSHandlerRoleAll = "com.google.chrome";LSHandlerURLScheme = "http";},{LSHandlerRoleAll = "com.google.chrome";LSHandlerURLScheme = "https";},{LSHandlerContentType = "public.html";LSHandlerRoleViewer = "com.google.chrome";},{LSHandlerContentType = "public.url";LSHandlerRoleViewer = "com.google.chrome";},{LSHandlerContentType = "com.apple.ical.backup";LSHandlerRoleAll = "com.apple.ical";},{LSHandlerContentTag = "icalevent";LSHandlerContentTagClass = "public.filename-extension";LSHandlerRoleAll = "com.apple.ical";},{LSHandlerContentTag = "icaltodo";LSHandlerContentTagClass = "public.filename-extension";LSHandlerRoleAll = "com.apple.reminders";},{LSHandlerRoleAll = "com.apple.ical";LSHandlerURLScheme = "webcal";},{LSHandlerContentTag = "coffee";LSHandlerContentTagClass = "public.filename-extension";LSHandlerRoleAll = "com.sublimetext.2";},{LSHandlerRoleAll = "com.apple.facetime";LSHandlerURLScheme = "facetime";},{LSHandlerRoleAll = "com.apple.dt.xcode";LSHandlerURLScheme = "xcdevice";},{LSHandlerContentType = "public.png";LSHandlerRoleAll = "com.macromedia.fireworks";},{LSHandlerRoleAll = "com.apple.dt.xcode";LSHandlerURLScheme = "xcbot";},{LSHandlerRoleAll = "com.microsoft.rdc.mac";LSHandlerURLScheme = "rdp";},{LSHandlerContentTag = "rdp";LSHandlerContentTagClass = "public.filename-extension";LSHandlerRoleAll = "com.microsoft.rdc.mac";},{LSHandlerContentType = "public.json";LSHandlerRoleAll = "com.sublimetext.2";},{LSHandlerContentTag = "cson";LSHandlerContentTagClass = "public.filename-extension";LSHandlerRoleAll = "com.sublimetext.2";},{LSHandlerRoleAll = "com.apple.mail";LSHandlerURLScheme = "mailto";})'""")

        it "should `lsregister` to reload defaults after saving them", ->
          callback = jasmine.createSpy('callback')
          @services.writeDefaults(stubDefaultsJSON, callback)
          command = execHitory[1][0]
          expect(command).toBe("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user")

      describe "isRegisteredForURLScheme", ->
        it "should require a callback is provided", ->
          expect( -> @services.isRegisteredForURLScheme('mailto')).toThrow()

        it "should return true if a matching `LSHandlerURLScheme` record exists for the bundle identifier", ->
          stubDefaults = """
            (
                {
                    LSHandlerRoleAll = "com.apple.dt.xcode";
                    LSHandlerURLScheme = xcdoc;
                },
                {
                    LSHandlerContentTag = cson;
                    LSHandlerContentTagClass = "public.filename-extension";
                    LSHandlerRoleAll = "com.sublimetext.2";
                },
                {
                    LSHandlerRoleAll = "com.inbox.edgehill";
                    LSHandlerURLScheme = mailto;
                }
            )
            """
          @services.isRegisteredForURLScheme 'mailto', (registered) ->
            expect(registered).toBe(true)

        it "should return false when other records exist for the bundle identifier but do not match", ->
          stubDefaults = """
            (
                {
                    LSHandlerRoleAll = "com.apple.dt.xcode";
                    LSHandlerURLScheme = xcdoc;
                },
                {
                    LSHandlerContentTag = cson;
                    LSHandlerContentTagClass = "public.filename-extension";
                    LSHandlerRoleAll = "com.sublimetext.2";
                },
                {
                    LSHandlerRoleAll = "com.inbox.edgehill";
                    LSHandlerURLScheme = atom;
                }
            )
            """
          @services.isRegisteredForURLScheme 'mailto', (registered) ->
            expect(registered).toBe(false)

        it "should return false if another bundle identifier is registered for the `LSHandlerURLScheme`", ->
          stubDefaults = """
            (
                {
                    LSHandlerRoleAll = "com.apple.dt.xcode";
                    LSHandlerURLScheme = xcdoc;
                },
                {
                    LSHandlerContentTag = cson;
                    LSHandlerContentTagClass = "public.filename-extension";
                    LSHandlerRoleAll = "com.sublimetext.2";
                },
                {
                    LSHandlerRoleAll = "com.apple.mail";
                    LSHandlerURLScheme = mailto;
                }
            )
            """
          @services.isRegisteredForURLScheme 'mailto', (registered) ->
            expect(registered).toBe(false)

      describe "registerForURLScheme", ->
        it "should remove any existing records for the `LSHandlerURLScheme`", ->
          @services.registerForURLScheme 'mailto', =>
            @services.readDefaults (values) ->
              expect(JSON.stringify(values).indexOf('com.apple.mail')).toBe(-1)

        it "should add a record for the `LSHandlerURLScheme` and the app's bundle identifier", ->
          @services.registerForURLScheme 'mailto', =>
            @services.readDefaults (defaults) ->
              match = _.find defaults, (d) ->
                d.LSHandlerURLScheme is 'mailto' and d.LSHandlerRoleAll is 'com.inbox.edgehill'
              expect(match).not.toBe(null)

        it "should write the new defaults", ->
          spyOn(@services, 'writeDefaults')
          @services.registerForURLScheme('mailto')
          expect(@services.writeDefaults).toHaveBeenCalled()

  describe "on other platforms", ->
    describe "available", ->
      beforeEach ->
        @services = new LaunchServices()
        @services.getPlatform = -> 'win32'

      it "should return false", ->
        expect(@services.available()).toEqual(false)
