package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceQrCodeRepository {

    Optional<DeviceQrCode> findByDeviceIdAndVersionAndNonce(String deviceId, int version, String nonce);
}
