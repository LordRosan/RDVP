package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcDeviceQrCodeRepository implements DeviceQrCodeRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcDeviceQrCodeRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<DeviceQrCode> findByDeviceIdAndVersionAndNonce(String deviceId, int version, String nonce) {
        List<DeviceQrCode> results = jdbcTemplate.query(
                """
                        SELECT id, device_id, version, nonce, signature_hash, status, expires_at
                        FROM device_qrcodes
                        WHERE device_id = :deviceId
                          AND version = :version
                          AND nonce = :nonce
                        """,
                Map.of("deviceId", deviceId, "version", version, "nonce", nonce),
                this::mapDeviceQrCode);
        return results.stream().findFirst();
    }

    @Override
    public Optional<DeviceQrCode> findLatestActiveByDeviceId(String deviceId) {
        List<DeviceQrCode> results = jdbcTemplate.query(
                """
                        SELECT id, device_id, version, nonce, signature_hash, status, expires_at
                        FROM device_qrcodes
                        WHERE device_id = :deviceId
                          AND status = 'ACTIVE'
                          AND (expires_at IS NULL OR expires_at > NOW())
                        ORDER BY version DESC, issued_at DESC, created_at DESC
                        LIMIT 1
                        """,
                Map.of("deviceId", deviceId),
                this::mapDeviceQrCode);
        return results.stream().findFirst();
    }

    private DeviceQrCode mapDeviceQrCode(ResultSet resultSet, int rowNumber) throws SQLException {
        return new DeviceQrCode(
                resultSet.getString("id"),
                resultSet.getString("device_id"),
                resultSet.getInt("version"),
                resultSet.getString("nonce"),
                resultSet.getString("signature_hash"),
                resultSet.getString("status"),
                resultSet.getObject("expires_at", OffsetDateTime.class));
    }
}
