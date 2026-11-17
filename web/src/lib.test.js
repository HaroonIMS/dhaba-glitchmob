import { describe, expect, it } from 'vitest';
import { cartToItems, cartTotal, formatPrice, groupByStatus } from './lib.js';

const menu = [
  { id: 1, name: 'Biryani', price: 9 },
  { id: 2, name: 'Garlic Naan', price: 1.5 },
];

describe('cart helpers', () => {
  it('drops dishes with quantity 0', () => {
    expect(cartToItems({ Biryani: 2, 'Garlic Naan': 0 })).toEqual([{ name: 'Biryani', qty: 2 }]);
  });

  it('adds up the total', () => {
    expect(cartTotal({ Biryani: 2, 'Garlic Naan': 1 }, menu)).toBeCloseTo(19.5);
  });

  it('formats prices with two decimals', () => {
    expect(formatPrice(9)).toBe('$9.00');
  });
});

describe('groupByStatus', () => {
  it('puts each order in its column', () => {
    const groups = groupByStatus([
      { id: 1, status: 'new' },
      { id: 2, status: 'cooking' },
      { id: 3, status: 'ready' },
      { id: 4, status: 'ready' },
    ]);
    expect(groups.new).toHaveLength(1);
    expect(groups.cooking).toHaveLength(1);
    expect(groups.ready.map((o) => o.id)).toEqual([3, 4]);
  });
});
