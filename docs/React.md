### The Nylas Mail Interface

Nylas Mail uses [React](https://facebook.github.io/react/) to create a fast, responsive UI. Packages that want to extend the Nylas Mail interface should use React. Using React's `JSX` is optional, but both `JSX` and `CJSX` (Coffeescript) are available.

For a quick introduction to React, take a look at Facebook's [Getting Started with React](https://facebook.github.io/react/docs/getting-started.html).

#####Standard React Components

The Nylas Mail client provides a set of core React components you can use in your packages. To use a pre-built component, require it from `ui-components` and wrap it in your own React component. React uses composition rather than inheritance, so your `<ThreadList>` component may render a `<ModelList>` component and pass it function arguments and other `props` to adjust it's behavior.

Many of the standard components listen for key events, include considerations for different platforms, and have extensive CSS. Wrapping standard components makes your package match the rest of Nylas Mail and is encouraged!

Here's a quick look at pre-built components you can require from `ui-components`:

- **Menu**: Allows you to display a list of items consistent with the rest of the Nylas Mail user experience.

- **Spinner**: Displays an indeterminate progress indicator centered within it's container.

- **Popover**: Component for creating menus and popovers that appear in response to a click and stay open until the user clicks outside them.

- **Flexbox**: Component for creating a Flexbox layout.

- **RetinaImg**: Replacement for standard `<img>` tags which automatically resolves the best version of the image for the user's display and can apply many image transforms.

- **ListTabular**: Component for creating a list of items backed by a paginating ModelView.

- **MultiselectList**: Component for creating a list that supports multi-selection. (Internally wraps ListTabular)

- **MultiselectActionBar**: Component for creating a contextual toolbar that is activated when the user makes a selection on a ModelView.

- **ResizableRegion**: Component that renders it's children inside a resizable region with a draggable handle.

- **TokenizingTextField**: Wraps a standard `<input>` and takes function props for tokenizing input values and displaying autocompletion suggestions.

- **EventedIFrame**: Replacement for the standard `<iframe>` tag which handles events directed at the iFrame to ensure a consistent user experience.

### React Component Injection

#####Registering Components

Once you've created components, the next step is to register them with the Component Registry. The Component Registry enables the React component injection that makes Nylas Mail so extensible. You can request that your components appear in a specific `Location`, override a built-in component by re-registering under it's `name`, or register your component for a `Role` that another package has declared.

The Component Registry API will be refined in the months to come. Here are a few examples of how to use it to extend Nylas Mail:

1. Add a component to the bottom of the Thread List column:

```
    ComponentRegistry.register
      view: ThreadList
      name: 'ThreadList'
      location: WorkspaceStore.Location.ThreadList
```

2. Add a component to the footer of the Composer:

```
    ComponentRegistry.register
      name: 'TemplatePicker'
      role: 'Composer:ActionButton'
      view: TemplatePicker
```


3. Replace the `Participants` component that ships with Nylas Mail to display thread participants on your own:

```
    ComponentRegistry.register
      name: 'Participants'
      view: InboxParticipants
```


*Tip: Remember to unregister components in the `deactivate` method of your package.*

