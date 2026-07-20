package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.List;
import java.util.stream.Collectors;

import com.rmf.rdvp.archive.ArchiveRequest;
import com.rmf.rdvp.archive.ArchiveImage;

public record ArchiveReviewResponse(
        String id,
        String type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String operatorId,
        String operatorName,
        String reason,
        String status,
        String initiatedAt,
        String createdAt,
        String submittedAt,
        boolean imagesChanged,
        List<ArchiveImageSummaryResponse> images,
        Map<String, ArchiveFieldChangeResponse> changes) {

    public static ArchiveReviewResponse from(ArchiveRequest request) {
        return from(request, List.of(), false);
    }

    public static ArchiveReviewResponse from(
            ArchiveRequest request,
            List<ArchiveImage> images,
            boolean imagesChanged) {
        return new ArchiveReviewResponse(
                request.id(),
                request.type().name(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                request.reason(),
                request.status().name(),
                toIsoString(request.initiatedAt()),
                toIsoString(request.createdAt()),
                toIsoString(request.createdAt()),
                imagesChanged,
                images.stream().map(ArchiveImageSummaryResponse::from).toList(),
                request.changes()
                        .entrySet()
                        .stream()
                        .collect(Collectors.toMap(
                                Map.Entry::getKey,
                                entry -> new ArchiveFieldChangeResponse(
                                        entry.getValue().oldValue(),
                                        entry.getValue().newValue()))));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }

    public record ArchiveFieldChangeResponse(
            String oldValue,
            String newValue) {
    }
}
