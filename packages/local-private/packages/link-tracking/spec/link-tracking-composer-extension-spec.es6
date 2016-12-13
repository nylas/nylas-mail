import {Message} from 'nylas-exports';

import LinkTrackingComposerExtension from '../lib/link-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/link-tracking-constants';

const beforeBody = `TEST_BODY<br>
<a href="www.replaced.com">test</a>
<a style="color: #aaa" href="http://replaced.com">asdad</a>
<a hre="www.stillhere.com">adsasd</a>
<a stillhere="">stillhere</a>
<div href="stillhere"></div>
http://www.stillhere.com
<blockquote class="gmail_quote">twst<a style="color: #aaa" href="http://untouched.com">asdad</a></blockquote>`;

const afterBodyFactory = (accountId, messageUid) => `TEST_BODY<br>
<a href="${PLUGIN_URL}/link/${accountId}/${messageUid}/0?redirect=www.replaced.com">test</a>
<a style="color: #aaa" href="${PLUGIN_URL}/link/${accountId}/${messageUid}/1?redirect=http%3A%2F%2Freplaced.com">asdad</a>
<a hre="www.stillhere.com">adsasd</a>
<a stillhere="">stillhere</a>
<div href="stillhere"></div>
http://www.stillhere.com
<blockquote class="gmail_quote">twst<a style="color: #aaa" href="http://untouched.com">asdad</a></blockquote>`;

const nodeForHTML = (html) => {
  const fragment = document.createDocumentFragment();
  const node = document.createElement('root');
  fragment.appendChild(node);
  node.innerHTML = html;
  return node;
}

xdescribe('Link tracking composer extension', function linkTrackingComposerExtension() {
  describe("applyTransformsForSending", () => {
    beforeEach(() => {
      this.draft = new Message({accountId: "test"});
      this.draft.body = beforeBody;
      this.draftBodyRootNode = nodeForHTML(this.draft.body);
    });

    it("takes no action if there is no metadata", () => {
      LinkTrackingComposerExtension.applyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const afterBody = this.draftBodyRootNode.innerHTML;
      expect(afterBody).toEqual(beforeBody);
    });

    describe("With properly formatted metadata and correct params", () => {
      beforeEach(() => {
        this.metadata = {tracked: true};
        this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
      });

      it("replaces links in the unquoted portion of the body", () => {
        LinkTrackingComposerExtension.applyTransformsForSending({
          draftBodyRootNode: this.draftBodyRootNode,
          draft: this.draft,
        });

        const metadata = this.draft.metadataForPluginId(PLUGIN_ID);
        const afterBody = this.draftBodyRootNode.innerHTML;
        expect(afterBody).toEqual(afterBodyFactory(this.draft.accountId, metadata.uid));
      });

      it("sets a uid and list of links on the metadata", () => {
        LinkTrackingComposerExtension.applyTransformsForSending({
          draftBodyRootNode: this.draftBodyRootNode,
          draft: this.draft,
        });
        const metadata = this.draft.metadataForPluginId(PLUGIN_ID);
        expect(metadata.uid).not.toBeUndefined();
        expect(metadata.links).not.toBeUndefined();
        expect(metadata.links.length).toEqual(2);

        for (const link of metadata.links) {
          expect(link.click_count).toEqual(0);
        }
      });
    });
  });

  describe("unapplyTransformsForSending", () => {
    beforeEach(() => {
      this.metadata = {tracked: true, uid: '123'};
      this.draft = new Message({accountId: "test"});
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);
    });

    it("takes no action if there are no tracked links in the body", () => {
      this.draft.body = beforeBody;
      this.draftBodyRootNode = nodeForHTML(this.draft.body);

      LinkTrackingComposerExtension.unapplyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const afterBody = this.draftBodyRootNode.innerHTML;
      expect(afterBody).toEqual(beforeBody);
    });

    it("replaces tracked links with the original links, restoring the body exactly", () => {
      this.draft.body = afterBodyFactory(this.draft.accountId, this.metadata.uid);
      this.draftBodyRootNode = nodeForHTML(this.draft.body);

      LinkTrackingComposerExtension.unapplyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const afterBody = this.draftBodyRootNode.innerHTML;
      expect(afterBody).toEqual(beforeBody);
    });
  });
});
