package cl.duoc.bancoxyz.bffweb.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;

@Component
public class ApiTokenAuthenticationFilter extends OncePerRequestFilter {

    private final List<TokenCredential> credentials;

    public ApiTokenAuthenticationFilter(
            @Value("${security.tokens.web}") String webToken,
            @Value("${security.tokens.mobile}") String mobileToken,
            @Value("${security.tokens.atm}") String atmToken) {

        // Conozco los tres tokens académicos para separar autenticación de autorización.
        // Así un token válido de otro canal queda autenticado, pero Spring Security lo rechaza con 403.
        this.credentials = List.of(
                new TokenCredential("bff-web-client", "WEB", tokenBytes(webToken)),
                new TokenCredential("bff-mobile-client", "MOBILE", tokenBytes(mobileToken)),
                new TokenCredential("bff-atm-client", "ATM", tokenBytes(atmToken))
        );
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);

        // Solo intento autenticar cuando recibo el esquema Bearer y aún no existe autenticación previa.
        if (SecurityContextHolder.getContext().getAuthentication() == null
                && authorization != null
                && authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {

            String suppliedToken = authorization.substring(7).trim();
            TokenCredential credential = buscarCredencial(suppliedToken);

            if (credential != null) {
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(
                                credential.principal(),
                                null,
                                List.of(new SimpleGrantedAuthority("ROLE_" + credential.role()))
                        );

                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        }

        filterChain.doFilter(request, response);
    }

    private TokenCredential buscarCredencial(String suppliedToken) {
        byte[] supplied = tokenBytes(suppliedToken);

        // MessageDigest.isEqual evita una comparación directa de String para los secretos.
        for (TokenCredential credential : credentials) {
            if (MessageDigest.isEqual(credential.token(), supplied)) {
                return credential;
            }
        }

        return null;
    }

    private static byte[] tokenBytes(String token) {
        return token.getBytes(StandardCharsets.UTF_8);
    }

    private record TokenCredential(
            String principal,
            String role,
            byte[] token
    ) {
    }
}
