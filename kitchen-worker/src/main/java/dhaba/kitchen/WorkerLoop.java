package dhaba.kitchen;

import jakarta.annotation.PreDestroy;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/** Takes jobs from the Redis queue. A job that fails is put back, so no order is lost. */
@Component
public class WorkerLoop {

    static final String QUEUE = "orders:queue";
    private static final Logger LOG = LoggerFactory.getLogger(WorkerLoop.class);

    private final StringRedisTemplate redis;
    private final OrderProcessor processor;
    private volatile boolean running = true;
    private Thread thread;

    public WorkerLoop(StringRedisTemplate redis, OrderProcessor processor) {
        this.redis = redis;
        this.processor = processor;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void start() {
        LOG.info("kitchen-worker version {} started", System.getenv().getOrDefault("GIT_COMMIT", "dev"));
        thread = new Thread(this::run, "worker-loop");
        thread.start();
    }

    @PreDestroy
    public void stop() {
        running = false;
        if (thread != null) {
            thread.interrupt();
        }
    }

    private void run() {
        while (running) {
            String job = null;
            try {
                job = redis.opsForList().rightPop(QUEUE, Duration.ofSeconds(5));
                if (job != null) {
                    processor.process(job);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                requeue(job);
                return;
            } catch (RuntimeException e) {
                LOG.warn("Job {} failed, retrying later: {}", job, e.getMessage());
                requeue(job);
                pause(2000);
            }
        }
    }

    private void requeue(String job) {
        if (job == null) {
            return;
        }
        try {
            redis.opsForList().rightPush(QUEUE, job);
        } catch (RuntimeException e) {
            LOG.error("Could not put job {} back on the queue: {}", job, e.getMessage());
        }
    }

    private void pause(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            running = false;
        }
    }
}
