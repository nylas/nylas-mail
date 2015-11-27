{MessageViewExtension, RegExpUtils} = require 'nylas-exports'

TrackingBlacklist = [{
    name: 'Sidekick',
    pattern: 't.signaux',
    homepage: 'http://getsidekick.com'
  }, {
    name: 'Sidekick',
    pattern: 't.senal',
    homepage: 'http://getsidekick.com'
  }, {
    name: 'Sidekick',
    pattern: 't.sidekickopen',
    homepage: 'http://getsidekick.com'
  }, {
    name: 'Sidekick',
    pattern: 't.sigopn',
    homepage: 'http://getsidekick.com'
  }, {
    name: 'Banana Tag',
    pattern: 'bl-1.com',
    homepage: 'http://bananatag.com'
  }, {
    name: 'Boomerang',
    pattern: 'mailstat.us/tr',
    homepage: 'http://boomeranggmail.com'
  }, {
    name: 'Cirrus Inisght',
    pattern: 'tracking.cirrusinsight.com',
    homepage: 'http://cirrusinsight.com'
  }, {
    name: 'Yesware',
    pattern: 'app.yesware.com',
    homepage: 'http://yesware.com'
  }, {
    name: 'Yesware',
    pattern: 't.yesware.com',
    homepage: 'http://yesware.com'
  }, {
    name: 'Streak',
    pattern: 'mailfoogae.appspot.com',
    homepage: 'http://streak.com'
  }, {
    name: 'LaunchBit',
    pattern: 'launchbit.com/taz-pixel',
    homepage: 'http://launchbit.com'
  }, {
    name: 'MailChimp',
    pattern: 'list-manage.com/track',
    homepage: 'http://mailchimp.com'
  }, {
    name: 'Postmark',
    pattern: 'cmail1.com/t',
    homepage: 'http://postmarkapp.com'
  }, {
    name: 'iContact',
    pattern: 'click.icptrack.com/icp/',
    homepage: 'http://icontact.com'
  }, {
    name: 'Infusionsoft',
    pattern: 'infusionsoft.com/app/emailOpened',
    homepage: 'http://infusionsoft.com'
  }, {
    name: 'Intercom',
    pattern: 'via.intercom.io/o',
    homepage: 'http://intercom.io'
  }, {
    name: 'Mandrill',
    pattern: 'mandrillapp.com/track',
    homepage: 'http://mandrillapp.com'
  }, {
    name: 'Hubspot',
    pattern: 't.hsms06.com',
    homepage: 'http://hubspot.com'
  }, {
    name: 'RelateIQ',
    pattern: 'app.relateiq.com/t.png',
    homepage: 'http://relateiq.com'
  }, {
    name: 'RJ Metrics',
    pattern: 'go.rjmetrics.com',
    homepage: 'http://rjmetrics.com'
  }, {
    name: 'Mixpanel',
    pattern: 'api.mixpanel.com/track',
    homepage: 'http://mixpanel.com'
  }, {
    name: 'Front App',
    pattern: 'web.frontapp.com/api',
    homepage: 'http://frontapp.com'
  }, {
    name: 'Mailtrack.io',
    pattern: 'mailtrack.io/trace',
    homepage: 'http://mailtrack.io'
  }, {
    name: 'Salesloft',
    pattern: 'sdr.salesloft.com/email_trackers',
    homepage: 'http://salesloft.com'
  }]

class TrackingPixelsExtension extends MessageViewExtension

  @formatMessageBody: (message) ->
    return unless message.isFromMe()

    regex = RegExpUtils.imageTagRegex()
    body = message.body
    spliceRegions = []

    # Identify img tags that should be cut out
    while (result = regex.exec(body)) isnt null
      for item in TrackingBlacklist
        if result[1].indexOf(item.pattern) > 0
          spliceRegions.push(start: result.index, end: result.index + result[0].length)
          continue

    # Remove them all, from the end of the string to the start
    spliceRegions.reverse().forEach ({start, end}) ->
      body = body.substr(0, start) + body.substr(end)
    message.body = body

module.exports = TrackingPixelsExtension
