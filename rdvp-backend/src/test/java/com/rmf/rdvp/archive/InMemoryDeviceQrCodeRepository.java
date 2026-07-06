package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryDeviceQrCodeRepository implements DeviceQrCodeRepository {

    private final Map<String, DeviceQrCode> qrCodesByLookupKey = new ConcurrentHashMap<>();

    public InMemoryDeviceQrCodeRepository() {
        Map<String, DeviceQrCode> initialQrCodes = new HashMap<>();
        initialQrCodes.put(
                key("device-local-0001", 1, "nonce-rdvp-device-0001"),
                new DeviceQrCode(
                        "qrcode-local-0001",
                        "device-local-0001",
                        1,
                        "nonce-rdvp-device-0001",
                        "f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807",
                        "ACTIVE",
                        OffsetDateTime.parse("2027-05-29T00:00:00Z")));
        initialQrCodes.put(
                key("device-local-0002", 1, "nonce-rdvp-device-0002"),
                new DeviceQrCode(
                        "qrcode-local-0002",
                        "device-local-0002",
                        1,
                        "nonce-rdvp-device-0002",
                        "c5fb24d08793ff6e3b4a7422874c765e2455d4f6dee7aca680b246b4222f8a37",
                        "ACTIVE",
                        OffsetDateTime.parse("2027-05-29T00:00:00Z")));
        initialQrCodes.put(
                key("device-local-0003", 1, "nonce-rdvp-device-0003"),
                new DeviceQrCode(
                        "qrcode-local-0003",
                        "device-local-0003",
                        1,
                        "nonce-rdvp-device-0003",
                        "6efde5c2594d434cf9294cc04dccd765eb9debd1fc7ec081f13fbe54e7bc6c97",
                        "ACTIVE",
                        OffsetDateTime.parse("2027-05-29T00:00:00Z")));
        initialQrCodes.put(
                key("device-local-0001", 1, "expired-rdvp-device-0001"),
                new DeviceQrCode(
                        "qrcode-local-expired-0001",
                        "device-local-0001",
                        1,
                        "expired-rdvp-device-0001",
                        "5a408b6a7d45f3cf968521e7187a4ade6518fc479f60b01ad1ba3fc4737f8d52",
                        "EXPIRED",
                        OffsetDateTime.parse("2026-01-01T00:00:00Z")));
        qrCodesByLookupKey.putAll(initialQrCodes);
    }

    @Override
    public Optional<DeviceQrCode> findByDeviceIdAndVersionAndNonce(String deviceId, int version, String nonce) {
        return Optional.ofNullable(qrCodesByLookupKey.get(key(deviceId, version, nonce)));
    }

    @Override
    public Optional<DeviceQrCode> findLatestActiveByDeviceId(String deviceId) {
        return qrCodesByLookupKey.values().stream()
                .filter(qrCode -> qrCode.deviceId().equals(deviceId))
                .filter(qrCode -> "ACTIVE".equals(qrCode.status()))
                .filter(qrCode -> qrCode.expiresAt() == null || qrCode.expiresAt().isAfter(OffsetDateTime.now()))
                .max((left, right) -> Integer.compare(left.version(), right.version()));
    }

    @Override
    public int nextVersionByDeviceId(String deviceId) {
        return qrCodesByLookupKey.values().stream()
                .filter(qrCode -> qrCode.deviceId().equals(deviceId))
                .mapToInt(DeviceQrCode::version)
                .max()
                .orElse(0) + 1;
    }

    @Override
    public void create(DeviceQrCodeCreate create) {
        qrCodesByLookupKey.put(
                key(create.deviceId(), create.version(), create.nonce()),
                new DeviceQrCode(
                        create.id(),
                        create.deviceId(),
                        create.version(),
                        create.nonce(),
                        create.signatureHash(),
                        create.status(),
                        create.expiresAt()));
    }

    private static String key(String deviceId, int version, String nonce) {
        return "%s:%d:%s".formatted(deviceId, version, nonce);
    }
}
