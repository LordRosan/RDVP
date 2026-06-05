package com.rmf.rdvp.api.operations;

import java.math.BigDecimal;

public record RepairTaskAcceptRequest(
        BigDecimal longitude,
        BigDecimal latitude) {
}
