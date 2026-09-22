package cl.duoc.bancoxyz.discoveryserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

/**
 * Servidor de descubrimiento de servicios de BancoXYZ.
 *
 * Eureka mantiene un registro centralizado de los
 * microservicios disponibles dentro de la arquitectura.
 *
 * Durante la Semana 6 permitirá registrar y descubrir
 * los BFF Web, Mobile y ATM.
 */
@SpringBootApplication
@EnableEurekaServer
public class DiscoveryServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(DiscoveryServerApplication.class, args);
    }
}