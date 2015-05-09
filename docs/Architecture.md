### Application Architecture: Flux

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


###Actions

Nylas Mail is built on top of Reflux, an implementation of the Flux architecture. React views fire `Actions`, which anyone in the application can subscribe to. Typically, `Stores` listen to actions to perform business logic and trigger updates to their corresponding views.

Your packages can fire `Actions` to trigger behaviors in the app. You can also define your own actions for use within your package.

For a complete list of available actions, see `Actions.coffee`. Actions in Nylas Mail are broken into three categories:

- Global Actions: These actions can be fired in any window and are automatically distributed to all windows via IPC.

- Main Window Actions: These actions can be fired in any window and are automatically sent to the main window via IPC. They are not sent to other windows of the app.

- Window Actions: These actions only broadcast within the window they're fired in.
