package cl.duoc.bancoxyz.clientes;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
@Configuration public class SecurityConfig {
@Bean SecurityFilterChain chain(HttpSecurity http) throws Exception {
 return http.csrf(c->c.disable()).authorizeHttpRequests(a->a.requestMatchers("/actuator/health","/actuator/info").permitAll().anyRequest().authenticated()).oauth2ResourceServer(o->o.jwt(j->{})).build();
}
}
