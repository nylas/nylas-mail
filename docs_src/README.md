## Nylas Mail Plugin SDK

<center>
<img src="/img/nylas-sdk-cuub@2x.png" width=200/>
</center>

The Nylas SDK allows you to create powerful extensions to Nylas Mail, a mail client for Mac OS X, Windows, and Linux. Building on Nylas Mail saves time and allows you to build innovative new experiences fast.
[Get Started](http://nylas.github.io/nylas-mail/docs/GettingStartedPart1.html)


#### Installing Nylas Mail

Nylas Mail is available for Mac, Windows, and Linux. Download the latest build for your platform below:

*   [Mac OS X](https://edgehill.nylas.com/download?platform=darwin)
*   [Linux](https://edgehill.nylas.com/download?platform=linux)
*   [Windows](https://edgehill.nylas.com/download?platform=win32)


#### Package Architecture

Packages lie at the heart of Nylas Mail. Each part of the core experience is a separate package that uses the Nylas Package API to add functionality to the client. Learn more about packages and create your first package.

*   [Create a Plugin](GettingStarted.md)
*   [Plugin Overview](PackageOverview.html)


#### Dive Deeper

*   [Application Architecture](http://nylas.github.io/nylas-mail/docs/Architecture.html)
*   [React & Component Injection](http://nylas.github.io/nylas-mail/docs/React.html)
*   [Core Interface Concepts](http://nylas.github.io/nylas-mail/docs/InterfaceConcepts.html)
*   [Accessing the Database](http://nylas.github.io/nylas-mail/docs/Database.html)
*   [Draft Store Extensions](http://nylas.github.io/nylas-mail/docs/DraftStoreExtension.html)


#### Debugging Packages

Nylas Mail is built on top of Electron, which runs the latest version of Chromium. Learn how to access debug tools in Electron and use our Developer Tools Extensions:

*   [Debugging in Nylas](http://nylas.github.io/nylas-mail/docs/Debugging.html)

#### Questions?

Need help? Check out the [FAQ](https://support.nylas.com/hc/en-us) or post a question in the [slack channel](http://slack-invite.nylas.com/).


#### Building these docs

Until my patch gets merged, docs need to be built manually using my fork.

    git clone git@github.com:grinich/gitbook.git

    cd nylas-mail

    ./node_modules/.bin/gitbook alias ../gitbook latest

Then to actually build the docs:

    script/grunt docs

    ./node_modules/.bin/gitbook --gitbook=latest build . ./docs



<!-- TODO

Smart Linkify references:
- https://github.com/markomanninen/gitbook-plugin-regexplace
- Figure out why infinitescroll isn't working
- Add examples


 -->
