package cl.duoc.bancoxyz.cuentas.config;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
@Configuration
public class SecurityConfig {
 @Bean
 SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
  http.csrf(csrf -> csrf.disable())
      .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
      .authorizeHttpRequests(auth -> auth
          .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
          .requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
          .requestMatchers(HttpMethod.GET, "/api/cuentas", "/api/cuentas/*").authenticated()
          .requestMatchers(HttpMethod.GET, "/api/cuentas/gestion", "/api/cuentas/gestion/*").authenticated()
          .requestMatchers(HttpMethod.POST, "/api/cuentas/gestion", "/api/cuentas/gestion/*/cierre").authenticated()
          .requestMatchers(HttpMethod.PUT, "/api/cuentas/gestion/*").authenticated()
          .anyRequest().denyAll())
      .oauth2ResourceServer(oauth -> oauth.jwt(jwt -> {}));
  return http.build();
 }
}
