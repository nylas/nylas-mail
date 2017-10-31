import _ from 'underscore';
import moment from 'moment';

import File from './file';
import Utils from './utils';
import Event from './event';
import Contact from './contact';
import Folder from './folder';
import Attributes from '../attributes';
import ModelWithMetadata from './model-with-metadata';

/*
Public: The Message model represents an email message or draft.

Messages are a sub-object of threads. The content of a message === immutable (with the
exception being drafts). Nylas does not support operations such as move || delete on
individual messages; those operations should be performed on the message’s thread.
All messages are part of a thread, even if that thread has only one message.

## Attributes

`to`: {AttributeCollection} A collection of {Contact} objects

`cc`: {AttributeCollection} A collection of {Contact} objects

`bcc`: {AttributeCollection} A collection of {Contact} objects

`from`: {AttributeCollection} A collection of {Contact} objects.

`replyTo`: {AttributeCollection} A collection of {Contact} objects.

`date`: {AttributeDateTime} When the message was delivered. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`snippet`: {AttributeString} A short, 140-character plain-text summary of the message body.

`unread`: {AttributeBoolean} True if the message === unread. Queryable.

`starred`: {AttributeBoolean} True if the message === starred. Queryable.

`draft`: {AttributeBoolean} True if the message === a draft. Queryable.

`version`: {AttributeNumber} The version number of the message. Message
   versions are used for drafts, && increment when attributes are changed.

`files`: {AttributeCollection} A set of {File} models representing
   the attachments on this thread.

`body`: {AttributeJoinedData} The HTML body of the message. You must specifically
 request this attribute when querying for a Message using the {{AttributeJoinedData::include}}
 method.

`pristine`: {AttributeBoolean} True if the message === a draft which has not been
 edited since it was created.

`threadId`: {AttributeString} The ID of the Message's parent {Thread}. Queryable.

`replyToHeaderMessageId`: {AttributeString} The headerMessageID of a {Message} that this message is in reply to.

This class also inherits attributes from {Model}

Section: Models
*/
export default class Message extends ModelWithMetadata {
  static attributes = Object.assign({}, ModelWithMetadata.attributes, {
    to: Attributes.Collection({
      modelKey: 'to',
      itemClass: Contact,
    }),

    cc: Attributes.Collection({
      modelKey: 'cc',
      itemClass: Contact,
    }),

    bcc: Attributes.Collection({
      modelKey: 'bcc',
      itemClass: Contact,
    }),

    from: Attributes.Collection({
      modelKey: 'from',
      itemClass: Contact,
    }),

    replyTo: Attributes.Collection({
      modelKey: 'replyTo',
      itemClass: Contact,
    }),

    date: Attributes.DateTime({
      queryable: true,
      modelKey: 'date',
    }),

    body: Attributes.JoinedData({
      modelTable: 'MessageBody',
      modelKey: 'body',
    }),

    files: Attributes.Collection({
      modelKey: 'files',
      itemClass: File,
    }),

    unread: Attributes.Boolean({
      queryable: true,
      modelKey: 'unread',
    }),

    events: Attributes.Collection({
      modelKey: 'events',
      itemClass: Event,
    }),

    starred: Attributes.Boolean({
      queryable: true,
      modelKey: 'starred',
    }),

    snippet: Attributes.String({
      modelKey: 'snippet',
    }),

    threadId: Attributes.String({
      queryable: true,
      modelKey: 'threadId',
    }),

    headerMessageId: Attributes.String({
      queryable: true,
      jsonKey: 'hMsgId',
      modelKey: 'headerMessageId',
    }),

    subject: Attributes.String({
      modelKey: 'subject',
    }),

    draft: Attributes.Boolean({
      modelKey: 'draft',
      queryable: true,
    }),

    pristine: Attributes.Boolean({
      modelKey: 'pristine',
      queryable: false,
    }),

    version: Attributes.Number({
      jsonKey: 'v',
      modelKey: 'version',
      queryable: true,
    }),

    replyToHeaderMessageId: Attributes.String({
      jsonKey: 'rthMsgId',
      modelKey: 'replyToHeaderMessageId',
    }),

    forwardedHeaderMessageId: Attributes.String({
      jsonKey: 'fwdMsgId',
      modelKey: 'forwardedHeaderMessageId',
    }),

    folder: Attributes.Object({
      queryable: false,
      modelKey: 'folder',
      itemClass: Folder,
    }),
  });

  static naturalSortOrder() {
    return Message.attributes.date.ascending();
  }

  constructor(data) {
    super(data);
    this.subject = this.subject || '';
    this.to = this.to || [];
    this.cc = this.cc || [];
    this.bcc = this.bcc || [];
    this.from = this.from || [];
    this.replyTo = this.replyTo || [];
    this.files = this.files || [];
    this.events = this.events || [];
  }

  toJSON(options) {
    const json = super.toJSON(options);
    json.file_ids = this.fileIds();
    if (this.draft) {
      json.object = 'draft';
    }

    if (this.events && this.events.length) {
      json.event_id = this.events[0].id;
    }

    return json;
  }

