package com.rmf.rdvp.api.archive;

public record DeviceCodeAvailabilityResponse(
        boolean available,
        String reason) {
}
