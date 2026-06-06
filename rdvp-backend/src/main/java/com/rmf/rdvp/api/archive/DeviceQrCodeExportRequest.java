package com.rmf.rdvp.api.archive;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DeviceQrCodeExportRequest(
        @NotBlank @Size(max = 128) String password) {
}
