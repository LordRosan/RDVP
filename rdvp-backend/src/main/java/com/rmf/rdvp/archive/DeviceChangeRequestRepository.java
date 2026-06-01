package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface DeviceChangeRequestRepository {

    Optional<DeviceChangeRequest> findById(String id);

    DeviceChangeRequestPage list(DeviceChangeRequestQuery query);

    boolean hasPendingByDeviceId(String deviceId);

    Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now);

    void create(DeviceChangeRequestCreate request);

    void applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            DeviceArchiveUpdate archiveUpdate);

    void applyRejectedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt);
}
