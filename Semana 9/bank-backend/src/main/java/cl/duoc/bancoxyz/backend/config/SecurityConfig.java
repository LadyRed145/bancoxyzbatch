package cl.duoc.bancoxyz.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    private static final String WEB = "SCOPE_bancoxyz.web";
    private static final String MOBILE = "SCOPE_bancoxyz.mobile";
    private static final String ATM = "SCOPE_bancoxyz.atm";

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http)
            throws Exception {

        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                    "/error",
                    "/actuator/health",
                    "/actuator/health/**",
                    "/actuator/info"
                ).permitAll()
                .requestMatchers(
                    HttpMethod.POST,
                    "/api/cuentas/*/retiro"
                ).hasAuthority(ATM)
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/cuentas"
                ).hasAnyAuthority(WEB, MOBILE)
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/cuentas/*"
                ).hasAnyAuthority(WEB, MOBILE, ATM)
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/estados-cuenta/**"
                ).hasAuthority(WEB)
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/resumenes/**",
                    "/api/transacciones/**"
                ).hasAuthority(WEB)
                .anyRequest().denyAll()
            )
            .oauth2ResourceServer(oauth2 ->
                oauth2.jwt(Customizer.withDefaults()));

        return http.build();
    }
}
