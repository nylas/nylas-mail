import OpenTrackingComposerExtension from '../lib/open-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/open-tracking-constants';
import {Message, QuotedHTMLTransformer} from 'nylas-exports';

const quote = `<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;"> On Feb 25 2016, at 3:38 pm, Drew &lt;drew@nylas.com&gt; wrote: <br> twst </blockquote>`;

describe("Open tracking composer extension", () => {
  // Set up a draft, session that returns the draft, and metadata
  beforeEach(() => {
    this.draft = new Message({
      body: `<head></head><body>TEST_BODY ${quote}</body>`,
    });
  });

  describe("applyTransformsToDraft", () => {
    it("takes no action if there is no metadata", () => {
      const out = OpenTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});
      expect(out.body).toEqual(this.draft.body);
    });

    it("reports an error if the metadata is missing required fields", () => {
      this.draft.applyPluginMetadata(PLUGIN_ID, {});
      spyOn(NylasEnv, "reportError");
      OpenTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});
      expect(NylasEnv.reportError).toHaveBeenCalled()
    });

    describe("With properly formatted metadata and correct params", () => {
      beforeEach(() => {
        this.metadata = {uid: "TEST_UID"};
        this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
        const out = OpenTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});
        this.unquoted = QuotedHTMLTransformer.removeQuotedHTML(out.body);
      });

      it("appends an image to the unquoted body", () => {
        expect(this.unquoted).toMatch(/<img .*?>/);
      });

      it("has the right server URL", () => {
        const img = this.unquoted.match(/<img .*?>/)[0];
        expect(img).toContain(`${PLUGIN_URL}/open/${this.draft.accountId}/${this.metadata.uid}`);
      });
    });
  });

  describe("unapplyTransformsToDraft", () => {
    it("takes no action if the img tag is missing", () => {
      const out = OpenTrackingComposerExtension.unapplyTransformsToDraft({draft: this.draft});
      expect(out.body).toEqual(this.draft.body);
    });

    it("removes the image from the body and restore the body to it's exact original content", () => {
      this.metadata = {uid: "TEST_UID"};
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      const withImg = OpenTrackingComposerExtension.applyTransformsToDraft({draft: this.draft});

      const withoutImg = OpenTrackingComposerExtension.unapplyTransformsToDraft({draft: withImg});
      expect(withoutImg.body).toEqual(this.draft.body);
    });
  });
});
