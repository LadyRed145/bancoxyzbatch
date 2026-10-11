package cl.duoc.bancoxyz.pagos;

import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/** OAuth2 JWT: operaciones permitidas solamente a los canales bancarios. */
@Configuration
public class SecurityConfig {
    @Bean
    SecurityFilterChain chain(HttpSecurity http) throws Exception {
        return http.csrf(c -> c.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                        .requestMatchers("/api/pagos/**").hasAnyAuthority(
                                "SCOPE_bancoxyz.web", "SCOPE_bancoxyz.mobile", "SCOPE_bancoxyz.atm")
                        .anyRequest().denyAll())
                .oauth2ResourceServer(o -> o.jwt(j -> {}))
                .build();
    }
}
