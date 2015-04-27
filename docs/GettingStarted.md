##Quick Start

The Nilas Package API allows you to create powerful extensions to the Nilas Mail client, Nylas Mail. The client is built on top of Atom Shell and runs on Mac OS X, Windows, and Linux. It exposes rich APIs for working with the mail, contacts, and calendar and a robust local cache layer. Your packages can leverage NodeJS and other web technologies to create innovative new experiences.

###Installing Nylas Mail

Nylas Mail is available for Mac, Windows, and Linux. Download the latest build for your platform below:

- [Mac OS X](https://edgehill.nilas.com/download?platform=darwin)
- [Linux](https://edgehill.nilas.com/download?platform=linux)
- [Windows](https://edgehill.nilas.com/download?platform=win32)



###Building a Package

Packages lie at the heart of Nylas Mail. Each part of the core experience is a separate package that uses the Nilas Package API to add functionality to the client. Want to make a read-only mail client? Remove the core `Composer` package and you'll see reply buttons and composer functionality disappear.

Let's explore the files in a simple package that adds a Translate option to the Composer. When you tap the Translate button, we'll display a popup menu with a list of languages. When you pick a language, we'll make a web request and convert your reply into the desired language.
    
#####Package Structure

Each package is defined by a `package.json` file that includes it's name, version and dependencies. Our `translate` package uses React and the Node [request](https://github.com/request/request) library.

```
{
  "name": "translate",
  "version": "0.1.0",
  "main": "./lib/main",
  "description": "An example package for Nylas Mail",
  "license": "Proprietary",
  "engines": {
    "atom": "*"
  },
  "dependencies": {
    "react": "^0.12.2",
    "request": "^2.53"
  }
}

```

Our package also contains source files, a spec file with complete tests for the behavior the package adds, and a stylesheet for CSS.

```
- package.json
- lib/
   - main.cjsx
- spec/
   - main-spec.coffee
- stylesheets/
   - translate.less
```

`package.json` lists `lib/main` as the root file of our package. As our package expands, we can add other source files. Since Nylas Mail runs NodeJS, you can `require` other source files, Node packages, etc. Inside `main.cjsx`, there are two important functions being exported:

```
module.exports =
  
  ##
  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    ComponentRegistry.register
      view: TranslateButton
      name: 'TranslateButton'
      role: 'Composer:ActionButton'
 
  ## 
  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->
  	{}

  ##
  # This optional method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  deactivate: ->
    ComponentRegistry.unregister('TranslateButton')
```


> Nylas Mail uses CJSX, a Coffeescript version of JSX, which makes it easy to express Virtual DOM in React `render` methods! You may want to add the [Babel](https://github.com/babel/babel-sublime) plugin to Sublime Text, or the [CJSX Language](https://atom.io/packages/language-cjsx) for syntax highlighting.


#####Package Style Sheets

Style sheets for your package should be placed in the _styles_ directory.
Any style sheets in this directory will be loaded and attached to the DOM when
your package is activated. Style sheets can be written as CSS or [Less], but
Less is recommended.

Ideally, you won't need much in the way of styling. We've provided a standard
set of components which define both the colors and UI elements for any package
that fits into Nylas Mail seamlessly.

If you _do_ need special styling, try to keep only structural styles in the
package style sheets. If you _must_ specify colors and sizing, these should be
taken from the active theme's [ui-variables.less][ui-variables]. For more
information, see the [theme variables docs][theme-variables]. If you follow this
guideline, your package will look good out of the box with any theme!

An optional `stylesheets` array in your _package.json_ can list the style sheets
by name to specify a loading order; otherwise, all style sheets are loaded.

###Installing a Package

Nylas Mail ships with many packages already bundled with the application. When the application launches, it looks for additional packages in `~/.inbox/packages`. Each package you create belongs in it's own directory inside this folder.

In the future, it will be possible to install packages directly from within the client.

-----

##Core Concepts

Nylas Mail uses [React](https://facebook.github.io/react/) to create a fast, responsive UI. Packages that want to extend the Nylas Mail interface should use React. Using React's `JSX` is optional, but both `JSX` and `CJSX` (Coffeescript) are available.

For a quick introduction to React, take a look at Facebook's [Getting Started with React](https://facebook.github.io/react/docs/getting-started.html).

Nylas Mail also uses [Reflux](https://github.com/spoike/refluxjs), a slim implementation of Facebook's [Flux Application Architecture](https://facebook.github.io/flux/) to coordinate the movement of data through the application. Flux is extremely well suited for applications that support third-party extension, because it emphasizes loose coupling and well defined interfaces between components. It enforces:

- **Uni-directional data flow** 
- **Loose coupling between components**

For more information about the Flux pattern, check out [this diagram](https://facebook.github.io/flux/docs/overview.html#structure-and-data-flow).

There are several core stores in the application:

- **NamespaceStore**: When the user signs in to Nylas Mail, their auth token provides one or more namespaces. The NamespaceStore manages the available Namespaces, exposes the current Namespace, and allows you to observe changes to the current namespace.

- **TaskQueue**: Manages `Tasks`, operations queued for processing on the backend. `Task` objects represent individual API actions and are persisted to disk, ensuring that they are performed eventually. Each `Task` may depend on other tasks, and `Tasks` are executed in order.

- **DatabaseStore**: The DatabaseStore marshalls data in and out of the local cache, and exposes an ActiveRecord-style query interface. You can observe the DatabaseStore to monitor the state of data in Nylas Mail.

- **DraftStore**: Manages `Drafts`. Drafts present a unique case in Nylas Mail because they may be updated frequently by disconnected parts of the application. You should use the DraftStore to create, edit, and send drafts.

- **FocusedContentStore**: Manages focus within the main applciation window. The FocusedContentStore allows you to query and monitor changes to the selected thread, tag, file, etc.

Most packages declare additional stores that subscribe to these Stores, as well as user Actions, and vend data to the package's React components.


### React

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

###Actions

Nylas Mail is built on top of Reflux, an implementation of the Flux architecture. React views fire `Actions`, which anyone in the application can subscribe to. Typically, `Stores` listen to actions to perform business logic and trigger updates to their corresponding views.

Your packages can fire `Actions` to trigger behaviors in the app. You can also define your own actions for use within your package.

For a complete list of available actions, see `Actions.coffee`. Actions in Nylas Mail are broken into three categories:

- Global Actions: These actions can be fired in any window and are automatically distributed to all windows via IPC.

- Main Window Actions: These actions can be fired in any window and are automatically sent to the main window via IPC. They are not sent to other windows of the app.

- Window Actions: These actions only broadcast within the window they're fired in.

###Database

Nylas Mail is built on top of a custom database layer modeled after ActiveRecord. For many parts of the application, the database is the source of truth. Data is retrieved from the API, written to the database, and changes to the database trigger Stores and components to refresh their contents. The illustration below shows this flow of data:

<img src="./images/database-flow.png" style="max-width:750px;">

The Database connection is managed by the `DatabaseStore`, a singleton object that exists in every window. All Database requests are asynchronous. Queries are forwarded to the application's `Browser` process via IPC and run in SQLite.

#####Declaring Models

In Nylas Mail, Models are thin wrappers around data with a particular schema. Each Model class declares a set of attributes that define the object's data. For example:

```
class Example extends Model

  @attributes:
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'object': Attributes.String
      modelKey: 'object'

    'namespaceId': Attributes.String
      queryable: true
      modelKey: 'namespaceId'
      jsonKey: 'namespace_id'
      
    'body': Attributes.JoinedData
      modelTable: 'MessageBody'
      modelKey: 'body'

    'files': Attributes.Collection
      modelKey: 'files'
      itemClass: File

    'unread': Attributes.Boolean
      queryable: true
      modelKey: 'unread'
```

When models are inflated from JSON using `fromJSON` or converted to JSON using `toJSON`, only the attributes declared on the model are copied. The `modelKey` and `jsonKey` options allow you to specify where a particular key should be found. Attributes are also coerced to the proper types: String attributes will always be strings, Boolean attributes will always be `true` or `false`, etc. `null` is a valid value for all types.

The DatabaseStore automatically maintains cache tables for storing Model objects. By default, models are stored in the cache as JSON blobs and basic attributes are not queryable. When the `queryable` option is specified on an attribute, it is given a separate column and index in the SQLite table for the model, and you can construct queries using the attribute:

```
Thread.attributes.namespaceId.equals("123") 
// where namespace_id = '123'

Thread.attributes.lastMessageTimestamp.greaterThan(123) 
// where last_message_timestamp > 123

Thread.attributes.lastMessageTimestamp.descending() 
// order by last_message_timestamp DESC
```

#####Retrieving Models

You can make queries for models stored in SQLite using a Promise-based ActiveRecord-style syntax. There is no way to make raw SQL queries against the local data store.

```
DatabaseStore.find(Thread, '123').then (thread) ->
    # thread is a thread object

DatabaseStore.findBy(Thread, {subject: 'Hello World'}).then (thread) ->
	# find a single thread by subject

DatabaseStore.findAll(Thread).where([Thread.attributes.tags.contains('inbox')]).then (threads) ->
	# find threads with the inbox tag

DatabaseStore.count(Thread).where([Thread.attributes.lastMessageTimestamp.greaterThan(120315123)]).then (results) ->
	# count threads where last message received since 120315123.

```

#####Retrieving Pages of Models

If you need to paginate through a view of data, you should use a `DatabaseView`. Database views can be configured with a sort order and a set of where clauses. After the view is configured, it maintains a cache of models in memory in a highly efficient manner and makes it easy to implement pagination. `DatabaseView` also performs deep inspection of it's cache when models are changed and can avoid costly SQL queries.


#####Saving and Updating Models

The DatabaseStore exposes two methods for creating and updating models: `persistModel` and `persistModels`. When you call `persistModel`, queries are automatically executed to update the object in the cache and the DatabaseStore triggers, broadcasting an update to the rest of the application so that views dependent on these kind of models can refresh.

When possible, you should accumulate the objects you want to save and call `persistModels`. The DatabaseStore will generate batch insert statements, and a single notification will be broadcast throughout the application. Since saving objects can result in objects being re-fetched by many stores and components, you should be mindful of database insertions.

#####Saving Drafts

Drafts in Nylas Mail presented us with a unique challenge. The same draft may be edited rapidly by unrelated parts of the application, causing race scenarios. (For example, when the user is typing and attachments finish uploading at the same time.) This problem could be solved by object locking, but we chose to marshall draft changes through a central DraftStore that debounces database queries and adds other helpful features. See the `DraftStore` documentation for more information.

#####Removing Models

The DatabaseStore exposes a single method, `unpersistModel`, that allows you to purge an object from the cache. You cannot remove a model by ID alone - you must load it first.

####Advanced Model Attributes

#####Attribute.JoinedData

Joined Data attributes allow you to store certain attributes of an object in a separate table in the database. We use this attribute type for Message bodies. Storing message bodies, which can be very large, in a separate table allows us to make queries on message metadata extremely fast, and inflate Message objects without their bodies to build the thread list.

When building a query on a model with a JoinedData attribute, you need to call `include` to explicitly load the joined data attribute. The query builder will automatically perform a `LEFT OUTER JOIN` with the secondary table to retrieve the attribute:

```
DatabaseStore.find(Message, '123').then (message) ->
	// message.body is undefined

DatabaseStore.find(Message, '123').include(Message.attributes.body).then (message) ->
	// message.body is defined
```

When you call `persistModel`, JoinedData attributes are automatically written to the secondary table.

JoinedData attributes cannot be `queryable`.

#####Attribute.Collection

Collection attributes provide basic support for one-to-many relationships. For example, Threads in Nylas Mail have a collection of Tags.

When Collection attributes are marked as `queryable`, the DatabaseStore automatically creates a join table and maintains it as you create, save, and delete models. When you call `persistModel`, entries are added to the join table associating the ID of the model with the IDs of models in the collection.

Collection attributes have an additional clause builder, `contains`:

```
DatabaseStore.findAll(Thread).where([Thread.attributes.tags.contains('inbox')])
```

This is equivalent to writing the following SQL:

```
SELECT `Thread`.`data` FROM `Thread` INNER JOIN `Thread-Tag` AS `M1` ON `M1`.`id` = `Thread`.`id` WHERE `M1`.`value` = 'inbox' ORDER BY `Thread`.`last_message_timestamp` DESC
```

#### Listening for Changes

For many parts of the application, the Database is the source of truth. Funneling changes through the database ensures that they are available to the entire application. Basing your packages on the Database, and listening to it for changes, ensures that your views never fall out of sync.

Within Reflux Stores, you can listen to the DatabaseStore using the `listenTo` helper method:

```
@listenTo(DatabaseStore, @_onDataChanged)
```

Within generic code, you can listen to the DatabaseStore using this syntax:

```
@unlisten = DatabaseStore.listen(@_onDataChanged, @)
```

When a model is persisted or unpersisted from the database, your listener method will fire. It's very important to inspect the change payload before making queries to refresh your data. The change payload is a simple object with the following keys:

```
{
	"objectClass": // string: the name of the class that was changed. ie: "Thread"
	"objects": // array: the objects that were persisted or removed
}
```


##### But why can't I...?

Nylas Mail exposes a minimal Database API that exposes high-level methods for saving and retrieving objects. The API was designed with several goals in mind, which will help us create a healthy ecosystem of third-party packages:

- Package code should not be tightly coupled to SQLite
- Queries should be composed in a way that makes invalid queries impossible
- All changes to the local database must be observable



###Sheets and Columns

The Nylas Mail user interface is conceptually organized into Sheets. Each Sheet represents a window of content. For example, the `Threads` sheet lies at the heart of the application. When the user chooses the "Files" tab, a separate `Files` sheet is displayed in place of `Threads`. When the user clicks a thread in single-pane mode, a `Thread` sheet is pushed on to the workspace and appears after a brief transition.

<img src="./images/sheets.png" style="max-width:400px;">

The `WorkspaceStore` maintains the state of the application's workspace and the stack of sheets currently being displayed. Your packages can declare "root" sheets which are listed in the app's main sidebar, or push custom sheets on top of sheets to display data.

The Nilas Workspace supports two display modes: `split` and `list`. Each Sheet describes it's appearance in each of the view modes it supports. For example, the `Threads` sheet describes a three column `split` view and a single column `list` view. Other sheets, like `Files` register for only one mode, and the user's mode preference is ignored. 

For each mode, Sheets register a set of column names. 

<img src="./images/columns.png" style="max-width:800px;">

```
@defineSheet 'Threads', {root: true},
   split: ['RootSidebar', 'ThreadList', 'MessageList', 'MessageListSidebar']
   list: ['RootSidebar', 'ThreadList']
```

Column names are important. Once you've registered a sheet, your package (and other packages) register React components that appear in each column.

Sheets also have a `Header` and `Footer` region that spans all of their content columns. You can register components to appear in these regions to display notifications, add bars beneath the toolbar, etc.


```
ComponentRegistry.register
  view: AccountSidebar
  name: 'AccountSidebar'
  location: WorkspaceStore.Location.RootSidebar


ComponentRegistry.register
  view: NotificationsStickyBar
  name: 'NotificationsStickyBar'
  location: WorkspaceStore.Sheet.Threads.Header

```

Each column is laid out as a CSS Flexbox, making them extremely flexible. For more about layout using Flexbox, see Working with Flexbox.


###Toolbars

Toolbars in Nylas Mail are also powered by the Component Registry. Though toolbars appear to be a single unit at the top of a sheet, they are divided into columns with the same widths as the columns in the sheet beneath them.

<img src="./images/toolbar.png" style="max-width:800px;">

Each Toolbar column is laid out using Flexbox. You can control where toolbar elements appear within the column using the CSS `order` attribute. To make it easy to position toolbar items on the left, right, or center of a column, we've added two "spacer" elements with `order:50` and `order:-50` that evenly use up available space. Other CSS attributes allow you to control whether your items shrink or expand as the column's size changes.

<img src="./images/toolbar-column.png" style="max-width:800px;">

To add items to a toolbar, you inject them via the Component Registry. There are several ways of describing the location of a toolbar component which are useful in different scenarios:

- `<Location>.Toolbar`: This component will always appear in the toolbar above the column named `<Location>`.

    (Example: Compose button which appears above the Left Sidebar column, regardless of what else is there.)

- `<ComponentName>.Toolbar`: This component will appear in the toolbar above `<ComponentName>`.

    (Example: Archive button that should always be coupled with the MessageList component, placed anywhere a MessageList component is placed.)

- `Global.Toolbar.Left`: This component will always be added to the leftmost column of the toolbar.

    (Example: Window Controls)



###Debugging

Nylas Mail is built on top of Atom Shell, which runs the latest version of Chromium (at the time of writing, Chromium 41). You can access the standard Chrome Developer Tools using the Command-Option-I keyboard shortcut. When you open the developer tools, you'll also notice a bar appear at the bottom of the window. This bar allows you to inspect API requests sent from the app, streaming updates received from the Nilas API, and tasks that are queued for processing with the `TaskQueue`.

###Software Architecture

Promises:

Loose Coupling