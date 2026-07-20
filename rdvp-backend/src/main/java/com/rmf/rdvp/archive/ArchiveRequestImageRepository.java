package com.rmf.rdvp.archive;

import java.util.List;
import java.util.Map;
import java.util.Optional;

public interface ArchiveRequestImageRepository {

    void saveChange(String requestId, List<ArchiveImage> images);

    Optional<List<ArchiveImage>> findChangeByRequestId(String requestId);

    Map<String, List<ArchiveImage>> findSummaryChangesByRequestIds(List<String> requestIds);

    Optional<ArchiveImage> findByRequestIdAndImageId(String requestId, String imageId);
}
