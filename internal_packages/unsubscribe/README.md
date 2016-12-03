![plugin page](plugin.png)

Quickly unsubscribe from emails without leaving N1. Automatically detects unsubscribe methods (email or browser) from the email headers (`list-unsubscribe` header) or the email body. If you can be automatically unsubscribed, this package will do that, else it will open an electron browser window.

## Keyboard Shortcuts

Press <kbd>CMD</kbd> + <kbd>ALT</kbd> + <kbd>U</kbd> when viewing an email. If you want to map your own shortcut keys:

1. Go to:`Nylas->Preferences`
2. Click the `shortcuts` tab
3. Then scroll to the bottom and click the `Edit Custom Shortcuts` button
4. From the finder window, open `keymap.json` in a text editor and add this snippet (replace `mod+j` with whatever shortcut you want - note: mod is the alt key on a Mac/PC):

	```json
		{
		  "unsubscribe:unsubscribe": "mod+j"
		}
	```

## Reporting Bugs

- **Feature Requests or Bug Reports**: Submit them through the [issues](issues) pane.
- **Mishandled Emails**: Find an email which this plugin doesn't handle correctly (not finding an unsubscribe link, etc.)? Forward the email to us at <a href="mailto:n1.unsubscribe@gmail.com">n1.unsubscribe@gmail.com</a> and we will look into it.

### Settings - Only available when running N1 from source right now

Certain features for this package can be toggled by changing the appropriate settings from within `unsubscribe-settings.json`. The settings file isn't tracked, so once you edit it, your preferences will be saved even when updating N1. You can see the default file here: [`unsubscribe-settings.defaults.json`](unsubscribe-settings.defaults.json).

To change any of these settings, you need to have N1 running from source, since the settings file isn't accessible from the distribution version of N1. If you have access to the source files, modify `N1/internal_packages/unsubscribe/unsubscribe-settings.json`. To implement the settings update, reload N1 with <kbd>Alt</kbd> + <kbd>Cmd</kbd> + <kbd>L</kbd>, `Developer > Reload`, or just quit and restart N1.

- **use_browser**: Toggle between opening web-based unsubscribe links in your native browser or an in-app pop-up window (default: pop-up).
- **handle_threads**: Toggle between automatically archiving, trashing or not moving your email anywhere after unsubscribing (default: archive).
- **confirm_for_email**: Toggle a confirmation box on or off before sending an automatic unsubscribe email (default: off).
- **confirm_for_browser**: Toggle a confirmation box on or off before opening a browser window to unsubscribe from an email (default: off).
- **debug**: Toggle maximum debug info. This will allow you to see all of the logs other than just the errors (default: off).

More documentation of these toggles is available in [`unsubscribe-settings.defaults.json`](unsubscribe-settings.defaults.json).

## Made by

[Kyle King](http://kyleking.me) and [Colin King](http://colinking.co)
