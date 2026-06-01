package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceArchiveRepository {

    Optional<DeviceArchive> findByCode(String deviceCode);

    Optional<DeviceArchive> findById(String id);
}
