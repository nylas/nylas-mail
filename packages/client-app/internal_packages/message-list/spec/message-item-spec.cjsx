proxyquire = require 'proxyquire'
React = require "react"
ReactDOM = require "react-dom"
ReactTestUtils = require 'react-addons-test-utils'

{Contact,
 Message,
 File,
 Thread,
 Utils,
 QuotedHTMLTransformer,
 FileDownloadStore,
 MessageBodyProcessor} = require "nylas-exports"

MessageItemBody = React.createClass({render: -> <div></div>})

{InjectedComponent} = require 'nylas-component-kit'

file = new File
  id: 'file_1_id'
  filename: 'a.png'
  contentType: 'image/png'
  size: 10
file_not_downloaded = new File
  id: 'file_2_id'
  filename: 'b.png'
  contentType: 'image/png'
  size: 10
file_inline = new File
  id: 'file_inline_id'
  filename: 'c.png'
  contentId: 'file_inline_id'
  contentType: 'image/png'
  size: 10
file_inline_downloading = new File
  id: 'file_inline_downloading_id'
  filename: 'd.png'
  contentId: 'file_inline_downloading_id'
  contentType: 'image/png'
  size: 10
file_inline_not_downloaded = new File
  id: 'file_inline_not_downloaded_id'
  filename: 'e.png'
  contentId: 'file_inline_not_downloaded_id'
  contentType: 'image/png'
  size: 10
file_cid_but_not_referenced = new File
  id: 'file_cid_but_not_referenced'
  filename: 'f.png'
  contentId: 'file_cid_but_not_referenced'
  contentType: 'image/png'
  size: 10
file_cid_but_not_referenced_or_image = new File
  id: 'file_cid_but_not_referenced_or_image'
  filename: 'ansible notes.txt'
  contentId: 'file_cid_but_not_referenced_or_image'
  contentType: 'text/plain'
  size: 300
file_without_filename = new File
  id: 'file_without_filename'
  contentType: 'image/png'
  size: 10

download =
  fileId: 'file_1_id'
download_inline =
  fileId: 'file_inline_downloading_id'

user_1 = new Contact
  name: "User One"
  email: "user1@nylas.com"
user_2 = new Contact
  name: "User Two"
  email: "user2@nylas.com"
user_3 = new Contact
  name: "User Three"
  email: "user3@nylas.com"
user_4 = new Contact
  name: "User Four"
  email: "user4@nylas.com"
user_5 = new Contact
  name: "User Five"
  email: "user5@nylas.com"


MessageItem = proxyquire '../lib/message-item',
  './message-item-body': MessageItemBody

MessageTimestamp = require('../lib/message-timestamp').default


xdescribe "MessageItem", ->
  beforeEach ->
    spyOn(FileDownloadStore, 'pathForFile').andCallFake (f) ->
      return '/fake/path.png' if f.id is file.id
      return '/fake/path-inline.png' if f.id is file_inline.id
      return '/fake/path-downloading.png' if f.id is file_inline_downloading.id
      return null
    spyOn(FileDownloadStore, 'getDownloadDataForFiles').andCallFake (ids) ->
      return {'file_1_id': download, 'file_inline_downloading_id': download_inline}

    spyOn(MessageBodyProcessor, '_addToCache').andCallFake ->

    @message = new Message
      id: "111"
      from: [user_1]
      to: [user_2]
      cc: [user_3, user_4]
      bcc: null
      body: "Body One"
      date: new Date(1415814587)
      draft: false
      files: []
      unread: false
      snippet: "snippet one..."
      subject: "Subject One"
      threadId: "thread_12345"
      accountId: TEST_ACCOUNT_ID

    @thread = new Thread
      id: 'thread-111'
      accountId: TEST_ACCOUNT_ID

    @threadParticipants = [user_1, user_2, user_3, user_4]

    # Generate the test component. Should be called after @message is configured
    # for the test, since MessageItem assumes attributes of the message will not
    # change after getInitialState runs.
    @createComponent = ({collapsed} = {}) =>
      collapsed ?= false
      @component = ReactTestUtils.renderIntoDocument(
        <MessageItem key={@message.id}
                     message={@message}
                     thread={@thread}
                     collapsed={collapsed} />
      )

  # TODO: We currently don't support collapsed messages
  # describe "when collapsed", ->
  #   beforeEach ->
  #     @createComponent({collapsed: true})
  #
  #   it "should not render the EmailFrame", ->
  #     expect( -> ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub)).toThrow()
  #
  #   it "should have the `collapsed` class", ->
  #     expect(ReactDOM.findDOMNode(@component).className.indexOf('collapsed') >= 0).toBe(true)

  describe "when displaying detailed headers", ->
    beforeEach ->
      @createComponent({collapsed: false})
      @component.setState detailedHeaders: true

    it "correctly sets the participant states", ->
      participants = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "expanded-participants")
      expect(participants.length).toBe 2
      expect(-> ReactTestUtils.findRenderedDOMComponentWithClass(@component, "collapsed-participants")).toThrow()

    it "correctly sets the timestamp", ->
      ts = ReactTestUtils.findRenderedComponentWithType(@component, MessageTimestamp)
      expect(ts.props.isDetailed).toBe true

  describe "when not collapsed", ->
    beforeEach ->
      @createComponent({collapsed: false})

    it "should render the MessageItemBody", ->
      frame = ReactTestUtils.findRenderedComponentWithType(@component, MessageItemBody)
      expect(frame).toBeDefined()

    it "should not have the `collapsed` class", ->
      expect(ReactDOM.findDOMNode(@component).className.indexOf('collapsed') >= 0).toBe(false)

  xdescribe "when the message contains attachments", ->
    beforeEach ->
      @message.files = [
        file,
        file_not_downloaded,
        file_cid_but_not_referenced,
        file_cid_but_not_referenced_or_image,

        file_inline,
        file_inline_downloading,
        file_inline_not_downloaded,
        file_without_filename
      ]
      @message.body = """
        <img alt=\"A\" src=\"cid:#{file_inline.contentId}\"/>
        <img alt=\"B\" src=\"cid:#{file_inline_downloading.contentId}\"/>
        <img alt=\"C\" src=\"cid:#{file_inline_not_downloaded.contentId}\"/>
        <img src=\"cid:missing-attachment\"/>
        """
      @createComponent()

    it "should include the attachments area", ->
      attachments = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'attachments-area')
      expect(attachments).toBeDefined()

    it 'injects a MessageAttachments component for any present attachments', ->
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@component, InjectedComponent, matching: {role: "MessageAttachments"})
      expect(els.length).toBe 1

    it "should list attachments that are not mentioned in the body via cid", ->
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@component, InjectedComponent, matching: {role: "MessageAttachments"})
      attachments = els[0].props.exposedProps.files
      expect(attachments.length).toEqual(5)
      expect(attachments[0]).toBe(file)
      expect(attachments[1]).toBe(file_not_downloaded)
      expect(attachments[2]).toBe(file_cid_but_not_referenced)
      expect(attachments[3]).toBe(file_cid_but_not_referenced_or_image)

    it "should provide the correct file download state for each attachment", ->
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@component, InjectedComponent, matching: {role: "MessageAttachments"})
      {downloads} = els[0].props.exposedProps
      expect(downloads['file_1_id']).toBe(download)
      expect(downloads['file_not_downloaded']).toBe(undefined)

    it "should still list attachments when the message has no body", ->
      @message.body = ""
      @createComponent()
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@component, InjectedComponent, matching: {role: "MessageAttachments"})
      attachments = els[0].props.exposedProps.files
      expect(attachments.length).toEqual(8)
