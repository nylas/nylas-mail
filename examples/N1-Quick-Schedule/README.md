# QuickSchedule

Say goodbye to the hassle of scheduling! This new plugin lets you avoid the typical back-and-forth of picking a time to meet. Just select a few options, and your recipient confirms with one click. It's the best way to instantly schedule meetings.

This plugin works by adding a small "QuickSchedule" button next to the Send button in the composer. Clicking the button will open a calendar where you can select potential times to meet. These times are placed in the draft, and your recipient can confirm a time with one click. It even automatically adds the event to both calendars! 

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Quick-Schedule/screenshots/quick-schedule-3.png">

### How to install this plugin

1. [Download and run N1](https://nylas.com/n1)

2. From the menu, select `Developer > Install a Package Manually...`
   The dialog will default to this examples directory. Choose the
   `N1-Quick-Schedule` folder to install it!

   > Note: When you install plugins, they're moved to `~/.nylas/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`


#### Who is this for?

Anyone who makes a lot of appointments! If you are a developer, this is also a great example of a more complicated plugin that requires a backend service, and demonstrates how arbitrary JavaScript can be inserted to create custom functionality.

