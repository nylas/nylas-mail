import LinkTrackingComposerExtension from '../lib/link-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/link-tracking-constants';
import {Message, QuotedHTMLTransformer, Actions} from 'nylas-exports';

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

const quote = `<blockquote class="gmail_quote"> twst </blockquote>`;
const testBody = `<head></head><body>${testContent}${quote}</body>`;

const replacedBody = (accountId, messageUid, unquoted) =>
  `<head></head><body>${replacedContent(accountId, messageUid)}${unquoted ? "" : quote}</body>`;

describe("Link tracking composer extension", () => {
  // Set up a draft, session that returns the draft, and metadata
  beforeEach(() => {
    this.draft = new Message({accountId: "test"});
    this.draft.body = testBody;
  });

  describe("applyTransformsToDraft", () => {
    it("takes no action if there is no metadata", () => {
      const out = LinkTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});
      expect(out.body).toEqual(this.draft.body);
    });

    describe("With properly formatted metadata and correct params", () => {
      beforeEach(() => {
        this.metadata = {tracked: true};
        this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      });

      it("replaces links in the unquoted portion of the body", () => {
        spyOn(Actions, 'setMetadata')

        const out = LinkTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});
        const outUnquoted = QuotedHTMLTransformer.removeQuotedHTML(out.body);

        const metadata = Actions.setMetadata.mostRecentCall.args[2];
        expect(outUnquoted).toContain(replacedBody(this.draft.accountId, metadata.uid, true));
        expect(out.body).toContain(replacedBody(this.draft.accountId, metadata.uid, false));
      });

      it("sets a uid and list of links on the metadata", () => {
        spyOn(Actions, 'setMetadata')
        LinkTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});

        const metadata = Actions.setMetadata.mostRecentCall.args[2];
        expect(metadata.uid).not.toBeUndefined();
        expect(metadata.links).not.toBeUndefined();
        expect(metadata.links.length).toEqual(2);

        for (const link of metadata.links) {
          expect(link.click_count).toEqual(0);
        }
      });
    });
  });

  describe("unapplyTransformsToDraft", () => {
    it("takes no action if there are no tracked links in the body", () => {
      const out = LinkTrackingComposerExtension.unapplyTransformsToDraft({
        draft: this.draft.clone(),
      });
      expect(out.body).toEqual(this.draft.body);
    });

    it("replaces tracked links with the original links, restoring the body exactly", () => {
      this.metadata = {tracked: true};
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      const withImg = LinkTrackingComposerExtension.applyTransformsToDraft({
        draft: this.draft.clone(),
      });
      const withoutImg = LinkTrackingComposerExtension.unapplyTransformsToDraft({
        draft: withImg.clone(),
      });
      expect(withoutImg.body).toEqual(this.draft.body);
    });
  });
});
