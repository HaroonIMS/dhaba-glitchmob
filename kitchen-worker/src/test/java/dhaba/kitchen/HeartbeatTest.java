package dhaba.kitchen;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class HeartbeatTest {

    @TempDir
    Path dir;

    @Test
    @SuppressWarnings("unchecked")
    void writesRedisKeyWithExpiryAndTouchesFile() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        Path file = dir.resolve("heartbeat");

        new Heartbeat(redis, file.toString()).beat();

        verify(ops).set(eq("worker:heartbeat"), anyString(), eq(Duration.ofSeconds(30)));
        assertTrue(Files.exists(file));
    }
}
