# N1-Unsubscribe (Nylas Plugin)

Quickly unsubscribe from emails without leaving N1

![UnsubscribePromoVideo][promo_video]

## The Plugin Magic

N1-Unsubscribe acts in one of two ways. First, it looks if it can unsubscribe via email. If it can, the plugin will send an unsubscribe request email on your behalf. Second, if no email is available, the plugin looks for a link in the body of the email, such as "click to unsubscribe." The plugin can then open the link in a mini-browser to complete the unsubscription without leaving Nylas. When unsubscribed, the email is then trashed or archived based on your selected option ([see settings below][settings]).

## The Icons

- ![Loading][Loading] Loading -- wait for a moment for the icon to update
- ![Unsubscribe][Unsubscribe] Ready to unsubscribe and waiting on your click
- ![Success][Success] You are now unsubscribed!
- ![Error][Error] When something goes wrong, you will get this error icon. Make sure to forward us the email causing you problems to [n1.unsubscribe@gmail.com](mailto:n1.unsubscribe@gmail.com) and we will try to see what went wrong!

## Keyboard Shortcuts

N1-Unsubscribe now supports keyboard shortcuts! Press <kbd>CMD</kbd> + <kbd>ALT</kbd> + <kbd>U</kbd> when viewing a single email instead of pressing the button. Unsubscribing couldn't be faster. If you want to map your own shortcut keys:

1. Go to:`Nylas->Preferences`
2. Click the `shortcuts` tab
3. Then scroll to the bottom and click the `Edit Custom Shortcuts` button
4. From the finder window, open keymap.json in a text editor and add this snippet (replace `mod+j` with whatever shortcut you want - note mod is the super key on a Mac/PC):

    For keymap.json:
    ```json
    {
      "n1-unsubscribe:unsubscribe": "mod+j"
    }
    ```
    **Alternatively** if you use Keymap.cson, you know what to do!

## Reporting Bugs

- **Feature Requests or Bug Reports**: Submit them through the [issues pane][issues] and make sure to tag @KingBrothers - [the plugin is written and actively maintained by two brothers, so tagging us gets you help faster!]
- **Mishandled Emails**: Find something that doesn't work (not finding an unsubscribe link, etc.)? Forward the email to us at <a href="mailto:n1.unsubscribe@gmail.com">n1.unsubscribe@gmail.com</a> and we will look into it## Archived Information

### Settings - Only available when running N1 from source right now

Certain features for this package can be toggled by changing the appropriate settings from within `unsubscribe-settings.json`. The settings file isn't tracked, so once you edit it, your preferences will be saved even when updating N1. You can see the default file here: [`unsubscribe-settings.defaults.json`][settings_file].

To change any of these settings, you need to have N1 running from source, since the settings file isn't accessible from the distribution version of N1. If you have access to the source files, modify `N1/internal_packages/n1-unsubscribe/unsubscribe-settings.json`. To implement the settings update, reload N1 with <kbd>Alt</kbd> + <kbd>Cmd</kbd> + <kbd>L</kbd>, `Developer > Reload`, or just quit and restart N1.

- **use_browser**: Toggle between opening web-based unsubscribe links in your native browser or an in-app pop-up window (default: pop-up).
- **handle_threads**: Toggle between automatically archiving, trashing or not moving your email anywhere after unsubscribing (default: archive).
- **confirm_for_email**: Toggle a confirmation box on or off before sending an automatic unsubscribe email (default: off).
- **confirm_for_browser**: Toggle a confirmation box on or off before opening a browser window to unsubscribe from an email (default: off).
- **debug**: Toggle maximum debug info. This will allow you to see all of the logs other than just the errors (default: off).

More documentation of these toggles is available in the [`unsubscribe-settings.defaults.json`][settings_file].

## Made by

[Kyle King](http://kyleking.me) and [Colin King](http://colinking.co)

[promo_video]: internal_packages/n1-unsubscribe/.github/UnsubscribePromoVideo.gif

<!-- Links -->

[issues]: https://github.com/nylas/N1/issues
[settings]: https://github.com/nylas/N1/tree/master/internal_packages/n1-unsubscribe#settings
[settings_file]: internal_packages/n1-unsubscribe/unsubscribe-settings.defaults.json

<!-- Icons -->

[Loading]: internal_packages/n1-unsubscribe/assets/unsubscribe-loading@2x.png
[Unsubscribe]: internal_packages/n1-unsubscribe/assets/unsubscribe@2x.png)
[Success]: internal_packages/n1-unsubscribe/assets/unsubscribe-success@2x.png
[Error]: internal_packages/n1-unsubscribe/assets/unsubscribe-error@2x.png