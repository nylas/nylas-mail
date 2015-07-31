File = require '../../src/flux/models/file'

test_file_path = "/path/to/file.jpg"

describe "File", ->
  it "attempts to generate a new file upload task on creation", ->
    # File.create(test_file_path)

  describe "displayName", ->
    it "should return the filename if populated", ->
      f = new File(filename: 'Hello world.jpg', contentType: 'image/jpg')
      expect(f.displayName()).toBe('Hello world.jpg')
      f = new File(filename: 'a', contentType: 'image/jpg')
      expect(f.displayName()).toBe('a')

    it "should return a good default name if a content type is populated", ->
      f = new File(filename: '', contentType: 'image/jpg')
      expect(f.displayName()).toBe('Unnamed Image.jpg')
      f = new File(filename: null, contentType: 'image/jpg')
      expect(f.displayName()).toBe('Unnamed Image.jpg')
      f = new File(filename: null, contentType: 'text/calendar')
      expect(f.displayName()).toBe('Event.ics')

    it "should return Unnamed Attachment otherwise", ->
      f = new File(filename: '', contentType: null)
      expect(f.displayName()).toBe('Unnamed Attachment')
      f = new File(filename: null, contentType: '')
      expect(f.displayName()).toBe('Unnamed Attachment')
      f = new File(filename: null, contentType: null)
      expect(f.displayName()).toBe('Unnamed Attachment')

  describe "displayExtension", ->
    it "should return an extension based on the filename when populated", ->
      f = new File(filename: 'Hello world.jpg', contentType: 'image/jpg')
      expect(f.displayExtension()).toBe('jpg')
      f = new File(filename: 'a', contentType: 'image/jpg')
      expect(f.displayExtension()).toBe('')

    it "should return an extension based on the default filename otherwise", ->
      f = new File(filename: '', contentType: 'image/jpg')
      expect(f.displayExtension()).toBe('jpg')
      f = new File(filename: null, contentType: 'text/calendar')
      expect(f.displayExtension()).toBe('ics')
