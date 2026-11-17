package dhaba.kitchen;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Writes worker:heartbeat to Redis every 10 seconds (it expires after 30) and touches a file
 * that the Docker HEALTHCHECK looks at. The file is only touched after Redis accepted the write.
 */
@Component
public class Heartbeat {

    static final String KEY = "worker:heartbeat";
    private static final Logger LOG = LoggerFactory.getLogger(Heartbeat.class);

    private final StringRedisTemplate redis;
    private final Path file;

    public Heartbeat(StringRedisTemplate redis, @Value("${worker.heartbeat-file:/tmp/heartbeat}") String file) {
        this.redis = redis;
        this.file = Path.of(file);
    }

    @Scheduled(fixedRate = 10000)
    public void beat() {
        try {
            String now = String.valueOf(Instant.now().getEpochSecond());
            redis.opsForValue().set(KEY, now, Duration.ofSeconds(30));
            Files.writeString(file, now);
        } catch (RuntimeException | IOException e) {
            LOG.warn("Heartbeat failed: {}", e.getMessage());
        }
    }
}
