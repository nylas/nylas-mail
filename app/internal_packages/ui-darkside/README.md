# Darkside
**An dark sidebar theme for [Mailspring](https://getmailspring.com). Created by [Jamie Wilson](http://jamiewilson.io)**

#### Customize

> **Open the theme directory**  
> If you're on a Mac, you can find the theme files at `/Library/Application Support/Mailspring/packages`. To get there quickly, use the key command <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd> and enter `/Library/Application Support/Mailspring/packages`.

> **Change package.json**  
> In order to avoid conflicts between your custom theme and the pre-installed version, change `name` and `displayName` in `package.json` to:

    "name": "ui-darkside-custom",
    "displayName": "Darkside Custom",

> **Edit LESS files**  
> Open the `ui-variables.less` file. To change colors, just comment out the default `@sidebar` and `@accent` variables and uncomment another theme or simply replace with your own colors.

```sass
// Default
@sidebar: #313042;
@accent: #F18260;

// Luna
// @sidebar: #202C46;
// @accent: #39DFF8;

// Zond
// @sidebar: #333333;
// @accent: #F6D49C;

// Gemini
// @sidebar: #00203C;
// @accent: #F6B312;

// Mercury
// @sidebar: #555;
// @accent: #999;

// Apollo
// @sidebar: #3A1E15;
// @accent: #F6AA1C;
```

### Feedback
If you have questions or suggestions, please submit an issue. If you need to, you can email me at [jamie@jamiewilson.io](mailto:jamie@jamiewilson?subject=Re: Darkside).
