

Providers = [
  {
    name: 'gmail'
    displayName: 'Gmail'
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
    fields: [
      {
        name: 'name'
        type: 'text'
        placeholder: 'Ashton Letterman'
        label: 'Name'
      }, {
        name: 'email'
        type: 'text'
        placeholder: 'you@example.com'
        label: 'Email'
      }
    ]
    settings: [
      {
        name: 'username'
        type: 'text'
        placeholder: 'MYCORP\\bob (if known)'
        label: 'Username (optional)'
      }, {
        name: 'password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
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
      }, {
        name: 'email'
        type: 'text'
        placeholder: 'you@icloud.com'
        label: 'Email'
      }
    ]
    settings: [{
      name: 'password'
      type: 'password'
      placeholder: 'Password'
      label: 'Password'
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
      }, {
        name: 'email'
        type: 'text'
        placeholder: 'you@yahoo.com'
        label: 'Email'
      }
    ]
    settings: [{
      name: 'password'
      type: 'password'
      placeholder: 'Password'
      label: 'Password'
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
      }, {
        name: 'email'
        type: 'text'
        placeholder: 'you@example.com'
        label: 'Email'
        page: 0
      }
    ]
    settings: [
      {
        name: 'imap_host'
        type: 'text'
        placeholder: 'imap.domain.com'
        label: 'IMAP Server'
        page: 1
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
        name: 'imap_ssl_enabled'
        type: 'checkbox'
        label: 'Use SSL'
        className: 'half'
        default: true
        page: 1
      }, {
        name: 'imap_username'
        type: 'text'
        placeholder: 'Username'
        label: 'Username'
        page: 1
      }, {
        name: 'imap_password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        page: 1
      }, {
        name: 'smtp_host'
        type: 'text'
        placeholder: 'smtp.domain.com'
        label: 'SMTP Server'
        page: 2
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
        name: 'smtp_ssl_enabled'
        type: 'checkbox'
        label: 'Use SSL'
        className: 'half'
        default: true
        page: 2
      }, {
        name: 'smtp_username'
        type: 'text'
        placeholder: 'Username'
        label: 'Username'
        page: 2
      }, {
        name: 'smtp_password'
        type: 'password'
        placeholder: 'Password'
        label: 'Password'
        page: 2
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
