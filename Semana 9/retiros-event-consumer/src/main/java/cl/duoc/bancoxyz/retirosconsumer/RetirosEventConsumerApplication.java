package cl.duoc.bancoxyz.retirosconsumer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "cl.duoc.bancoxyz")
public class RetirosEventConsumerApplication {

    public static void main(String[] args) {
        SpringApplication.run(RetirosEventConsumerApplication.class, args);
    }
}
