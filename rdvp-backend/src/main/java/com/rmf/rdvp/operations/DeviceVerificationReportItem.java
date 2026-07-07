package com.rmf.rdvp.operations;

public record DeviceVerificationReportItem(
        String itemCode,
        String itemName,
        VerificationItemResult result,
        int displayOrder) {
}
