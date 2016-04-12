---
Title:   Accessing the Database
Section: Guides
Order:   5
---

N1 is built on top of a custom database layer modeled after ActiveRecord. For many parts of the application, the database is the source of truth. Data is retrieved from the API, written to the database, and changes to the database trigger Stores and components to refresh their contents. The illustration below shows this flow of data:

<img src="./images/database-flow.png">

The Database connection is managed by the {DatabaseStore}, a singleton object that exists in every window. All Database requests are asynchronous. Queries are forwarded to the application's `Browser` process via IPC and run in SQLite.

## Declaring Models

In N1, Models are thin wrappers around data with a particular schema. Each {Model} class declares a set of attributes that define the object's data. For example:

```coffee
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

The {DatabaseStore} automatically maintains cache tables for storing Model objects. By default, models are stored in the cache as JSON blobs and basic attributes are not queryable. When the `queryable` option is specified on an attribute, it is given a separate column and index in the SQLite table for the model, and you can construct queries using the attribute:

```coffee
Thread.attributes.namespaceId.equals("123")
// where namespace_id = '123'

Thread.attributes.lastMessageTimestamp.greaterThan(123)
// where last_message_timestamp > 123

Thread.attributes.lastMessageTimestamp.descending()
// order by last_message_timestamp DESC
```

## Retrieving Models

You can make queries for models stored in SQLite using a {Promise}-based ActiveRecord-style syntax. There is no way to make raw SQL queries against the local data store.

```coffee
DatabaseStore.find(Thread, '123').then (thread) ->
    # thread is a thread object

DatabaseStore.findBy(Thread, {subject: 'Hello World'}).then (thread) ->
	# find a single thread by subject

DatabaseStore.findAll(Thread).where([Thread.attributes.tags.contains('inbox')]).then (threads) ->
	# find threads with the inbox tag

DatabaseStore.count(Thread).where([Thread.attributes.lastMessageTimestamp.greaterThan(120315123)]).then (results) ->
	# count threads where last message received since 120315123.

```

## Retrieving Pages of Models

If you need to paginate through a view of data, you should use a `DatabaseView`. Database views can be configured with a sort order and a set of where clauses. After the view is configured, it maintains a cache of models in memory in a highly efficient manner and makes it easy to implement pagination. `DatabaseView` also performs deep inspection of its cache when models are changed and can avoid costly SQL queries.


## Saving and Updating Models

The {DatabaseStore} exposes two methods for creating and updating models: `persistModel` and `persistModels`. When you call `persistModel`, queries are automatically executed to update the object in the cache and the {DatabaseStore} triggers, broadcasting an update to the rest of the application so that views dependent on these kind of models can refresh.

When possible, you should accumulate the objects you want to save and call `persistModels`. The {DatabaseStore} will generate batch insert statements, and a single notification will be broadcast throughout the application. Since saving objects can result in objects being re-fetched by many stores and components, you should be mindful of database insertions.

## Saving Drafts

Drafts in N1 presented us with a unique challenge. The same draft may be edited rapidly by unrelated parts of the application, causing race scenarios. (For example, when the user is typing and attachments finish uploading at the same time.) This problem could be solved by object locking, but we chose to marshall draft changes through a central DraftStore that debounces database queries and adds other helpful features. See the {DraftStore} documentation for more information.

## Removing Models

The {DatabaseStore} exposes a single method, `unpersistModel`, that allows you to purge an object from the cache. You cannot remove a model by ID alone - you must load it first.

#### Advanced Model Attributes

##### Attribute.JoinedData

Joined Data attributes allow you to store certain attributes of an object in a separate table in the database. We use this attribute type for Message bodies. Storing message bodies, which can be very large, in a separate table allows us to make queries on message metadata extremely fast, and inflate Message objects without their bodies to build the thread list.

When building a {ModelQuery} on a model with a {JoinedDataAttribute}, you need to call `include` to explicitly load the joined data attribute. The query builder will automatically perform a `LEFT OUTER JOIN` with the secondary table to retrieve the attribute:

```coffee
DatabaseStore.find(Message, '123').then (message) ->
	// message.body is undefined

DatabaseStore.find(Message, '123').include(Message.attributes.body).then (message) ->
	// message.body is defined
```

When you call `persistModel`, JoinedData attributes are automatically written to the secondary table.

JoinedData attributes cannot be `queryable`.

##### Attribute.Collection

Collection attributes provide basic support for one-to-many relationships. For example, {Thread}s in N1 have a collection of {Tag}s.

When Collection attributes are marked as `queryable`, the {DatabaseStore} automatically creates a join table and maintains it as you create, save, and delete models. When you call `persistModel`, entries are added to the join table associating the ID of the model with the IDs of models in the collection.

Collection attributes have an additional clause builder, `contains`:

```coffee
DatabaseStore.findAll(Thread).where([Thread.attributes.tags.contains('inbox')])
```

This is equivalent to writing the following SQL:

```sql
SELECT `Thread`.`data` FROM `Thread` INNER JOIN `ThreadTag` AS `M1` ON `M1`.`id` = `Thread`.`id` WHERE `M1`.`value` = 'inbox' ORDER BY `Thread`.`last_message_timestamp` DESC
```

#### Listening for Changes

For many parts of the application, the Database is the source of truth. Funneling changes through the database ensures that they are available to the entire application. Basing your packages on the Database, and listening to it for changes, ensures that your views never fall out of sync.

Within Reflux Stores, you can listen to the {DatabaseStore} using the `listenTo` helper method:

```coffee
@listenTo(DatabaseStore, @_onDataChanged)
```

Within generic code, you can listen to the {DatabaseStore} using this syntax:

```coffee
@unlisten = DatabaseStore.listen(@_onDataChanged, @)
```

When a model is persisted or unpersisted from the database, your listener method will fire. It's very important to inspect the change payload before making queries to refresh your data. The change payload is a simple object with the following keys:

```
{
	"objectClass": // string: the name of the class that was changed. ie: "Thread"
	"objects": // array: the objects that were persisted or removed
}
```


##  But why can't I...?

N1 exposes a minimal Database API that exposes high-level methods for saving and retrieving objects. The API was designed with several goals in mind, which will help us create a healthy ecosystem of third-party packages:

- Package code should not be tightly coupled to SQLite

- Queries should be composed in a way that makes invalid queries impossible

- All changes to the local database must be observable
