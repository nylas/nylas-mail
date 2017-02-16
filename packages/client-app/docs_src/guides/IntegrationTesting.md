# Integration Testing

In addition to unit tests, we run integration tests using
[ChromeDriver](https://code.google.com/p/selenium/wiki/ChromeDriver) and
[WebdriverIO](http://webdriver.io/) through the
[Spectron](https://github.com/kevinsawicki/spectron) library.

## Running Tests

    script/grunt run-integration-tests

This command will, in order:

1. Run `npm test` in the `/spec_integration` directory and pass in the
   `NYLAS_ROOT_PATH`
1. Boot `jasmine` and load all files ending in `-spec`
1. Most tests in `beforeAll` will boot N1 via the `N1Launcher`. See
   `spec_integration/helpers/n1-launcher.es6`
1. This instantiates a new `spectron` `Application` which will spawn a
   `ChromeDriver` process with the appropriate N1 launch args.
1. `ChromeDriver` will then boot a [Selenium](http://www.seleniumhq.org/)
   server at `http://localhost:9515`
1. The ChromeDriver / Selenium server will boot N1 with testing hooks and
   expose an controlling API.
1. The API is made easily available through the [Spectron API](https://github.com/kevinsawicki/spectron/blob/master/README.md)
1. The `N1Launcher`'s `mainWindowReady` or `popoutComposerWindowReady` or
   `onboardingWindowReady` methods poll the app until the designated
   window is available and loaded. Then will resolve a Promise once
   everything has booted.

## Writing Tests

The [Spectron API](https://github.com/kevinsawicki/spectron/blob/master/README.md) is a pure extension over the [Webdriver API](http://webdriver.io/api.html). Reference both to write tests.

Most of the methods on `app.client` object apply to the "currently
focused" window only. Since N1 has several windows (many of which are
hidden) the `N1Launcher` extension will cycle through windows
automatically until it finds the one you want, and then select it.

Furthermore, "loaded" in the pure Spectron sense is only once the window
is booted. N1 windows take much longer to full finish loading packages and
rendering the UI. The `N1Launcher::windowReady` method and its derivatives
take this into account.

You will almost always need the minimal boilerplate for each integration
test:

```javascript
describe('My test', () => {
  beforeAll((done)=>{
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(["--dev"]);
    this.app.mainWindowReady().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().finally(done);
    } else {
      done()
    }
  });

  it("is a test you'll write", () => {
  });

  it("is an async test you'll write", (done) => {
    doSomething.finally(done)
  });
});
```

### Executing Code in N1's environment

The `app.client.execute` and `app.client.executeAsync` methods are
extremely helpful when running code in N1. Those are documented slightly
more on the [WebdriveIO API docs page here](http://webdriver.io/api/protocol/execute.html)

```javascript
it("is a test you'll write", () => {
  this.app.client.execute((arg1)=>{
    // NOTE: `arg1` just got passed in over a JSON api. It can only be a
    // primitive data type

    // I'M RUNNING IN N1
    return someValue

  }, arg1).then(({value})=>{
    // NOTE: the return is stuffed in an attribute called `value`. Also it
    // passed back of a JSON API and can only be a primitive value.
  })
});
```

### Debugging tests.

Debugging is through lots of `console.log`ing.

There is code is `spec_integration/jasmine/bootstrap.js` that attempts to
catch unhandled Promises and color them accordingly.

If you want to access logs from within N1 via the `app.client.execute`
blocks, you'll have to either package it up yourself and return it, or use
the new `app.client.getMainProcessLogs()` just added into Spectron.
