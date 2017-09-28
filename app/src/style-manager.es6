import { Disposable } from 'event-kit';

export default class StyleManager {
  constructor() {
    this.styleElementsBySourcePath = {};

    this.el = document.createElement('managed-styles');
    document.head.appendChild(this.el);
  }

  getStyleElements() {
    return Array.from(this.el.children);
  }

  addStyleSheet(source, { sourcePath, priority } = {}) {
    let styleElement = sourcePath ? this.styleElementsBySourcePath[sourcePath] : null;

    if (styleElement) {
      styleElement.textContent = source;
    } else {
      styleElement = document.createElement('style');
      if (sourcePath !== undefined) {
        styleElement.sourcePath = sourcePath;
        styleElement.setAttribute('source-path', sourcePath);
        this.styleElementsBySourcePath[sourcePath] = styleElement;
      }
      if (priority !== undefined) {
        styleElement.priority = priority;
        styleElement.setAttribute('priority', priority);
      }
      styleElement.textContent = source;
      this.insertStyleElementIntoDOM(styleElement);
    }

    return new Disposable(() => this.removeStyleElement(styleElement));
  }

  insertStyleElementIntoDOM(styleElement) {
    const { priority } = styleElement;
    const beforeEl =
      priority !== undefined && this.getStyleElements().find(el => el.priority > priority);
    if (!beforeEl) {
      this.el.appendChild(styleElement);
    } else {
      this.el.insertBefore(styleElement, beforeEl);
    }
  }

  removeStyleElement(styleElement) {
    if (styleElement.sourcePath) {
      delete this.styleElementsBySourcePath[styleElement.sourcePath];
    }
    styleElement.remove();
  }

  getSnapshot() {
    return this.getStyleElements();
  }

  restoreSnapshot(styleElements) {
    for (const el of this.getStyleElements()) {
      this.removeStyleElement(el);
    }
    for (const el of styleElements) {
      const { sourcePath, priority } = el;
      this.addStyleSheet(el.textContent, { sourcePath, priority });
    }
  }
}
