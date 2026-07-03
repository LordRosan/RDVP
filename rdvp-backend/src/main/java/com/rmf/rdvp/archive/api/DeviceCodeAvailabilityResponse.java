package com.rmf.rdvp.archive.api;

public record DeviceCodeAvailabilityResponse(
        boolean available,
        String reason) {
}
