AccountSidebarStore = require '../lib/account-sidebar-store'
{Folder, WorkspaceStore, CategoryStore} = require 'nylas-exports'

describe "AccountSidebarStore", ->
  describe "sections", ->
    it "should return the correct output", ->
      atom.testOrganizationUnit = 'folder'

      spyOn(CategoryStore, 'getStandardCategories').andCallFake ->
        return [
          new Folder(displayName:'Inbox', clientId: '1', name: 'inbox')
          new Folder(displayName:'Sent', clientId: '3', name: 'sent')
          new Folder(displayName:'Important', clientId: '4', name: 'important')
        ]

      spyOn(CategoryStore, 'getUserCategories').andCallFake ->
        return [
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

      expected = [
        {
          label: 'Mailboxes',
          items: [
            {
              id: '1',
              name: 'Inbox',
              mailViewFilter: {
                name: 'Inbox',
                category: {
                  client_id: '1',
                  name: 'inbox',
                  display_name: 'Inbox',
                  id: '1'
                },
                iconName: 'inbox.png'
              },
              children: [

              ]
            },
            {
              id: 'starred',
              name: 'Starred',
              mailViewFilter: {
                name: 'Starred',
                iconName: 'starred.png'
              },
              children: [

              ]
            },
            {
              id: '3',
              name: 'Sent',
              mailViewFilter: {
                name: 'Sent',
                category: {
                  client_id: '3',
                  name: 'sent',
                  display_name: 'Sent',
                  id: '3'
                },
                iconName: 'sent.png'
              },
              children: [

              ]
            },
            {
              id: '4',
              name: 'Important',
              mailViewFilter: {
                name: 'Important',
                category: {
                  client_id: '4',
                  name: 'important',
                  display_name: 'Important',
                  id: '4'
                },
                iconName: 'important.png'
              },
              children: [

              ]
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
              mailViewFilter: {
                name: 'A',
                category: {
                  client_id: 'a',
                  display_name: 'A',
                  id: 'a'
                },
                iconName: 'folder.png'
              },
              children: [
                {
                  id: 'a+b',
                  name: 'B',
                  mailViewFilter: {
                    name: 'A/B',
                    category: {
                      client_id: 'a+b',
                      display_name: 'A/B',
                      id: 'a+b'
                    },
                    iconName: 'folder.png'
                  },
                  children: [
                    {
                      id: 'a+b+c',
                      name: 'C',
                      mailViewFilter: {
                        name: 'A/B/C',
                        category: {
                          client_id: 'a+b+c',
                          display_name: 'A/B/C',
                          id: 'a+b+c'
                        },
                        iconName: 'folder.png'
                      },
                      children: [

                      ]
                    }
                  ]
                },
                {
                  id: 'a+d',
                  name: 'D',
                  mailViewFilter: {
                    name: 'A.D',
                    category: {
                      client_id: 'a+d',
                      display_name: 'A.D',
                      id: 'a+d'
                    },
                    iconName: 'folder.png'
                  },
                  children: [

                  ]
                },
                {
                  id: 'a+e',
                  name: 'E',
                  mailViewFilter: {
                    name: 'A\\E',
                    category: {
                      client_id: 'a+e',
                      display_name: 'A\\E',
                      id: 'a+e'
                    },
                    iconName: 'folder.png'
                  },
                  children: [

                  ]
                },
                {
                  id: 'a+b-c',
                  name: 'B-C',
                  mailViewFilter: {
                    name: 'A/B-C',
                    category: {
                      client_id: 'a+b-c',
                      display_name: 'A/B-C',
                      id: 'a+b-c'
                    },
                    iconName: 'folder.png'
                  },
                  children: [

                  ]
                }
              ]
            },
            {
              id: 'b',
              name: 'B',
              mailViewFilter: {
                name: 'B',
                category: {
                  client_id: 'b',
                  display_name: 'B',
                  id: 'b'
                },
                iconName: 'folder.png'
              },
              children: [
                {
                  id: 'b+c',
                  name: 'C',
                  mailViewFilter: {
                    name: 'B/C',
                    category: {
                      client_id: 'b+c',
                      display_name: 'B/C',
                      id: 'b+c'
                    },
                    iconName: 'folder.png'
                  },
                  children: [

                  ]
                }
              ]
            }
          ]
        }
      ]

      AccountSidebarStore._refreshSections()

      # Converting to JSON removes keys whose values are `undefined`,
      # makes the output smaller and easier to visually compare.
      output = JSON.parse(JSON.stringify(AccountSidebarStore.sections()))

      expect(output).toEqual(expected)
