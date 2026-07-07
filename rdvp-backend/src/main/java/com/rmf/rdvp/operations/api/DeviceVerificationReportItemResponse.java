package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.DeviceVerificationReportItem;

public record DeviceVerificationReportItemResponse(
        String itemCode,
        String itemName,
        String result,
        int displayOrder) {

    public static DeviceVerificationReportItemResponse from(DeviceVerificationReportItem item) {
        return new DeviceVerificationReportItemResponse(
                item.itemCode(),
                item.itemName(),
                item.result().name(),
                item.displayOrder());
    }
}
