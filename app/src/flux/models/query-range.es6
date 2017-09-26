export default class QueryRange {
  static infinite() {
    return new QueryRange({ limit: null, offset: null });
  }

  static rangeWithUnion(a, b) {
    if (a.isInfinite() || b.isInfinite()) {
      return QueryRange.infinite();
    }
    if (!a.isContiguousWith(b)) {
      throw new Error('You cannot union ranges which do not touch or intersect.');
    }

    return new QueryRange({
      start: Math.min(a.start, b.start),
      end: Math.max(a.end, b.end),
    });
  }

  static rangesBySubtracting(a, b) {
    if (!b) {
      return [];
    }

    if (a.isInfinite() || b.isInfinite()) {
      throw new Error('You cannot subtract infinite ranges.');
    }

    const uncovered = [];
    if (b.start > a.start) {
      uncovered.push(new QueryRange({ start: a.start, end: Math.min(a.end, b.start) }));
    }
    if (b.end < a.end) {
      uncovered.push(new QueryRange({ start: Math.max(a.start, b.end), end: a.end }));
    }
    return uncovered;
  }

  get start() {
    return this.offset;
  }

  get end() {
    return this.offset + this.limit;
  }

  constructor({ limit, offset, start, end } = {}) {
    this.limit = limit;
    this.offset = offset;

    if (start !== undefined && offset === undefined) {
      this.offset = start;
    }
    if (end !== undefined && limit === undefined) {
      this.limit = end - this.offset;
    }

    if (this.limit === undefined) {
      throw new Error('You must specify a limit');
    }
    if (this.offset === undefined) {
      throw new Error('You must specify an offset');
    }
  }

  clone() {
    const { limit, offset } = this;
    return new QueryRange({ limit, offset });
  }

  isInfinite() {
    return this.limit === null && this.offset === null;
  }

  isEqual(b) {
    return this.start === b.start && this.end === b.end;
  }

  // Returns true if joining the two ranges would not result in empty space.
  // ie: they intersect or touch
  isContiguousWith(b) {
    if (this.isInfinite() || b.isInfinite()) {
      return true;
    }
    return (
      (this.start <= b.start && b.start <= this.end) || (this.start <= b.end && b.end <= this.end)
    );
  }

  toString() {
    return `QueryRange{${this.start} - ${this.end}}`;
  }
}
