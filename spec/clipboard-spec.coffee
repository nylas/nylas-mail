describe "Clipboard", ->
  describe "write(text, metadata) and read()", ->
    it "writes and reads text to/from the native clipboard", ->
      expect(NylasEnv.clipboard.read()).toBe 'initial clipboard content'
      NylasEnv.clipboard.write('next')
      expect(NylasEnv.clipboard.read()).toBe 'next'

    it "returns metadata if the item on the native clipboard matches the last written item", ->
      NylasEnv.clipboard.write('next', {meta: 'data'})
      expect(NylasEnv.clipboard.read()).toBe 'next'
      expect(NylasEnv.clipboard.readWithMetadata().text).toBe 'next'
      expect(NylasEnv.clipboard.readWithMetadata().metadata).toEqual {meta: 'data'}
