package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface DeviceChangeRequestRepository {

    Optional<DeviceChangeRequest> findById(String id);

    DeviceChangeRequestPage list(DeviceChangeRequestQuery query);

    boolean hasPendingByDeviceId(String deviceId);

    boolean hasPendingByTargetDeviceCode(String deviceCode);

    Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now);

    void create(DeviceChangeRequestCreate request);

    boolean applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            DeviceArchiveUpdate archiveUpdate);

    boolean markApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil);

    boolean applyRejectedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt);
}
