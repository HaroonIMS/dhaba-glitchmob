import { useEffect, useState } from 'react';
import { cartToItems, cartTotal, formatPrice, groupByStatus } from './lib.js';

const VERSION = import.meta.env.VITE_GIT_COMMIT || 'dev';
const TABS = [
  { key: 'order', label: 'Order' },
  { key: 'kitchen', label: 'Kitchen' },
  { key: 'stats', label: 'Stats' },
];
const COLUMNS = [
  { key: 'new', title: 'New' },
  { key: 'cooking', title: 'Cooking' },
  { key: 'ready', title: 'Ready' },
];

function usePolling(url, intervalMs) {
  const [data, setData] = useState(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const res = await fetch(url);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (active) {
          setData(json);
          setFailed(false);
        }
      } catch {
        if (active) setFailed(true);
      }
    };
    load();
    const timer = setInterval(load, intervalMs);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, [url, intervalMs]);

  return { data, failed };
}

function OrderPage() {
  const { data: menu, failed } = usePolling('/api/menu', 30000);
  const [cart, setCart] = useState({});
  const [message, setMessage] = useState(null);
  const [busy, setBusy] = useState(false);

  const dishes = menu ?? [];
  const items = cartToItems(cart);

  const change = (name, delta) =>
    setCart((current) => ({ ...current, [name]: Math.max(0, (current[name] ?? 0) + delta) }));

  const placeOrder = async () => {
    setBusy(true);
    setMessage(null);
    try {
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.error ?? 'The order could not be placed');
      setCart({});
      setMessage({ ok: true, text: `Order #${body.id} is with the kitchen` });
    } catch (err) {
      setMessage({ ok: false, text: err.message });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="order-layout">
      <section>
        <h2>Menu</h2>
        {failed && <p className="notice bad">The menu could not be loaded. Retrying.</p>}
        <ul className="menu">
          {dishes.map((dish) => (
            <li key={dish.id}>
              <span className="dish">{dish.name}</span>
              <span className="price">{formatPrice(dish.price)}</span>
              <span className="stepper">
                <button type="button" aria-label={`Remove one ${dish.name}`} onClick={() => change(dish.name, -1)}>
                  -
                </button>
                <output>{cart[dish.name] ?? 0}</output>
                <button type="button" aria-label={`Add one ${dish.name}`} onClick={() => change(dish.name, 1)}>
                  +
                </button>
              </span>
            </li>
          ))}
        </ul>
      </section>
      <aside className="ticket">
        <h2>Your order</h2>
        {items.length === 0 ? (
          <p className="muted">Add a dish from the menu to start.</p>
        ) : (
          <ul>
            {items.map((item) => (
              <li key={item.name}>
                {item.qty} x {item.name}
              </li>
            ))}
          </ul>
        )}
        <p className="total">Total {formatPrice(cartTotal(cart, dishes))}</p>
        <button type="button" className="primary" disabled={busy || items.length === 0} onClick={placeOrder}>
          Place order
        </button>
        {message && <p className={`notice ${message.ok ? 'good' : 'bad'}`}>{message.text}</p>}
      </aside>
    </div>
  );
}

function KitchenPage() {
  const { data, failed } = usePolling('/api/orders', 2000);
  const groups = groupByStatus(data ?? []);

  return (
    <section>
      <h2>Kitchen</h2>
      {failed && <p className="notice bad">Orders could not be loaded. Retrying.</p>}
      <div className="rail">
        {COLUMNS.map((column) => (
          <div key={column.key} className={`lane ${column.key}`}>
            <h3>
              {column.title} <span className="count">{groups[column.key].length}</span>
            </h3>
            {groups[column.key].map((order) => (
              <article key={order.id} className="slip">
                <strong>Order #{order.id}</strong>
                <ul>
                  {order.items.map((item) => (
                    <li key={item.name}>
                      {item.qty} x {item.name}
                    </li>
                  ))}
                </ul>
              </article>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}

function StatsPage() {
  const { data, failed } = usePolling('/api/stats', 3000);

  return (
    <section>
      <h2>Stats</h2>
      {failed && <p className="notice bad">Stats could not be loaded. Retrying.</p>}
      {data && (
        <>
          <div className="numbers">
            <p>
              <strong>{data.orders_this_minute}</strong> orders this minute
            </p>
            <p>
              <strong>{data.orders_last_5_minutes}</strong> orders in the last 5 minutes
            </p>
          </div>
          <h3>Top dishes</h3>
          {data.top_dishes.length === 0 ? (
            <p className="muted">No orders yet.</p>
          ) : (
            <ol className="top">
              {data.top_dishes.map((dish) => (
                <li key={dish.name}>
                  <span>{dish.name}</span>
                  <span>{dish.count} sold</span>
                </li>
              ))}
            </ol>
          )}
        </>
      )}
    </section>
  );
}

export default function App() {
  const [tab, setTab] = useState('order');

  return (
    <div className="page">
      <header>
        <h1>Dhaba Orders</h1>
        <nav aria-label="Pages">
          {TABS.map((item) => (
            <button
              key={item.key}
              type="button"
              aria-current={tab === item.key ? 'page' : undefined}
              onClick={() => setTab(item.key)}
            >
              {item.label}
            </button>
          ))}
        </nav>
      </header>
      <main>
        {tab === 'order' && <OrderPage />}
        {tab === 'kitchen' && <KitchenPage />}
        {tab === 'stats' && <StatsPage />}
      </main>
      <footer>Version {VERSION}</footer>
    </div>
  );
}
