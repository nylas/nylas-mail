import {Message} from 'nylas-exports';
import OpenTrackingComposerExtension from '../lib/open-tracking-composer-extension'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/open-tracking-constants';

const accountId = 'fake-accountId';
const clientId = 'local-31d8df57-1442';
const beforeBody = `TEST_BODY <blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;"> On Feb 25 2016, at 3:38 pm, Drew &lt;drew@nylas.com&gt; wrote: <br> twst </blockquote>`;
const afterBody = `TEST_BODY <img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${PLUGIN_URL}/open/${accountId}/${clientId}"><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;"> On Feb 25 2016, at 3:38 pm, Drew &lt;drew@nylas.com&gt; wrote: <br> twst </blockquote>`;

const nodeForHTML = (html) => {
  const fragment = document.createDocumentFragment();
  const node = document.createElement('root');
  fragment.appendChild(node);
  node.innerHTML = html;
  return node;
}

xdescribe('Open tracking composer extension', function openTrackingComposerExtension() {
  describe("applyTransformsForSending", () => {
    beforeEach(() => {
      this.draftBodyRootNode = nodeForHTML(beforeBody);
      this.draft = new Message({
        clientId: clientId,
        accountId: accountId,
        body: beforeBody,
      });
    });

    it("takes no action if there is no metadata", () => {
      OpenTrackingComposerExtension.applyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const actualAfterBody = this.draftBodyRootNode.innerHTML;
      expect(actualAfterBody).toEqual(beforeBody);
    });

    describe("With properly formatted metadata and correct params", () => {
      beforeEach(() => {
        this.metadata = {open_count: 0};
        this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);

        OpenTrackingComposerExtension.applyTransformsForSending({
          draftBodyRootNode: this.draftBodyRootNode,
          draft: this.draft,
        });
        this.metadata = this.draft.metadataForPluginId(PLUGIN_ID);
      });

      it("appends an image with the correct server URL to the unquoted body", () => {
        const actualAfterBody = this.draftBodyRootNode.innerHTML;
        expect(actualAfterBody).toEqual(afterBody);
      });
    });
  });

  describe("unapplyTransformsForSending", () => {
    it("takes no action if the img tag is missing", () => {
      this.draftBodyRootNode = nodeForHTML(beforeBody);
      this.draft = new Message({
        clientId: clientId,
        accountId: accountId,
        body: beforeBody,
      });
      OpenTrackingComposerExtension.unapplyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const actualAfterBody = this.draftBodyRootNode.innerHTML;
      expect(actualAfterBody).toEqual(beforeBody);
    });

    it("removes the image from the body and restore the body to it's exact original content", () => {
      this.metadata = {open_count: 0};
      this.draft.applyPluginMetadata(PLUGIN_ID, this.metadata);

      this.draftBodyRootNode = nodeForHTML(afterBody);
      this.draft = new Message({
        clientId: clientId,
        accountId: accountId,
        body: afterBody,
      });
      OpenTrackingComposerExtension.unapplyTransformsForSending({
        draftBodyRootNode: this.draftBodyRootNode,
        draft: this.draft,
      });
      const actualAfterBody = this.draftBodyRootNode.innerHTML;
      expect(actualAfterBody).toEqual(beforeBody);
    });
  });
});
