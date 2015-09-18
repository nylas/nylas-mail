---
Title:   Application Architecture
Section: Guides
Order:   3
---

Nylas Mail uses [Reflux](https://github.com/spoike/refluxjs), a slim implementation of Facebook's [Flux Application Architecture](https://facebook.github.io/flux/) to coordinate the movement of data through the application. Flux is extremely well suited for applications that support third-party extension because it emphasizes loose coupling and well defined interfaces between components. It enforces:

- **Uni-directional data flow**
- **Loose coupling between components**

For more information about the Flux pattern, check out [this diagram](https://facebook.github.io/flux/docs/overview.html#structure-and-data-flow). For a bit more insight into why we chose Reflux over other Flux implementations, there's a great [blog post](http://spoike.ghost.io/deconstructing-reactjss-flux/) by the author of Reflux.

There are several core stores in the application:

- **{AccountStore}**: When the user signs in to Nylas Mail, their auth token provides one or more accounts. The AccountStore manages the available Accounts, exposes the current Account, and allows you to observe changes to the current Account.

- **{TaskQueue}**: Manages Tasks, operations queued for processing on the backend. Task objects represent individual API actions and are persisted to disk, ensuring that they are performed eventually. Each Task may depend on other tasks, and Tasks are executed in order.

- **{DatabaseStore}**: The {DatabaseStore} marshalls data in and out of the local cache, and exposes an ActiveRecord-style query interface. You can observe the DatabaseStore to monitor the state of data in Nylas Mail.

- **{DraftStore}**: Manages Drafts, which are {Message} objects the user is authoring. Drafts present a unique case in Nylas Mail because they may be updated frequently by disconnected parts of the application. You should use the {DraftStore} to create, edit, and send drafts.

- **{FocusedContentStore}**: Manages focus within the main applciation window. The {FocusedContentStore} allows you to query and monitor changes to the selected thread, tag, file, etc.

Most packages declare additional stores that subscribe to these Stores, as well as user Actions, and vend data to the package's React components.


### Actions

In Flux applications, views fire {Actions}, which anyone in the application can subscribe to. Typically, `Stores` listen to actions to perform business logic and trigger updates to their corresponding views. For example, when you click "Compose" in the top left corner of Nylas Mail, the React component for the button fires {Actions::composeNewBlankDraft}. The {DraftStore} listens to this action and opens a new composer window.

This approach means that your packages can fire existing {Actions}, like {Actions::composeNewBlankDraft}, or observe actions to add functionality. (For example, we have an Analytics package that also listens for {Actions::composeNewBlankDraft} and counts how many times it's been fired.) You can also define your own actions for use within your package.

For a complete list of available actions, see {Actions}.
