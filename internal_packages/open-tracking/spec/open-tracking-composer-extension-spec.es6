import OpenTrackingComposerExtension from '../lib/open-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/open-tracking-constants';
import {Message, QuotedHTMLTransformer} from 'nylas-exports';

const quote = `<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;"> On Feb 25 2016, at 3:38 pm, Drew &lt;drew@nylas.com&gt; wrote: <br> twst </blockquote>`;

describe("Open tracking composer extension", () => {
  // Set up a draft, session that returns the draft, and metadata
  beforeEach(()=>{
    this.draft = new Message();
    this.draft.body = `<body>TEST_BODY ${quote}</body>`;
    this.session = {
      draft: () => this.draft,
      changes: jasmine.createSpyObj('changes', ['add', 'commit']),
    };
  });

  it("takes no action if there is no metadata", ()=>{
    OpenTrackingComposerExtension.finalizeSessionBeforeSending({session: this.session});
    expect(this.session.changes.add.calls.length).toEqual(0);
    expect(this.session.changes.commit.calls.length).toEqual(0);
  });

  describe("With properly formatted metadata and correct params", () => {
    // Set metadata on the draft and call finalizeSessionBeforeSending
    beforeEach(()=>{
      this.metadata = {uid: "TEST_UID"};
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      OpenTrackingComposerExtension.finalizeSessionBeforeSending({session: this.session});
    });

    it("adds (but does not commit) the changes to the session", ()=>{
      expect(this.session.changes.add).toHaveBeenCalled();
      expect(this.session.changes.add.mostRecentCall.args[0].body).toBeDefined();
      expect(this.session.changes.add.mostRecentCall.args[0].body).toContain("TEST_BODY");
      expect(this.session.changes.commit).not.toHaveBeenCalled();
    });

    describe("On the unquoted body", () => {
      beforeEach(()=>{
        const body = this.session.changes.add.mostRecentCall.args[0].body;
        this.unquoted = QuotedHTMLTransformer.removeQuotedHTML(body);
      });

      it("appends an image to the body", ()=>{
        expect(this.unquoted).toMatch(/<img .*?>/);
      });

      it("has the right server URL", ()=>{
        const img = this.unquoted.match(/<img .*?>/)[0];
        expect(img).toContain(`${PLUGIN_URL}/open/${this.draft.accountId}/${this.metadata.uid}`);
      });
    })
  });

  it("reports an error if the metadata is missing required fields", ()=>{
    this.draft.applyPluginMetadata(PLUGIN_ID, {});
    spyOn(NylasEnv, "reportError");
    OpenTrackingComposerExtension.finalizeSessionBeforeSending({session: this.session});
    expect(NylasEnv.reportError).toHaveBeenCalled()
  });
});

