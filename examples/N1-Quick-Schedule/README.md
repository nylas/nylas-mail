# QuickSchedule

This is a package that allows you to email times that you are free to other people to make it easier to schedule appointments. The package adds a "QuickSchedule" button next to the "Send" button. The button opens a calendar, in which you can select time periods to email to other people. When the recipient clicks a link to a specific time, the event is scheduled immediately. Say goodbye to the hassle of scheduling and say hello to QuickSchedule!

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Quick-Schedule/screenshots/quick-schedule-1.png">

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Quick-Schedule/screenshots/quick-schedule-2.png">

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

