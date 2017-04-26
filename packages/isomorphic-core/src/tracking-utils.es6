/**
 * These contain utility methods for link and open tracking.
 *
 * We need to perform some final transforms on the tracking links just
 * before send. Since we send from:
 *
 * 1) client-sync: SendMessageSMTP
 * 2) client-sync: SendMessagePerRecipientSMTP
 * 3) cloud-workers: sendPerRecipient
 *
 * we need to store these functions in isomorphic-core
 *
 * Open/Link tracking is a multi-step process.
 */
import url from 'url'

class TrackingUtils {
  /**
   * STEP 1: Put Message ID in tracking links
   *
   * When OpenTrackingComposerExtension or LinkTrackingComposerExtension
   * insert tracking links into a draft body, these composer plugins don't
   * yet know what the messageId will be. Once we generate a messageId in
   * build for send, we replace the hardcoded `MESSAGE_ID` placeholder with
   * the actual messageId. Have the messageId in the link is necessary for
   * the cloud-api to figure out what link or open tracking pixel someone
   * accessed.
   */
  prepareTrackingLinks(messageId, originalBody) {
    const regex = new RegExp(`(https://.+?)MESSAGE_ID`, 'g')
    const body = originalBody.replace(regex, `$1${messageId}`);
    return this.addSrcToOpenTrackingPixel(body);
  }

  /**
   * STEP 2: Update open tracking src parameter
   *
   * Open tracking uses an image who's src points to our cloud-api. We
   * don't actually want to give the img a `src` until this step since the
   * link doesn't actually resolve to anything until now. Since we
   * immediately render all changes to draft bodies in the client-app, if
   * we don't do this the cloud-api servers will get a whole bunch of `GET
   * /open/MESSAGE_ID` stub requests from the incomplete open pixel
   */
  addSrcToOpenTrackingPixel(originalBody) {
    return originalBody.replace("data-open-tracking-src", "src")
  }

  /**
   * STEP 3: Add individualized recipient data to tracking links
   *
   * By default the open and link tracking urls don't indicate who that link
   * is tailored to. When we send to individual people, we need to add an
   * extra parameter to the end of the tracking url with the email of who
   * it's being sent to.
   *
   * We use the `recipient` query parameter to indicate who the Recipient is.
   *
   * The cloud-api routes/link-tracking and routes/open-tracking know to
   * look for the `recipient` query param when determining who clicked the
   * link.
   */
  addRecipientToTrackingLinks({baseMessage, recipient, usesOpenTracking, usesLinkTracking} = {}) {
    let body = baseMessage.body

    if (usesOpenTracking) {
      // This adds a `recipient` param to the open tracking src url.
      body = body.replace(/<img class="n1-open".*?src="(.*?)">/g, (match, src) => {
        const newSrc = this._addRecipientToUrl(src, recipient.email)
        return `<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${newSrc}">`;
      });
    }

    if (usesLinkTracking) {
      // This adds a `recipient` param to the link tracking tracking href url.
      body = body.replace(this._urlLinkTagRegex(), (match, prefix, href, suffix, content, closingTag) => {
        const newHref = this._addRecipientToUrl(href, recipient.email)
        return `${prefix}${newHref}${suffix}${content}${closingTag}`;
      });
    }

    return body;
  }

  /**
   * STEP 4: Remove all link data from your own emails to prevent
   * self-triggering
   *
   * When we save a message to a user's sent folder, we don't want that
   * message to have link tracking data in it. Immediately after the message
   * is sent, we save a stripped-version of the message to the database.
   */
  stripTrackingLinksFromBody(originalBody) {
    // Removes open tracking images.
    let body = originalBody.replace(/<img class="n1-open".*?>/g, "");

    // Replaces link tracking links with the original link.
    // Link tracking looks like:
    // <a href="https://n1.nylas.com/link/81ae3fe62cb9e5d674d94ea5d7c3f0e65fb2a93fe357f2db5452575a7c5d0165/0?redirect=https%3A%2F%2Fnylas.com%3Fref%3Dn1&r=ZXZhbkBldmFubW9yaWthd2EuY29t">Nylas Mail</a>
    //
    // See https://regex101.com/r/Tr0LLT/1 for this._urlLinkTagRegex on example
    // link.
    // The link-tracking/lib/link-tracking-composer-extension.es6
    // will add a `redirect` query param that has the original url.
    body = body.replace(this._urlLinkTagRegex(), (match, prefix, href, suffix, content, closingTag) => {
      if (!/nylas\.com/.test(href)) return match
      const originalUrl = (url.parse(href, true).query || {}).redirect
      if (!originalUrl) return match
      return `${prefix}${originalUrl}${suffix}${content}${closingTag}`;
    });
    return body;
  }

  _addRecipientToUrl(originalUrl, email) {
    const parsed = url.parse(originalUrl, true);
    const query = parsed.query || {}
    query.recipient = email;
    parsed.query = query;
    parsed.search = null // so the format will use the query. See url docs.
    return parsed.format()
  }

  // Copied from regexp-utils.coffee.
  // Test cases: https://regex101.com/r/cK0zD8/4
  // Catches link tags containing which are:
  // - Non empty
  // - Not a mailto: link
  // Returns the following capturing groups:
  // 1. start of the opening a tag to href="
  // 2. The contents of the href without quotes
  // 3. the rest of the opening a tag
  // 4. the contents of the a tag
  // 5. the closing tag
  _urlLinkTagRegex() {
    return new RegExp(/(<a.*?href\s*?=\s*?['"])((?!mailto).+?)(['"].*?>)([\s\S]*?)(<\/a>)/gim);
  }

}

export default new TrackingUtils();
