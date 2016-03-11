import {Message} from 'nylas-exports'
import {PLUGIN_ID, PLUGIN_URL} from '../lib/link-tracking-constants';
import LinkTrackingAfterSend from '../lib/link-tracking-after-send'

describe("Link tracking afterDraftSend callback", () => {
  beforeEach(() => {
    this.message = new Message();
    this.postResponse = 200;
    spyOn(LinkTrackingAfterSend, "post").andCallFake(() => Promise.resolve([{statusCode: this.postResponse}, ""]));
    spyOn(NylasEnv, "isMainWindow").andReturn(true);
  });

  it("takes no action when the message has no metadata", () => {
    LinkTrackingAfterSend.afterDraftSend({message: this.message});
    expect(LinkTrackingAfterSend.post).not.toHaveBeenCalled();
  });

  it("takes no action when the message has malformed metadata", () => {
    this.message.applyPluginMetadata(PLUGIN_ID, {gar: "bage"});
    LinkTrackingAfterSend.afterDraftSend({message: this.message});
    expect(LinkTrackingAfterSend.post).not.toHaveBeenCalled();
  });

  describe("When metadata is present", () => {
    beforeEach(() => {
      this.metadata = {uid: "TEST_UID"};
      this.message.applyPluginMetadata(PLUGIN_ID, this.metadata);
    });

    it("posts UID => message ID to the server", () => {
      // Spy on the POST request, then call the afterDraftSend function
      LinkTrackingAfterSend.afterDraftSend({message: this.message});

      expect(LinkTrackingAfterSend.post).toHaveBeenCalled();
      const {url, body} = LinkTrackingAfterSend.post.mostRecentCall.args[0];
      const {uid, message_id} = JSON.parse(body);

      expect(url).toEqual(`${PLUGIN_URL}/plugins/register-message`);
      expect(uid).toEqual(this.metadata.uid);
      expect(message_id).toEqual(this.message.id);
    });


    it("shows an error dialog if the request fails", () => {
      // Spy on the POST request and dialog function
      this.postResponse = 400;
      spyOn(NylasEnv, "showErrorDialog");
      spyOn(NylasEnv, "reportError");

      LinkTrackingAfterSend.afterDraftSend({message: this.message});

      expect(LinkTrackingAfterSend.post).toHaveBeenCalled();

      waitsFor(() => {
        return NylasEnv.reportError.callCount > 0;
      });
      runs(() => {
        expect(NylasEnv.showErrorDialog).toHaveBeenCalled();
        expect(NylasEnv.reportError).toHaveBeenCalled();
      });
    });
  });
});
