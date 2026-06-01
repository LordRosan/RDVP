package com.rmf.rdvp.api.archive;

import java.util.Map;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record CreateDeviceChangeRequest(
        @NotBlank @Size(max = 64) String deviceId,
        @NotBlank @Size(max = 500) String reason,
        @NotEmpty Map<@Size(max = 64) String, @Valid DeviceChangeValueRequest> changes) {
}
