import { DOMUtils } from 'nylas-exports';
import BlockquoteManager from '../../src/components/contenteditable/blockquote-manager';

describe("BlockquoteManager", function BlockquoteManagerSpecs() {
  const outdentCases = [`
  <div>|</div>
  `,
    `
  <div>
    <span>|</span>
  </div>
  `,
    `
  <p></p>
  <span>\n</span>
  <span>|</span>
  `,
    `
  <span></span>
  <p></p>
  <span></span>
  <span>|</span>
  `,
    `
  <div>
    <div>
      <div>|</div>
    </div>
  </div>
  `,
    `
  <div>
    <span></span>
    <span>|</span>
  </div>
  `,
    `
  <span></span>
  <p><span>yo</span></p>
  <span></span>
  <span>
    <span></span>
    <span></span>
    <span>|test</span>
  </span>
  `,
  ]

  const backspaceCases = [`
  <div>yo|</div>
  `,
    `
  <div>
    yo
    <span>|</span>
  </div>
  `,
    `
  <p></p>
  <span>&nbsp;</span>
  <span>|</span>
  `,
    `
  <span></span>
  <p></p>
  <span>yo</span>
  <span>|</span>
  `,
    `
  <div>
    <div>
      <div>yo|</div>
    </div>
  </div>
  `,
    `
  <div>
    <span>yo</span>
    <span>|</span>
  </div>
  `,
    `
  <span></span>
  <p><span>yo</span></p>
  <span></span>
  <span>
    <span>yo</span>
    <span></span>
    <span>|test</span>
  </span>
  `,
  ]

  const setupContext = (testCase) => {
    const context = document.createElement("blockquote");
    context.innerHTML = testCase;
    const {node, index} = DOMUtils.findCharacter(context, "|");
    if (!node) {
      throw new Error("Couldn't find where to set Selection");
    }
    const mockSelection = {
      isCollapsed: true,
      anchorNode: node,
      anchorOffset: index,
    };
    return mockSelection;
  };

  outdentCases.forEach(testCase =>
    it(`outdents\n${testCase}`, () => {
      const mockSelection = setupContext(testCase);
      const editor = {currentSelection() { return mockSelection; }};
      expect(BlockquoteManager._isInBlockquote(editor)).toBe(true);
      return expect(BlockquoteManager._isAtStartOfLine(editor)).toBe(true);
    })
  );

  return backspaceCases.forEach(testCase =>
    it(`backspaces (does NOT outdent)\n${testCase}`, () => {
      const mockSelection = setupContext(testCase);
      const editor = {currentSelection() { return mockSelection; }};
      expect(BlockquoteManager._isInBlockquote(editor)).toBe(true);
      return expect(BlockquoteManager._isAtStartOfLine(editor)).toBe(false);
    })
  );
});
