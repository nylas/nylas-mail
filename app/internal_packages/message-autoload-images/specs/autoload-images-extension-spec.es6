import fs from 'fs';
import path from 'path';
import AutoloadImagesExtension from '../lib/autoload-images-extension';
import AutoloadImagesStore from '../lib/autoload-images-store';

describe('AutoloadImagesExtension', function autoloadImagesExtension() {
  describe('formatMessageBody', () => {
    const scenarios = [];
    const fixtures = path.resolve(path.join(__dirname, 'fixtures'));

    fs.readdirSync(fixtures).forEach(filename => {
      if (filename.endsWith('-in.html')) {
        const name = filename.replace('-in.html', '');

        scenarios.push({
          name: name,
          in: fs.readFileSync(path.join(fixtures, filename)).toString(),
          out: fs.readFileSync(path.join(fixtures, `${name}-out.html`)).toString(),
        });
      }
    });

    scenarios.forEach(scenario => {
      it(`should process ${scenario.name}`, () => {
        spyOn(AutoloadImagesStore, 'shouldBlockImagesIn').andReturn(true);

        const message = {
          body: scenario.in,
        };
        AutoloadImagesExtension.formatMessageBody({ message });

        expect(message.body === scenario.out).toBe(true);
      });
    });
  });
});
