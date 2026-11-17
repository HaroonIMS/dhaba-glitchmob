export function cartToItems(cart) {
  return Object.entries(cart)
    .filter(([, qty]) => qty > 0)
    .map(([name, qty]) => ({ name, qty }));
}

export function cartTotal(cart, menu) {
  const prices = Object.fromEntries(menu.map((dish) => [dish.name, dish.price]));
  return Object.entries(cart).reduce((sum, [name, qty]) => sum + (prices[name] ?? 0) * qty, 0);
}

export function groupByStatus(orders) {
  const groups = { new: [], cooking: [], ready: [] };
  for (const order of orders) {
    (groups[order.status] ?? groups.new).push(order);
  }
  return groups;
}

export function formatPrice(amount) {
  return `$${amount.toFixed(2)}`;
}
