RegExpUtils = require('nylas-exports').RegExpUtils

validEmail = (address) ->
  return RegExpUtils.emailRegex().test(address)

validDomain = (domain) ->
  return RegExpUtils.domainRegex().test(domain)

Providers = [
  {
    name: 'gmail'
    displayName: 'Gmail or Google Apps'
    icon: 'ic-settings-account-gmail.png'
    header_icon: 'setup-icon-provider-gmail.png'
    color: '#e99999'
    settings: []
  }, {
    name: 'exchange'
    displayName: 'Microsoft Exchange'
    icon: 'ic-settings-account-eas.png'
    header_icon: 'setup-icon-provider-exchange.png'
    color: '#1ea2a3'
    pages: ['Set up your email account', 'Exchange settings']
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
        required: true
        page: 0
      }, {
        name: 'email'
        type: 'email'
        placeholder: 'you@example.com'
        label: 'Email'
        isValid: validEmail
        required: true
        page: 0
      }
    ]
    settings: [
      {
        name: 'username'
        type: 'text'
        placeholder: 'MYCORP\\bob (if known)'
        label: 'Username (optional)'
        page: 1
      }, {
        name: 'password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        required: true
        page: 1
      }, {
        name: 'eas_server_host'
        type: 'text'
        placeholder: 'mail.company.com'
        label: 'Exchange server (optional)'
        isValid: validDomain
        page: 1
      }
    ]
  }, {
    name: 'icloud'
    displayName: 'iCloud'
    icon: 'ic-settings-account-icloud.png'
    header_icon: 'setup-icon-provider-icloud.png'
    color: '#61bfe9'
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
        required: true
        page: 0
      }, {
        name: 'email'
        type: 'email'
        placeholder: 'you@icloud.com'
        label: 'Email'
        isValid: validEmail
        required: true
        page: 0
      }
    ]
    settings: [{
      name: 'password'
      type: 'password'
      placeholder: 'Password'
      label: 'Password'
      required: true
      page: 0
    }]
  }, {
    name: 'outlook'
    displayName: 'Outlook.com'
    icon: 'ic-settings-account-outlook.png'
    header_icon: 'setup-icon-provider-outlook.png'
    color: '#1174c3'
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
        required: true
        page: 0
      }, {
        name: 'email'
        type: 'email'
        placeholder: 'you@hotmail.com'
        label: 'Email'
        isValid: validEmail
        required: true
        page: 0
      }
    ]
    settings: [{
        name: 'password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        required: true
        page: 0
      }]
  }, {
    name: 'yahoo'
    displayName: 'Yahoo'
    icon: 'ic-settings-account-yahoo.png'
    header_icon: 'setup-icon-provider-yahoo.png'
    color: '#a76ead'
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
        required: true
        page: 0
      }, {
        name: 'email'
        type: 'email'
        placeholder: 'you@yahoo.com'
        label: 'Email'
        isValid: validEmail
        required: true
        page: 0
      }
    ]
    settings: [{
      name: 'password'
      type: 'password'
      placeholder: 'Password'
      label: 'Password'
      required: true
    }]
  }, {
    name: 'imap'
    displayName: 'IMAP / SMTP Setup'
    icon: 'ic-settings-account-imap.png'
    header_icon: 'setup-icon-provider-imap.png'
    pages: ['Set up your email account','Configure incoming mail','Configure outgoing mail']
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
        page: 0
        required: true
      }, {
        name: 'email'
        type: 'email'
        placeholder: 'you@example.com'
        label: 'Email'
        isValid: validEmail
        page: 0
        required: true
      }
    ]
    settings: [
      {
        name: 'imap_host'
        type: 'text'
        placeholder: 'imap.domain.com'
        label: 'IMAP Server'
        page: 1
        required: true
        isValid: validDomain
      }, {
        name: 'imap_port'
        type: 'text'
        placeholder: '993'
        label: 'Port (optional)'
        className: 'half'
        default: 993
        format: 'integer'
        page: 1
      }, {
        name: 'imap_username'
        type: 'text'
        placeholder: 'Username'
        label: 'Username'
        page: 1
        required: true
      }, {
        name: 'imap_password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        page: 1
        required: true
      }, {
        name: 'smtp_host'
        type: 'text'
        placeholder: 'smtp.domain.com'
        label: 'SMTP Server'
        page: 2
        required: true
        isValid: validDomain
      }, {
        name: 'smtp_port'
        type: 'text'
        placeholder: '587'
        label: 'Port (optional)'
        className: 'half'
        format: 'integer'
        default: 587
        page: 2
      }, {
        name: 'smtp_username'
        type: 'text'
        placeholder: 'Username'
        label: 'Username'
        page: 2
        required: true
      }, {
        name: 'smtp_password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        page: 2
        required: true
      }
    ]
#  }, {
#    name: 'default'
#    displayName: ''
#    icon: ''
#    color: ''
#    fields: [
#      {
#        name: 'name'
#        type: 'text'
#        placeholder: 'Ashton Letterman'
#        label: 'Name'
#      }, {
#        name: 'email'
#        type: 'text'
#        placeholder: 'you@example.com'
#        label: 'Email'
#      }
#    ]
#    settings: [
#      {
#        name: 'username'
#        type: 'text'
#        placeholder: 'Username'
#        label: 'Username'
#      }, {
#        name: 'password'
#        type: 'password'
#        placeholder: 'Password'
#        label: 'Password'
#      }
#    ]
  }
]

module.exports = Providers
