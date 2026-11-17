package dhaba.kitchen;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Moves one order from new to cooking to ready. */
@Component
public class OrderProcessor {

    private static final Logger LOG = LoggerFactory.getLogger(OrderProcessor.class);

    private final OrderRepository orders;
    private final long cookMillis;

    public OrderProcessor(OrderRepository orders, @Value("${worker.cook-millis:5000}") long cookMillis) {
        this.orders = orders;
        this.cookMillis = cookMillis;
    }

    /**
     * Processes one job from the queue.
     *
     * @param job the order id as text
     * @throws InterruptedException if the worker is stopped while cooking
     */
    public void process(String job) throws InterruptedException {
        long id;
        try {
            id = Long.parseLong(job.trim());
        } catch (NumberFormatException e) {
            LOG.warn("Ignoring job with a bad order id: '{}'", job);
            return;
        }
        orders.updateStatus(id, "cooking");
        Thread.sleep(cookMillis);
        orders.updateStatus(id, "ready");
        LOG.info("Order {} is ready", id);
    }
}
