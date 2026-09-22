package cl.duoc.bancoxyz.bffmobile.config;

import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.security.autoconfigure.actuate.web.servlet.EndpointRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.util.List;

@Configuration
public class SecurityConfig {

    @Bean
    public UserDetailsService userDetailsService() {
        // La autenticación del BFF se resuelve exclusivamente mediante Bearer tokens.
        return new InMemoryUserDetailsManager(List.of());
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            ApiTokenAuthenticationFilter apiTokenAuthenticationFilter) throws Exception {

        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth

                        // Mantengo /error accesible para preservar códigos HTTP reales.
                        .requestMatchers("/error").permitAll()

                        // Health e info pueden utilizarse para monitoreo y health checks.
                        .requestMatchers(
                                EndpointRequest.to("health", "info")
                        ).permitAll()

                        // El resto de Actuator exige el rol propio de este BFF.
                        .requestMatchers(
                                EndpointRequest.toAnyEndpoint()
                        ).hasRole("MOBILE")

                        // API funcional del canal.
                        .requestMatchers("/api/mobile/**").hasRole("MOBILE")

                        .anyRequest().denyAll()
                )
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint((request, response, exception) ->
                                response.sendError(HttpServletResponse.SC_UNAUTHORIZED))
                        .accessDeniedHandler((request, response, exception) ->
                                response.sendError(HttpServletResponse.SC_FORBIDDEN))
                )
                .addFilterBefore(
                        apiTokenAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class
                );

        return http.build();
    }
}
