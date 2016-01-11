AccountSidebarStore = require '../lib/account-sidebar-store'
{Folder, WorkspaceStore, CategoryStore, AccountStore} = require 'nylas-exports'
NylasEnv.testOrganizationUnit = 'folder'

describe "AccountSidebarStore", ->
  describe "sections", ->
    it "should return the correct output", ->

      account = AccountStore.accounts()[0]
      account.organizationUnit = 'folder'
      # Converting to JSON removes keys whose values are `undefined`,
      # makes the output smaller and easier to visually compare.
      jsonAcc = JSON.parse(JSON.stringify(account))
      AccountSidebarStore._account = account

      spyOn(CategoryStore, 'standardCategories').andReturn [
        new Folder(displayName:'Inbox', clientId: '1', name: 'inbox')
        new Folder(displayName:'Sent', clientId: '3', name: 'sent')
        new Folder(displayName:'Important', clientId: '4', name: 'important')
      ]

      spyOn(CategoryStore, 'userCategories').andReturn [
        new Folder(displayName:'A', clientId: 'a')
        new Folder(displayName:'B', clientId: 'b')
        new Folder(displayName:'A/B', clientId: 'a+b')
        new Folder(displayName:'A.D', clientId: 'a+d')
        new Folder(displayName:'A\\E', clientId: 'a+e')
        new Folder(displayName:'B/C', clientId: 'b+c')
        new Folder(displayName:'A/B/C', clientId: 'a+b+c')
        new Folder(displayName:'A/B-C', clientId: 'a+b-c')
      ]

      spyOn(WorkspaceStore, 'sidebarItems').andCallFake ->
        return [
          new WorkspaceStore.SidebarItem
            component: {}
            sheet: 'stub'
            id: 'Drafts'
            name: 'Drafts'
        ]

      # Note: If you replace this JSON with new JSON, you may have to replace
      # A\E with A\\E manually.
      expected = [{
        label: 'Mailboxes',
        items: [
          {
            id: '1',
            name: 'Inbox',
            mailboxPerspective: {
              name: 'Inbox',
              category: {
                client_id: '1',
                name: 'inbox',
                display_name: 'Inbox',
                id: '1'
              },
              iconName: 'inbox.png'
              account: jsonAcc
            },
            children: [

            ],
            unreadCount: null
          },
          {
            id: 'starred',
            name: 'Starred',
            mailboxPerspective: {
              name: 'Starred',
              iconName: 'starred.png'
              account: jsonAcc
            },
            children: [

            ]
          },
          {
            id: '3',
            name: 'Sent',
            mailboxPerspective: {
              name: 'Sent',
              category: {
                client_id: '3',
                name: 'sent',
                display_name: 'Sent',
                id: '3'
              },
              iconName: 'sent.png'
              account: jsonAcc
            },
            children: [

            ],
            unreadCount: 0
          },
          {
            id: '4',
            name: 'Important',
            mailboxPerspective: {
              name: 'Important',
              category: {
                client_id: '4',
                name: 'important',
                display_name: 'Important',
                id: '4'
              },
              iconName: 'important.png'
              account: jsonAcc
            },
            children: [

            ],
            unreadCount: 0
          },
          {
            id: 'Drafts',
            component: {

            },
            name: 'Drafts',
            sheet: 'stub',
            children: [

            ]
          }
        ]
      },
      {
        label: 'Folders',
        items: [
          {
            id: 'a',
            name: 'A',
            mailboxPerspective: {
              name: 'A',
              category: {
                client_id: 'a',
                display_name: 'A',
                id: 'a'
              },
              iconName: 'folder.png'
              account: jsonAcc
            },
            children: [
              {
                id: 'a+b',
                name: 'B',
                mailboxPerspective: {
                  name: 'A/B',
                  category: {
                    client_id: 'a+b',
                    display_name: 'A/B',
                    id: 'a+b'
                  },
                  iconName: 'folder.png'
                  account: jsonAcc
                },
                children: [
                  {
                    id: 'a+b+c',
                    name: 'C',
                    mailboxPerspective: {
                      name: 'A/B/C',
                      category: {
                        client_id: 'a+b+c',
                        display_name: 'A/B/C',
                        id: 'a+b+c'
                      },
                      iconName: 'folder.png'
                      account: jsonAcc
                    },
                    children: [

                    ],
                    unreadCount: 0
                  }
                ],
                unreadCount: 0
              },
              {
                id: 'a+d',
                name: 'D',
                mailboxPerspective: {
                  name: 'A.D',
                  category: {
                    client_id: 'a+d',
                    display_name: 'A.D',
                    id: 'a+d'
                  },
                  iconName: 'folder.png'
                  account: jsonAcc
                },
                children: [

                ],
                unreadCount: 0
              },
              {
                id: 'a+e',
                name: 'E',
                mailboxPerspective: {
                  name: 'A\\E',
                  category: {
                    client_id: 'a+e',
                    display_name: 'A\\E',
                    id: 'a+e'
                  },
                  iconName: 'folder.png'
                  account: jsonAcc
                },
                children: [

                ],
                unreadCount: 0
              },
              {
                id: 'a+b-c',
                name: 'B-C',
                mailboxPerspective: {
                  name: 'A/B-C',
                  category: {
                    client_id: 'a+b-c',
                    display_name: 'A/B-C',
                    id: 'a+b-c'
                  },
                  iconName: 'folder.png'
                  account: jsonAcc
                },
                children: [

                ],
                unreadCount: 0
              }
            ],
            unreadCount: 0
          },
          {
            id: 'b',
            name: 'B',
            mailboxPerspective: {
              name: 'B',
              category: {
                client_id: 'b',
                display_name: 'B',
                id: 'b'
              },
              iconName: 'folder.png'
              account: jsonAcc
            },
            children: [
              {
                id: 'b+c',
                name: 'C',
                mailboxPerspective: {
                  name: 'B/C',
                  category: {
                    client_id: 'b+c',
                    display_name: 'B/C',
                    id: 'b+c'
                  },
                  iconName: 'folder.png'
                  account: jsonAcc
                },
                children: [

                ],
                unreadCount: 0
              }
            ],
            unreadCount: 0
          }
        ],
        iconName: 'folder.png'
      }]

      AccountSidebarStore._updateSections()

      # Converting to JSON removes keys whose values are `undefined`,
      # makes the output smaller and easier to visually compare.
      output = JSON.parse(JSON.stringify(AccountSidebarStore.sections()))

      expect(output).toEqual(expected)
