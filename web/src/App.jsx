import { useEffect, useState } from 'react';
import { cartToItems, cartTotal, formatPrice, groupByStatus } from './lib.js';

const VERSION = import.meta.env.VITE_GIT_COMMIT || 'dev';

const TABS = [
  { key: 'order', label: 'Order', icon: '🍽️' },
  { key: 'kitchen', label: 'Kitchen', icon: '👨‍🍳' },
  { key: 'stats', label: 'Stats', icon: '📊' },
];

const COLUMNS = [
  { key: 'new', title: 'New orders', subtitle: 'Waiting to be prepared' },
  { key: 'cooking', title: 'Cooking', subtitle: 'Being prepared now' },
  { key: 'ready', title: 'Ready', subtitle: 'Ready to serve' },
];

function dishEmoji(name = '') {
  const dish = name.toLowerCase();

  if (dish.includes('karahi')) return '🍲';
  if (dish.includes('biryani')) return '🍛';
  if (dish.includes('daal') || dish.includes('dal')) return '🥘';
  if (dish.includes('naan') || dish.includes('roti')) return '🫓';
  if (dish.includes('lassi') || dish.includes('drink')) return '🥤';

  return '🍽️';
}

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
  const total = cartTotal(cart, dishes);
  const itemCount = items.reduce((sum, item) => sum + item.qty, 0);

  const change = (name, delta) => {
    setCart((current) => ({
      ...current,
      [name]: Math.max(0, (current[name] ?? 0) + delta),
    }));
  };

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

      if (!res.ok) {
        throw new Error(body.error ?? 'The order could not be placed');
      }

      setCart({});
      setMessage({
        ok: true,
        text: `Order #${body.id} has been sent to the kitchen!`,
      });
    } catch (err) {
      setMessage({ ok: false, text: err.message });
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <section className="hero">
        <div className="hero-content">
          <span className="eyebrow">FRESHLY PREPARED · FULL OF FLAVOUR</span>
          <h2>Good food.<br /><span>Good mood.</span></h2>
          <p>Discover your favourites and let us prepare something delicious for you.</p>
          <a className="hero-link" href="#menu">Explore the menu <span>↓</span></a>
        </div>
        <div className="hero-art" aria-hidden="true">
          <div className="hero-circle">
            <span>🍛</span>
          </div>
          <span className="hero-spark spark-one">✦</span>
          <span className="hero-spark spark-two">✳</span>
          <span className="hero-note">Made with<br />love ❤️</span>
        </div>
      </section>

      <div className="section-heading" id="menu">
        <div>
          <span className="eyebrow">MADE FRESH FOR YOU</span>
          <h2>Explore our menu</h2>
          <p className="muted">Choose your favourite dishes and build your order.</p>
        </div>
        <span className="menu-count">{dishes.length} items</span>
      </div>

      {failed && (
        <p className="notice bad">The menu could not be loaded. Retrying automatically.</p>
      )}

      {!menu && !failed && <p className="muted loading-text">Loading our menu...</p>}

      {menu && dishes.length === 0 && (
        <p className="muted loading-text">No menu items are available right now.</p>
      )}

      <div className="order-layout">
        <section className="menu-grid" aria-label="Restaurant menu">
          {dishes.map((dish) => {
            const quantity = cart[dish.name] ?? 0;

            return (
              <article className={`menu-card ${quantity > 0 ? 'selected' : ''}`} key={dish.id}>
                <div className="dish-art">
                  <span>{dishEmoji(dish.name)}</span>
                  {quantity > 0 && <span className="selected-tag">In your order</span>}
                </div>

                <div className="dish-info">
                  <h3>{dish.name}</h3>
                  <p className="dish-description">Freshly prepared and full of flavour.</p>

                  <div className="dish-bottom">
                    <strong className="price">{formatPrice(dish.price)}</strong>

                    <div className="stepper">
                      <button
                        type="button"
                        aria-label={`Remove one ${dish.name}`}
                        disabled={quantity === 0}
                        onClick={() => change(dish.name, -1)}
                      >
                        −
                      </button>
                      <output aria-label={`${quantity} ${dish.name} selected`}>{quantity}</output>
                      <button
                        type="button"
                        aria-label={`Add one ${dish.name}`}
                        onClick={() => change(dish.name, 1)}
                      >
                        +
                      </button>
                    </div>
                  </div>
                </div>
              </article>
            );
          })}
        </section>

        <aside className="ticket">
          <div className="ticket-heading">
            <div>
              <span className="eyebrow">YOUR SELECTION</span>
              <h2>Your order</h2>
            </div>
            <span className="cart-icon">🛍️</span>
          </div>

          <div className="cart-count">
            {itemCount} {itemCount === 1 ? 'item' : 'items'} selected
          </div>

          {items.length === 0 ? (
            <div className="empty-cart">
              <span>🥡</span>
              <strong>Your cart is waiting</strong>
              <p>Add something delicious from the menu to get started.</p>
            </div>
          ) : (
            <ul className="cart-items">
              {items.map((item) => (
                <li key={item.name}>
                  <div>
                    <strong>{item.name}</strong>
                    <span>{item.qty} × selected</span>
                  </div>
                  <div className="cart-controls">
                    <button
                      type="button"
                      aria-label={`Remove one ${item.name}`}
                      onClick={() => change(item.name, -1)}
                    >
                      −
                    </button>
                    <button
                      type="button"
                      aria-label={`Add one ${item.name}`}
                      onClick={() => change(item.name, 1)}
                    >
                      +
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}

          <div className="ticket-total">
            <span>Total amount</span>
            <strong>{formatPrice(total)}</strong>
          </div>

          <button
            type="button"
            className="primary"
            disabled={busy || items.length === 0}
            onClick={placeOrder}
          >
            {busy ? 'Placing order...' : 'Place your order'}
            {!busy && <span>→</span>}
          </button>

          <p className="secure-note">Fresh food, prepared with care.</p>

          {message && (
            <p className={`notice ${message.ok ? 'good' : 'bad'}`} role="status">
              {message.text}
            </p>
          )}
        </aside>
      </div>
    </>
  );
}

function KitchenPage() {
  const { data, failed } = usePolling('/api/orders', 2000);
  const groups = groupByStatus(data ?? []);

  return (
    <section className="dashboard-page">
      <div className="section-heading">
        <div>
          <span className="eyebrow">LIVE ORDER MANAGEMENT</span>
          <h2>Kitchen dashboard</h2>
          <p className="muted">Keep track of orders as they move through the kitchen.</p>
        </div>
        <span className="live-indicator"><span /> Live updates</span>
      </div>

      {failed && <p className="notice bad">Orders could not be loaded. Retrying.</p>}

      <div className="rail">
        {COLUMNS.map((column) => (
          <div key={column.key} className={`lane ${column.key}`}>
            <div className="lane-heading">
              <div>
                <h3>{column.title}</h3>
                <p>{column.subtitle}</p>
              </div>
              <span className="count">{groups[column.key].length}</span>
            </div>

            {groups[column.key].length === 0 && (
              <p className="lane-empty">No orders here yet.</p>
            )}

            {groups[column.key].map((order) => (
              <article key={order.id} className="slip">
                <div className="slip-heading">
                  <strong>Order #{order.id}</strong>
                  <span>{order.items.length} dishes</span>
                </div>
                <ul>
                  {order.items.map((item) => (
                    <li key={item.name}>
                      <span>{item.name}</span>
                      <strong>× {item.qty}</strong>
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
    <section className="dashboard-page">
      <div className="section-heading">
        <div>
          <span className="eyebrow">RESTAURANT OVERVIEW</span>
          <h2>Sales & activity</h2>
          <p className="muted">A quick look at recent restaurant activity.</p>
        </div>
        <span className="live-indicator"><span /> Live updates</span>
      </div>

      {failed && <p className="notice bad">Stats could not be loaded. Retrying.</p>}

      {data && (
        <>
          <div className="numbers">
            <article className="stat-card">
              <span className="stat-icon">⚡</span>
              <p>Orders this minute</p>
              <strong>{data.orders_this_minute}</strong>
              <span className="stat-caption">Current activity</span>
            </article>

            <article className="stat-card">
              <span className="stat-icon">🧾</span>
              <p>Orders in last 5 minutes</p>
              <strong>{data.orders_last_5_minutes}</strong>
              <span className="stat-caption">Recent order volume</span>
            </article>
          </div>

          <div className="top-dishes-panel">
            <div className="panel-heading">
              <div>
                <span className="eyebrow">CUSTOMER FAVOURITES</span>
                <h3>Top dishes</h3>
              </div>
              <span>🍽️</span>
            </div>

            {data.top_dishes.length === 0 ? (
              <p className="muted">No orders yet. Your bestsellers will appear here.</p>
            ) : (
              <ol className="top">
                {data.top_dishes.map((dish, index) => (
                  <li key={dish.name}>
                    <span className="rank">{index + 1}</span>
                    <span className="top-dish-name">{dish.name}</span>
                    <strong>{dish.count} sold</strong>
                  </li>
                ))}
              </ol>
            )}
          </div>
        </>
      )}

      {!data && !failed && <p className="muted loading-text">Loading restaurant statistics...</p>}
    </section>
  );
}

export default function App() {
  const [tab, setTab] = useState('order');

  return (
    <div className="app-shell">
      <header className="site-header">
        <a className="brand" href="#" onClick={() => setTab('order')}>
          <span className="brand-mark">D</span>
          <span>
            <strong>Dhaba</strong>
            <small>THE FOOD CORNER</small>
          </span>
        </a>

        <nav aria-label="Pages">
          {TABS.map((item) => (
            <button
              key={item.key}
              type="button"
              aria-current={tab === item.key ? 'page' : undefined}
              onClick={() => setTab(item.key)}
            >
              <span>{item.icon}</span>
              {item.label}
            </button>
          ))}
        </nav>

        <span className="header-tag">GOOD FOOD, GOOD TIMES</span>
      </header>

      <main className="page">
        {tab === 'order' && <OrderPage />}
        {tab === 'kitchen' && <KitchenPage />}
        {tab === 'stats' && <StatsPage />}
      </main>

      <footer className="site-footer">
        <div>
          <strong>Dhaba</strong>
          <span>Serving happiness, one dish at a time.</span>
        </div>
        <span>Version {VERSION}</span>
      </footer>
    </div>
  );
}
