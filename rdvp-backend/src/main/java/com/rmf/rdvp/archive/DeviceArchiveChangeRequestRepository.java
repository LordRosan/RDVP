package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface DeviceArchiveChangeRequestRepository {

    Optional<DeviceArchiveChangeRequest> findById(String id);

    DeviceArchiveChangeRequestPage list(DeviceArchiveChangeRequestQuery query);

    long countPendingReview();

    boolean hasPendingByDeviceId(String deviceId);

    boolean hasPendingByTargetDeviceCode(String deviceCode);

    Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now);

    void create(DeviceArchiveChangeRequestCreate request);

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
