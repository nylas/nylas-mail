import React from 'react';
import FixedPopover from '../../src/components/fixed-popover';
import { renderIntoDocument } from '../mailspring-test-utils';

const { Directions: { Up, Down, Left, Right } } = FixedPopover;

const makePopover = (props = {}) => {
  const originRect = props.originRect ? props.originRect : {};
  const popover = renderIntoDocument(<FixedPopover {...props} originRect={originRect} />);
  if (props.initialState) {
    popover.setState(props.initialState);
  }
  return popover;
};

describe('FixedPopover', function fixedPopover() {
  describe('computeAdjustedOffsetAndDirection', () => {
    beforeEach(() => {
      this.popover = makePopover();
      this.PADDING = 10;
      this.windowDimensions = {
        height: 500,
        width: 500,
      };
    });

    const compute = (direction, { fallback, top, left, bottom, right }) => {
      return this.popover.computeAdjustedOffsetAndDirection({
        direction,
        windowDimensions: this.windowDimensions,
        currentRect: {
          top,
          left,
          bottom,
          right,
        },
        fallback,
        offsetPadding: this.PADDING,
      });
    };

    it('returns null when no overflows present', () => {
      const res = compute(Up, { top: 10, left: 10, right: 20, bottom: 20 });
      expect(res).toBe(null);
    });

    describe('when overflowing on 1 side of the window', () => {
      it('returns fallback direction when it is specified', () => {
        const { offset, direction } = compute(Up, {
          fallback: Left,
          top: -10,
          left: 10,
          right: 20,
          bottom: 10,
        });
        expect(offset).toEqual({});
        expect(direction).toEqual(Left);
      });

      it('inverts direction if is Up and overflows on the top', () => {
        const { offset, direction } = compute(Up, { top: -10, left: 10, right: 20, bottom: 10 });
        expect(offset).toEqual({});
        expect(direction).toEqual(Down);
      });

      it('inverts direction if is Down and overflows on the bottom', () => {
        const { offset, direction } = compute(Down, { top: 490, left: 10, right: 20, bottom: 510 });
        expect(offset).toEqual({});
        expect(direction).toEqual(Up);
      });

      it('inverts direction if is Right and overflows on the right', () => {
        const { offset, direction } = compute(Right, {
          top: 10,
          left: 490,
          right: 510,
          bottom: 20,
        });
        expect(offset).toEqual({});
        expect(direction).toEqual(Left);
      });

      it('inverts direction if is Left and overflows on the left', () => {
        const { offset, direction } = compute(Left, { top: 10, left: -10, right: 10, bottom: 20 });
        expect(offset).toEqual({});
        expect(direction).toEqual(Right);
      });

      [Up, Down, Left, Right].forEach(dir => {
        if (dir === Up || dir === Down) {
          it('moves left if its overflowing on the right', () => {
            const { offset, direction } = compute(dir, {
              top: 10,
              left: 490,
              right: 510,
              bottom: 20,
            });
            expect(offset).toEqual({ x: -20 });
            expect(direction).toEqual(dir);
          });

          it('moves right if overflows on the left', () => {
            const { offset, direction } = compute(dir, {
              top: 10,
              left: -10,
              right: 10,
              bottom: 20,
            });
            expect(offset).toEqual({ x: 20 });
            expect(direction).toEqual(dir);
          });
        }

        if (dir === Left || dir === Right) {
          it('moves up if its overflowing on the bottom', () => {
            const { offset, direction } = compute(dir, {
              top: 490,
              left: 10,
              right: 20,
              bottom: 510,
            });
            expect(offset).toEqual({ y: -20 });
            expect(direction).toEqual(dir);
          });

          it('moves down if overflows on the top', () => {
            const { offset, direction } = compute(dir, {
              top: -10,
              left: 10,
              right: 20,
              bottom: 10,
            });
            expect(offset).toEqual({ y: 20 });
            expect(direction).toEqual(dir);
          });
        }
      });
    });

    describe('when overflowing on 2 sides of the window', () => {
      describe('when direction is up', () => {
        it('computes correctly when it overflows up and right', () => {
          const { offset, direction } = compute(Up, { top: -10, left: 10, right: 510, bottom: 10 });
          expect(offset).toEqual({ x: -20 });
          expect(direction).toEqual(Down);
        });

        it('computes correctly when it overflows up and left', () => {
          const { offset, direction } = compute(Up, { top: -10, left: -10, right: 10, bottom: 10 });
          expect(offset).toEqual({ x: 20 });
          expect(direction).toEqual(Down);
        });
      });

      describe('when direction is right', () => {
        it('computes correctly when it overflows right and up', () => {
          const { offset, direction } = compute(Right, {
            top: -10,
            left: 490,
            right: 510,
            bottom: 10,
          });
          expect(offset).toEqual({ y: 20 });
          expect(direction).toEqual(Left);
        });

        it('computes correctly when it overflows right and down', () => {
          const { offset, direction } = compute(Right, {
            top: 490,
            left: 490,
            right: 510,
            bottom: 510,
          });
          expect(offset).toEqual({ y: -20 });
          expect(direction).toEqual(Left);
        });
      });

      describe('when direction is left', () => {
        it('computes correctly when it overflows left and up', () => {
          const { offset, direction } = compute(Left, {
            top: -10,
            left: -10,
            right: 10,
            bottom: 10,
          });
          expect(offset).toEqual({ y: 20 });
          expect(direction).toEqual(Right);
        });

        it('computes correctly when it overflows left and down', () => {
          const { offset, direction } = compute(Left, {
            top: 490,
            left: -10,
            right: 10,
            bottom: 510,
          });
          expect(offset).toEqual({ y: -20 });
          expect(direction).toEqual(Right);
        });
      });

      describe('when direction is down', () => {
        it('computes correctly when it overflows down and left', () => {
          const { offset, direction } = compute(Down, {
            top: 490,
            left: -10,
            right: 10,
            bottom: 510,
          });
          expect(offset).toEqual({ x: 20 });
          expect(direction).toEqual(Up);
        });

        it('computes correctly when it overflows down and right', () => {
          const { offset, direction } = compute(Down, {
            top: 490,
            left: 490,
            right: 510,
            bottom: 510,
          });
          expect(offset).toEqual({ x: -20 });
          expect(direction).toEqual(Up);
        });
      });
    });
  });

  describe('computePopoverStyles', () => {
    // TODO
  });
});
