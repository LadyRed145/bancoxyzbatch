package cl.duoc.bancoxyz.configserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

/**
 * Servidor centralizado de configuración de BancoXYZ.
 *
 * Los distintos microservicios podrán obtener desde aquí
 * sus propiedades externas, evitando duplicar configuración
 * entre aplicaciones.
 */
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}