package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface DeviceArchiveRequestRepository {

    Optional<DeviceArchiveRequest> findById(String id);

    DeviceArchiveRequestPage list(DeviceArchiveRequestQuery query);

    long countPendingReview();

    long countApprovedByType(DeviceArchiveRequestType type);

    long countReviewed();

    boolean hasPendingByDeviceId(String deviceId);

    boolean hasPendingByTargetDeviceCode(String deviceCode);

    Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now);

    void create(DeviceArchiveRequestCreate request);

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
