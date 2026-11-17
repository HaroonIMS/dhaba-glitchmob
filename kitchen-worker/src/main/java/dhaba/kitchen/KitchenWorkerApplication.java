package dhaba.kitchen;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Entry point of the kitchen worker (no web port). */
@SpringBootApplication
@EnableScheduling
public class KitchenWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(KitchenWorkerApplication.class, args);
    }
}
