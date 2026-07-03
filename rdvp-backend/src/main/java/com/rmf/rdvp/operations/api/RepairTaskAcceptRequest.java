package com.rmf.rdvp.operations.api;

import java.math.BigDecimal;

public record RepairTaskAcceptRequest(
        BigDecimal longitude,
        BigDecimal latitude) {
}
