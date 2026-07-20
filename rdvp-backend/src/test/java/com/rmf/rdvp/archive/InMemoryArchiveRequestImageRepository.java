package com.rmf.rdvp.archive;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryArchiveRequestImageRepository implements ArchiveRequestImageRepository {

    private final Map<String, List<ArchiveImage>> changesByRequestId = new ConcurrentHashMap<>();

    @Override
    public void saveChange(String requestId, List<ArchiveImage> images) {
        changesByRequestId.put(requestId, List.copyOf(images));
    }

    @Override
    public Optional<List<ArchiveImage>> findChangeByRequestId(String requestId) {
        return Optional.ofNullable(changesByRequestId.get(requestId));
    }

    @Override
    public Map<String, List<ArchiveImage>> findSummaryChangesByRequestIds(List<String> requestIds) {
        Map<String, List<ArchiveImage>> result = new LinkedHashMap<>();
        requestIds.forEach(requestId -> {
            List<ArchiveImage> images = changesByRequestId.get(requestId);
            if (images != null) {
                result.put(requestId, images);
            }
        });
        return result;
    }

    @Override
    public Optional<ArchiveImage> findByRequestIdAndImageId(String requestId, String imageId) {
        return findChangeByRequestId(requestId)
                .flatMap(images -> images.stream().filter(image -> image.id().equals(imageId)).findFirst());
    }
}