  fromJSON(json = {}) {
    super.fromJSON(json);

    // Only change the `draft` bit if the incoming json has an `object`
    // property. Because of `DraftChangeSet`, it's common for incoming json
    // to be an empty hash. In this case we want to leave the pre-existing
    // draft bit alone.
    if (json.object) {
      this.draft = json.object === 'draft';
    }

    return this;
  }

  canReplyAll() {
    const { to, cc } = this.participantsForReplyAll();
    return to.length > 1 || cc.length > 0;
  }

  // Public: Returns a set of uniqued message participants by combining the
  // `to`, `cc`, `bcc` && (optionally) `from` fields.
  participants({ includeFrom = true, includeBcc = false } = {}) {
    const seen = {};
    const all = [];
    let contacts = [].concat(this.to, this.cc);
    if (includeFrom) {
      contacts = _.union(contacts, this.from || []);
    }
    if (includeBcc) {
      contacts = _.union(contacts, this.bcc || []);
    }
    for (const contact of contacts) {
      if (!contact.email) {
        continue;
      }
      const key = contact
        .toString()
        .trim()
        .toLowerCase();
      if (seen[key]) {
        continue;
      }
      seen[key] = true;
      all.push(contact);
    }
    return all;
  }

  // Public: Returns a hash with `to` && `cc` keys for authoring a new draft in
  // "reply all" to this message. This method takes into account whether the
  // message is from the current user, && also looks at the replyTo field.
  participantsForReplyAll() {
    const excludedFroms = this.from.map(c => Utils.toEquivalentEmailForm(c.email));

    const excludeMeAndFroms = cc =>
      _.reject(
        cc,
        p => p.isMe() || _.contains(excludedFroms, Utils.toEquivalentEmailForm(p.email))
      );

    let to = null;
    let cc = null;

    if (this.replyTo.length && !this.replyTo[0].isMe()) {
      // If a replyTo is specified and that replyTo would not result in you
      // sending the message to yourself, use it.
      to = this.replyTo;
      cc = excludeMeAndFroms([].concat(this.to, this.cc));
    } else if (this.isFromMe()) {
      // If the message is from you to others, reply-all should send to the
      // same people.
      to = this.to;
      cc = excludeMeAndFroms(this.cc);
    } else {
      // ... otherwise, address the reply to the sender of the email and cc
      // everyone else.
      to = this.from;
      cc = excludeMeAndFroms([].concat(this.to, this.cc));
    }

    to = _.uniq(to, p => Utils.toEquivalentEmailForm(p.email));
    cc = _.uniq(cc, p => Utils.toEquivalentEmailForm(p.email));
    return { to, cc };
  }

  // Public: Returns a hash with `to` && `cc` keys for authoring a new draft in
  // "reply" to this message. This method takes into account whether the
  // message is from the current user, && also looks at the replyTo field.
  participantsForReply() {
    let to = [];
    const cc = [];

    if (this.replyTo.length && !this.replyTo[0].isMe()) {
      // If a replyTo is specified and that replyTo would not result in you
      // sending the message to yourself, use it.
      to = this.replyTo;
    } else if (this.isFromMe()) {
      // If you sent the previous email, a "reply" should go to the same recipient.
      to = this.to;
    } else {
      // ... otherwise, address the reply to the sender.
      to = this.from;
    }

    to = _.uniq(to, p => Utils.toEquivalentEmailForm(p.email));
    return { to, cc };
  }

  // Public: Returns an {Array} of {File} IDs
  fileIds() {
    return this.files.map(file => file.id);
  }

  // Public: Returns true if this message === from the current user's email
  // address. In the future, this method will take into account all of the
  // user's email addresses && accounts.
  isFromMe() {
    return this.from[0] ? this.from[0].isMe() : false;
  }

  fromContact() {
    return (this.from || [])[0] || new Contact({ name: 'Unknown', email: 'Unknown' });
  }

  // Public: Returns the standard attribution line for this message,
  // localized for the current user.
  // ie "On Dec. 12th, 2015 at 4:00PM, Ben Gotow wrote:"
  replyAttributionLine() {
    return `On ${this.formattedDate()}, ${this.fromContact().toString()} wrote:`;
  }

  formattedDate() {
    return moment(this.date).format('MMM D YYYY, [at] h:mm a');
  }

  hasEmptyBody() {
    if (!this.body) {
      return true;
    }

    // https://regex101.com/r/hR7zN3/1
    const re = /(?:<signature>.*<\/signature>)|(?:<.+?>)|\s/gim;
    return this.body.replace(re, '').length === 0;
  }

  isHidden() {
    const isReminder =
      this.to.length === 1 &&
      this.from.length === 1 &&
      this.to[0].email === this.from[0].email &&
      (this.from[0].name || '').endsWith('via Mailspring');
    const isDraftBeingDeleted = this.id.startsWith('deleted-');

    return isReminder || isDraftBeingDeleted;
  }
}
