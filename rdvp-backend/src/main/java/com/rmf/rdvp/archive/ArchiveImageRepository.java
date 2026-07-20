package com.rmf.rdvp.archive;

import java.util.List;
import java.util.Optional;

public interface ArchiveImageRepository {

    List<ArchiveImage> findByDeviceId(String deviceId);

    Optional<ArchiveImage> findById(String imageId);

    void replaceForDevice(String deviceId, List<ArchiveImage> images, String operatorId);
}
