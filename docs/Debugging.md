---
Title:   Debugging N1
Section: Guides
Order:   4
---

### Chromium DevTools

N1 is built on top of Electron, which runs the latest version of Chromium (at the time of writing, Chromium 43). You can access the standard [Chrome DevTools](https://developer.chrome.com/devtools) using the `Command-Option-I` (`Ctrl-Shift-I` on Windows/Linux) keyboard shortcut, including the Debugger, Profiler, and Console. You can find extensive information about the Chromium DevTools on [developer.chrome.com](https://developer.chrome.com/devtools).

Here are a few hidden tricks for getting the most out of the Chromium DevTools:

- You can use `Command-P` to "Open Quickly", jumping to a particular source file from any tab.

- You can set breakpoints by clicking the line number gutter while viewing a source file.

- While on a breakpoint, you can toggle the console panel by pressing `Esc` and type commands which are executed in the current scope.

- While viewing the DOM in the `Elements` panel, typing `$0` on the console refers to the currently selected DOM node.


### Nylas Developer Panel

If you choose `Developer > Show Activity Window` from the menu, you can see detailed logs of the requests, tasks, and streaming updates processed by N1.

The Developer Panel provides three views which you can click to activate:

- `Tasks`: This view allows you to inspect the {TaskQueue} and see the what tasks are pending and complete. Click a task to see its JSON representation and inspect it's values, including the last error it encountered.

- `Long Polling`: This view allows you to see the streaming updates from the Nylas API that the app has received. You can click individual updates to see the exact JSON that was consumed by the app, and search in the lower left for updates pertaining to an object ID or type.

- `Requests`: This view shows the requests the app has made to the Nylas API in `curl`-equivalent form. (The app does not actually make `curl` requests). You can click "Copy" to copy a `curl` command to the clipboard, or "Run" to execute it in a new Terminal window.

The Developer Panel also allows you to toggle "View Component Regions". Turning on component regions adds a red border to areas of the app that render dynamically injected components, and shows the props passed to React components in each one. See {react} for more information.

### The Development Workflow

If you're debugging a package, you'll be modifying your code and re-running N1 over and over again. There are a few things you can do to make this development workflow less time consuming:

- **Inline Changes**: Using the Chromium DevTools, you can change the contents of your coffeescript and javascript source files, type `Command-S` to save, and hot-swap the code. This makes it easy to test small adjustments to your code without re-launching N1.

- **View > Refresh**: From the View menu, choose "Refresh" to reload the N1 window just like a page in your browser. Refreshing is faster than restarting the app and allows you to iterate more quickly.

 > Note: A bug in Electron causes the Chromium DevTools to become detatched if you refresh the app often. If you find that Chromium is not stopping at your breakpoints, quit N1 and re-launch it.

In the future, we'll support much richer hot-reloading of plugin components and code. Stay tuned!
