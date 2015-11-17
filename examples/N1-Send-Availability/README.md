# Send availability

This is a package that allows you to email times that you are free to other people to make it easier to schedule appointments. The package adds an "Add Availability" button next to the "Send" button. The button opens a calendar, in which you can select time periods to email to other people.

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Send-Availability/screenshots/send-availability-1.png">

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Send-Availability/screenshots/send-availability-2.png">

#### Install this plugin

1. Download and run N1

2. From the menu, select `Developer > Install a Package Manually...`
   The dialog will default to this examples directory. Just choose the
   package to install it!

   > When you install packages, they're moved to `~/.nylas/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`


#### Who?

This package annotated for those who are familiar with React, Flux already, and have already seen other N1 packages. This package is more complicated than the other packages, as it demonstrates how arbitrary JavaScript can be inserted to create custom functionality.

#### Why?

When making appointments with other people, you need to share your availabilities in order to schedule a time.
