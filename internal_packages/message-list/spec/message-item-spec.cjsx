proxyquire = require 'proxyquire'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

{Contact,
 Message,
 File,
 ComponentRegistry,
 FileDownloadStore,
 InboxTestUtils} = require "inbox-exports"

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

download =
  fileId: 'file_1_id'
download_inline =
  fileId: 'file_inline_downloading_id'

user_1 = new Contact
  name: "User One"
  email: "user1@inboxapp.com"
user_2 = new Contact
  name: "User Two"
  email: "user2@inboxapp.com"
user_3 = new Contact
  name: "User Three"
  email: "user3@inboxapp.com"
user_4 = new Contact
  name: "User Four"
  email: "user4@inboxapp.com"
user_5 = new Contact
  name: "User Five"
  email: "user5@inboxapp.com"


AttachmentStub = React.createClass({render: -> <div></div>})
EmailFrameStub = React.createClass({render: -> <div></div>})

MessageItem = proxyquire '../lib/message-item.cjsx',
  './email-frame': EmailFrameStub


describe "MessageItem", ->
  beforeEach ->
    ComponentRegistry.register
      name: 'AttachmentComponent'
      view: AttachmentStub

    spyOn(FileDownloadStore, 'pathForFile').andCallFake (f) ->
      return '/fake/path.png' if f.id is file.id
      return '/fake/path-inline.png' if f.id is file_inline.id
      return '/fake/path-downloading.png' if f.id is file_inline_downloading.id
      return null
    spyOn(FileDownloadStore, 'downloadsForFileIds').andCallFake (ids) ->
      return {'file_1_id': download, 'file_inline_downloading_id': download_inline}

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
      namespaceId: "nsid"

    @threadParticipants = [user_1, user_2, user_3, user_4]
    
    # Generate the test component. Should be called after @message is configured
    # for the test, since MessageItem assumes attributes of the message will not
    # change after getInitialState runs.
    @createComponent = ({collapsed} = {}) =>
      collapsed ?= false
      @component = ReactTestUtils.renderIntoDocument(
        <MessageItem key={@message.id}
                     message={@message}
                     collapsed={collapsed}
                     thread_participants={@threadParticipants} />
      )
  
  describe "when collapsed", ->
    beforeEach ->
      @createComponent({collapsed: true})

    it "should not render the EmailFrame", ->
      expect( -> ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub)).toThrow()

    it "should have the `collapsed` class", ->
      expect(@component.getDOMNode().className.indexOf('collapsed') >= 0).toBe(true)

  describe "when not collapsed", ->
    beforeEach ->
      @createComponent({collapsed: false})

    it "should render the EmailFrame", ->
      frame = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub)
      expect(frame).toBeDefined()

    it "should not have the `collapsed` class", ->
      expect(@component.getDOMNode().className.indexOf('collapsed') >= 0).toBe(false)
    
  describe "when the message contains attachments", ->
    beforeEach ->
      @message.files = [file, file_not_downloaded]
      @createComponent()

    it "should include the attachments area", ->
      attachments = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'attachments-area')
      expect(attachments).toBeDefined()

    it "should render the registered AttachmentComponent for each attachment", ->
      attachments = ReactTestUtils.scryRenderedComponentsWithType(@component, AttachmentStub)
      expect(attachments.length).toEqual(2)
      expect(attachments[0].props.file).toBe(file)
      expect(attachments[1].props.file).toBe(file_not_downloaded)

    it "should provide file download state to each AttachmentComponent", ->
      attachments = ReactTestUtils.scryRenderedComponentsWithType(@component, AttachmentStub)
      expect(attachments[0].props.download).toBe(download)
      expect(attachments[1].props.download).toBe(undefined)

  describe "when the message contains inline attachments", ->
    beforeEach ->
      @message.files = [
        file,
        file_inline,
        file_inline_downloading,
        file_inline_not_downloaded
      ]
      @message.body = """
        <img alt=\"A\" src=\"cid:#{file_inline.contentId}\"/>
        <img alt=\"B\" src=\"cid:#{file_inline_downloading.contentId}\"/>
        <img alt=\"C\" src=\"cid:#{file_inline_not_downloaded.contentId}\"/>
        <img src=\"cid:missing-attachment\"/>
        """
      @createComponent()

    it "should never include src=cid:// in the message body", ->
      body = @component._formatBody()
      expect(body.indexOf('cid')).toEqual(-1)

    it "should replace cid://<file.contentId> with the FileDownloadStore's path for the file", ->
      body = @component._formatBody()
      expect(body.indexOf('alt="A" src="/fake/path-inline.png"')).toEqual(@message.body.indexOf('alt="A"'))

    it "should not replace cid://<file.contentId> with the FileDownloadStore's path if the download is in progress", ->
      body = @component._formatBody()
      expect(body.indexOf('/fake/path-downloading.png')).toEqual(-1)

    it "should not include them in the attachments area", ->
      attachments = ReactTestUtils.scryRenderedComponentsWithType(@component, AttachmentStub)
      expect(attachments.length).toEqual(1)
      expect(attachments[0].props.file).toBe(file)

  describe "showQuotedText", ->
    it "should be initialized to false", ->
      @createComponent()
      expect(@component.state.showQuotedText).toBe(false)

    it "should show the `show quoted text` toggle in the off state", ->
      @createComponent()
      toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-toggle')
      expect(toggle.getDOMNode().className.indexOf('state-on')).toBe(-1)

    it "should be initialized to true if the message contains `Forwarded`...", ->
      @message.body = """
        Hi guys, take a look at this. Very relevant. -mg
        <br>
        <br>
        <div class="gmail_quote">
          ---- Forwarded Message -----
          blablalba
        </div>
        """
      @createComponent()
      expect(@component.state.showQuotedText).toBe(true)

    it "should be initialized to false if the message is a response to a Forwarded message", ->
      @message.body = """
        Thanks mg, that indeed looks very relevant. Will bring it up
        with the rest of the team.

        On Sunday, March 4th at 12:32AM, Michael Grinich Wrote:
        <div class="gmail_quote">
          Hi guys, take a look at this. Very relevant. -mg
          <br>
          <br>
          <div class="gmail_quote">
            ---- Forwarded Message -----
            blablalba
          </div>
        </div>
        """
      @createComponent()
      expect(@component.state.showQuotedText).toBe(false)

    describe "when true", ->
      beforeEach ->
        @createComponent()
        @component.setState(showQuotedText: true)

      it "should show the `show quoted text` toggle in the on state", ->
        toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-toggle')
        expect(toggle.getDOMNode().className.indexOf('state-on') > 0).toBe(true)

      it "should pass the value into the EmailFrame", ->
        frame = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub)
        expect(frame.props.showQuotedText).toBe(true)
