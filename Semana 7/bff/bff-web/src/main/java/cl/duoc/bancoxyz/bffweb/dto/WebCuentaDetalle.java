package cl.duoc.bancoxyz.bffweb.dto;

import tools.jackson.databind.JsonNode;

public record WebCuentaDetalle(
        JsonNode cuenta,
        JsonNode estadosCuenta
) {
}