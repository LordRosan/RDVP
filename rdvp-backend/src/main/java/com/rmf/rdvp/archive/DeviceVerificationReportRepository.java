package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceVerificationReportRepository {

    void create(DeviceVerificationReportCreate create);

    Optional<DeviceVerificationReport> findById(String id);

    long countAll();
}
