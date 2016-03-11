import {MessageViewExtension, RegExpUtils} from 'nylas-exports'
import {PLUGIN_ID} from './link-tracking-constants'

export default class LinkTrackingMessageExtension extends MessageViewExtension {
  static formatMessageBody({message}) {
    const metadata = message.metadataForPluginId(PLUGIN_ID) || {};
    if ((metadata.links || []).length === 0) { return }
    const links = {}
    for (const link of metadata.links) {
      links[link.redirect_url] = link
    }

    message.body = message.body.replace(RegExpUtils.urlLinkTagRegex(), (match, openTagPrefix, aTagHref, openTagSuffix, content, closingTag) => {
      if (links[aTagHref]) {
        const openTag = openTagPrefix + aTagHref + openTagSuffix
        let title;
        let dotSrc;
        let newOpenTag;
        const titleRe = /title="[^"]*"|title='[^']*'/gi;

        if (!content) { return match; }
        if (content.search("link-tracking-dot") >= 0) { return match; }

        const originalUrl = links[aTagHref].url;
        const dotImgSrcPrefix = "nylas://link-tracking/assets/";
        const dotStyles = "margin-left: 1px; vertical-align: super; margin-right: 2px; zoom: 0.55;"

        if (links[aTagHref].click_count > 0) {
          title = ` title="Number of clicks: ${links[aTagHref].click_count} | ${originalUrl}" `;
          dotSrc = dotImgSrcPrefix + "ic-tracking-visited@2x.png"
        } else {
          title = ` title="Never been clicked | ${originalUrl}" `
          dotSrc = dotImgSrcPrefix + "ic-tracking-unvisited@2x.png"
        }
        const dot = `<img class="link-tracking-dot" src="${dotSrc}" style="${dotStyles}" />`

        if (titleRe.test(openTag)) {
          newOpenTag = openTag.replace(titleRe, title)
        } else {
          const tagLen = openTag.length
          newOpenTag = openTag.slice(0, tagLen - 1) + title + openTag.slice(tagLen - 1, tagLen)
        }
        return newOpenTag + content + dot + closingTag
      }
      return match;
    })
  }
}
