import { ipcRenderer } from 'electron';
import InlineStyleTransformer from '../../src/services/inline-style-transformer';

describe('InlineStyleTransformer', function specs() {
  describe('run', () => {
    beforeEach(() => {
      spyOn(ipcRenderer, 'send');
      spyOn(InlineStyleTransformer, '_injectUserAgentStyles').andCallFake(input => input);
      InlineStyleTransformer._inlineStylePromises = {};
    });
    it('should return a Promise', () => {
      expect(InlineStyleTransformer.run('asd') instanceof Promise).toBe(true);
    });

    it('should resolve immediately if the html is empty', async () => {
      const promise = InlineStyleTransformer.run('');
      expect(await promise.isResolved()).toBe(true);
    });

    it('should resolve immediately if there is no <style> tag in the source', async () => {
      const promise = InlineStyleTransformer.run(`
      This is some tricky HTML but there's no style tag here!
      <I wonder if it'll get into trouble < style >. <Ohmgerd.>
      `);
      expect(await promise.isResolved()).toBe(true);
    });

    it("should properly remove comment tags used to prevent style tags from being displayed when they're not understood", () => {
      InlineStyleTransformer.run(`
      <style>
      <!--table
      {mso-displayed-decimal-separator:".";
      mso-displayed-thousand-separator:",";}
      -->
      </style>
      <style><!--table
      {mso-displayed-decimal-separator:".";
      mso-displayed-thousand-separator:",";}
      --></style>
      `);
      expect(ipcRenderer.send.mostRecentCall.args[1].html).toEqual(`
      <style>table
      {mso-displayed-decimal-separator:".";
      mso-displayed-thousand-separator:",";}
      </style>
      <style>table
      {mso-displayed-decimal-separator:".";
      mso-displayed-thousand-separator:",";}
      </style>
      `);
    });

    it('should add user agent styles', () => {
      InlineStyleTransformer.run(`<style>
      <!--table
        {mso-displayed-decimal-separator:".";
        mso-displayed-thousand-separator:",";}
      -->
      </style>Other content goes here`);
      expect(InlineStyleTransformer._injectUserAgentStyles).toHaveBeenCalled();
    });

    it('should fire inline-style-parse to the main process', () => {
      InlineStyleTransformer.run(`<style>
      <!--table
        {mso-displayed-decimal-separator:".";
        mso-displayed-thousand-separator:",";}
      -->
      </style>Other content goes here`);
      expect(ipcRenderer.send).toHaveBeenCalled();
      expect(ipcRenderer.send.mostRecentCall.args[0]).toEqual('inline-style-parse');
    });
  });
});
