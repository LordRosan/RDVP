package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface ArchiveRequestRepository {

    Optional<ArchiveRequest> findById(String id);

    ArchiveRequestPage list(ArchiveRequestQuery query);

    long countAll();

    long countPendingReview();

    long countApprovedByType(ArchiveRequestType type);

    long countReviewed();

    boolean hasPendingByDeviceId(String deviceId);

    boolean hasPendingByTargetDeviceCode(String deviceCode);

    Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now);

    Optional<OffsetDateTime> findActiveFreezeUntilByTargetDeviceCode(String deviceCode, OffsetDateTime now);

    void create(ArchiveRequestCreate request);

    boolean applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            ArchiveUpdate archiveUpdate);

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
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil);
}
