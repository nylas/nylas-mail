import LinkTrackingComposerExtension from '../lib/link-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/link-tracking-constants';
import {Message, QuotedHTMLTransformer} from 'nylas-exports';

const testContent = `TEST_BODY<br>
<a href="www.replaced.com">test</a>
<a style="color: #aaa" href="http://replaced">asdad</a>
<a hre="www.stillhere.com">adsasd</a>
<a stillhere="">stillhere</a>
<div href="stillhere"></div>
http://www.stillhere.com`;

const replacedContent = (accountId, messageUid) => `TEST_BODY<br>
<a href="${PLUGIN_URL}/link/${accountId}/${messageUid}/0?redirect=www.replaced.com">test</a>
<a style="color: #aaa" href="${PLUGIN_URL}/link/${accountId}/${messageUid}/1?redirect=http%3A%2F%2Freplaced">asdad</a>
<a hre="www.stillhere.com">adsasd</a>
<a stillhere="">stillhere</a>
<div href="stillhere"></div>
http://www.stillhere.com`;

const quote = `<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;"> On Feb 25 2016, at 3:38 pm, Drew &lt;drew@nylas.com&gt; wrote: <br> twst </blockquote>`;
const testBody = `<body>${testContent}${quote}</body>`;
const replacedBody = (accountId, messageUid, unquoted) => `<body>${replacedContent(accountId, messageUid)}${unquoted ? "" : quote}</body>`;

describe("Open tracking composer extension", () => {
  // Set up a draft, session that returns the draft, and metadata
  beforeEach(()=>{
    this.draft = new Message({accountId: "test"});
    this.draft.body = testBody;
    this.session = {
      draft: () => this.draft,
      changes: jasmine.createSpyObj('changes', ['add', 'commit']),
    };
  });

  it("takes no action if there is no metadata", ()=>{
    LinkTrackingComposerExtension.finalizeSessionBeforeSending({session: this.session});
    expect(this.session.changes.add).not.toHaveBeenCalled();
    expect(this.session.changes.commit).not.toHaveBeenCalled();
  });

  describe("With properly formatted metadata and correct params", () => {
    // Set metadata on the draft and call finalizeSessionBeforeSending
    beforeEach(()=>{
      this.metadata = {tracked: true};
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      LinkTrackingComposerExtension.finalizeSessionBeforeSending({session: this.session});
    });

    it("adds (but does not commit) the changes to the session", ()=>{
      expect(this.session.changes.add).toHaveBeenCalled();
      expect(this.session.changes.add.mostRecentCall.args[0].body).toBeDefined();
      expect(this.session.changes.commit).not.toHaveBeenCalled();
    });

    describe("On the unquoted body", () => {
      beforeEach(()=>{
        this.body = this.session.changes.add.mostRecentCall.args[0].body;
        this.unquoted = QuotedHTMLTransformer.removeQuotedHTML(this.body);

        waitsFor(()=>this.metadata.uid)
      });

      it("sets a uid and list of links on the metadata", ()=>{
        runs(() => {
          expect(this.metadata.uid).not.toBeUndefined();
          expect(this.metadata.links).not.toBeUndefined();
          expect(this.metadata.links.length).toEqual(2);

          for (const link of this.metadata.links) {
            expect(link.click_count).toEqual(0);
          }
        })
      });

      it("replaces all the valid href URLs with redirects", ()=>{
        runs(() => {
          expect(this.unquoted).toContain(replacedBody(this.draft.accountId, this.metadata.uid, true));
          expect(this.body).toContain(replacedBody(this.draft.accountId, this.metadata.uid, false));
        })
      });
    })
  });
});

