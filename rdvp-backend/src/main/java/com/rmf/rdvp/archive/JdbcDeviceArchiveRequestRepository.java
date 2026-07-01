package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;

@Repository
@Profile("!test")
public class JdbcDeviceArchiveRequestRepository implements DeviceArchiveRequestRepository {

    private static final TypeReference<Map<String, DeviceArchiveFieldChange>> CHANGE_MAP_TYPE = new TypeReference<>() {
    };

    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public JdbcDeviceArchiveRequestRepository(
            NamedParameterJdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public Optional<DeviceArchiveRequest> findById(String id) {
        List<DeviceArchiveRequest> results = jdbcTemplate.query(
                baseSelect() + " WHERE cr.id = :id",
                Map.of("id", id),
                this::mapArchiveRequest);
        return results.stream().findFirst();
    }

    @Override
    public DeviceArchiveRequestPage list(DeviceArchiveRequestQuery query) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", query.pageSize())
                .addValue("offset", (query.page() - 1) * query.pageSize());
        String where = buildWhereClause(query, parameters);

        List<DeviceArchiveRequest> items = jdbcTemplate.query(
                baseSelect() + where + " ORDER BY cr.created_at DESC LIMIT :limit OFFSET :offset",
                parameters,
                this::mapArchiveRequest);
        Long total = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests cr
                        LEFT JOIN devices d ON d.id = cr.device_id
                        """
                        + where,
                parameters,
                Long.class);
        return new DeviceArchiveRequestPage(items, total == null ? 0 : total);
    }

    @Override
    public long countAll() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countPendingReview() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        WHERE status = 'PENDING_REVIEW'
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countApprovedByType(DeviceArchiveRequestType type) {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        WHERE status = 'APPROVED'
                          AND request_type = :requestType
                        """,
                Map.of("requestType", type.name()),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countReviewed() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        WHERE status IN ('APPROVED', 'REJECTED')
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public boolean hasPendingByDeviceId(String deviceId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        WHERE device_id = :deviceId
                          AND status = 'PENDING_REVIEW'
                        """,
                Map.of("deviceId", deviceId),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public boolean hasPendingByTargetDeviceCode(String deviceCode) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_archive_requests
                        WHERE target_device_code = :deviceCode
                          AND status = 'PENDING_REVIEW'
                        """,
                Map.of("deviceCode", deviceCode),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now) {
        List<OffsetDateTime> results = jdbcTemplate.query(
                """
                        SELECT cr.freeze_until
                        FROM device_archive_requests cr
                        LEFT JOIN devices d ON d.id = :deviceId
                        WHERE (cr.device_id = :deviceId OR cr.target_device_code = d.device_code)
                          AND cr.freeze_until IS NOT NULL
                          AND cr.freeze_until > :now
                        ORDER BY freeze_until DESC
                        LIMIT 1
                        """,
                Map.of("deviceId", deviceId, "now", now),
                (resultSet, rowNumber) -> resultSet.getObject("freeze_until", OffsetDateTime.class));
        return results.stream().findFirst();
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntilByTargetDeviceCode(String deviceCode, OffsetDateTime now) {
        List<OffsetDateTime> results = jdbcTemplate.query(
                """
                        SELECT freeze_until
                        FROM device_archive_requests
                        WHERE target_device_code = :deviceCode
                          AND freeze_until IS NOT NULL
                          AND freeze_until > :now
                        ORDER BY freeze_until DESC
                        LIMIT 1
                        """,
                Map.of("deviceCode", deviceCode, "now", now),
                (resultSet, rowNumber) -> resultSet.getObject("freeze_until", OffsetDateTime.class));
        return results.stream().findFirst();
    }

    @Override
    public void create(DeviceArchiveRequestCreate request) {
        jdbcTemplate.update(
                """
                        INSERT INTO device_archive_requests (
                            id,
                            request_type,
                            device_id,
                            target_device_code,
                            applicant_id,
                            status,
                            previous_device_status,
                            reason,
                            changes,
                            initiated_at,
                            created_at,
                            created_by,
                            updated_at,
                            updated_by
                        ) VALUES (
                            :id,
                            :requestType,
                            :deviceId,
                            :targetDeviceCode,
                            :applicantId,
                            'PENDING_REVIEW',
                            :previousDeviceStatus,
                            :reason,
                            CAST(:changes AS jsonb),
                            :initiatedAt,
                            :createdAt,
                            :applicantId,
                            :createdAt,
                            :applicantId
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", request.id())
                        .addValue("requestType", request.type().name())
                        .addValue("deviceId", request.deviceId())
                        .addValue("targetDeviceCode", request.targetDeviceCode())
                        .addValue("applicantId", request.applicantId())
                        .addValue("previousDeviceStatus", request.previousDeviceStatus())
                        .addValue("reason", request.reason())
                        .addValue("changes", writeChanges(request.changes()))
                        .addValue("initiatedAt", request.initiatedAt())
                        .addValue("createdAt", request.createdAt()));
    }

    @Override
    public boolean applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            DeviceArchiveUpdate archiveUpdate) {
        jdbcTemplate.update(
                """
                        UPDATE devices
                        SET name = :name,
                            model = :model,
                            manufacturer = :manufacturer,
                            address = :address,
                            updated_at = :updatedAt,
                            updated_by = :updatedBy
                        WHERE id = :deviceId
                          AND deleted_at IS NULL
                        """,
                new MapSqlParameterSource()
                        .addValue("deviceId", archiveUpdate.deviceId())
                        .addValue("name", archiveUpdate.name())
                        .addValue("model", archiveUpdate.model())
                        .addValue("manufacturer", archiveUpdate.manufacturer())
                        .addValue("address", archiveUpdate.address())
                        .addValue("updatedAt", archiveUpdate.updatedAt())
                        .addValue("updatedBy", archiveUpdate.updatedBy()));
        int updatedRequest = jdbcTemplate.update(
                """
                        UPDATE device_archive_requests
                        SET status = 'APPROVED',
                            reviewer_id = :reviewerId,
                            review_comment = :reviewComment,
                            reviewed_at = :reviewedAt,
                            freeze_until = :freezeUntil,
                            updated_at = :reviewedAt,
                            updated_by = :reviewerId
                        WHERE id = :requestId
                          AND status = 'PENDING_REVIEW'
                        """,
                new MapSqlParameterSource()
                        .addValue("requestId", requestId)
                        .addValue("reviewerId", reviewerId)
                        .addValue("reviewComment", reviewComment)
                        .addValue("reviewedAt", reviewedAt)
                        .addValue("freezeUntil", freezeUntil));
        return updatedRequest > 0;
    }

    @Override
    public boolean markApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE device_archive_requests
                        SET status = 'APPROVED',
                            reviewer_id = :reviewerId,
                            review_comment = :reviewComment,
                            reviewed_at = :reviewedAt,
                            freeze_until = :freezeUntil,
                            updated_at = :reviewedAt,
                            updated_by = :reviewerId
                        WHERE id = :requestId
                          AND status = 'PENDING_REVIEW'
                        """,
                new MapSqlParameterSource()
                        .addValue("requestId", requestId)
                        .addValue("reviewerId", reviewerId)
                        .addValue("reviewComment", reviewComment)
                        .addValue("reviewedAt", reviewedAt)
                        .addValue("freezeUntil", freezeUntil));
        return updated > 0;
    }

    @Override
    public boolean applyRejectedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE device_archive_requests
                        SET status = 'REJECTED',
                            reviewer_id = :reviewerId,
                            review_comment = :reviewComment,
                            reviewed_at = :reviewedAt,
                            freeze_until = :freezeUntil,
                            updated_at = :reviewedAt,
                            updated_by = :reviewerId
                        WHERE id = :requestId
                          AND status = 'PENDING_REVIEW'
                        """,
                new MapSqlParameterSource()
                        .addValue("requestId", requestId)
                        .addValue("reviewerId", reviewerId)
                        .addValue("reviewComment", reviewComment)
                        .addValue("reviewedAt", reviewedAt)
                        .addValue("freezeUntil", freezeUntil));
        return updated > 0;
    }

    private String baseSelect() {
        return """
                SELECT
                    cr.id,
                    cr.request_type,
                    cr.device_id,
                    COALESCE(d.device_code, cr.target_device_code) AS device_code,
                    d.name AS device_name,
                    cr.applicant_id,
                    cr.status,
                    cr.reason,
                    cr.changes,
                    COALESCE(cr.initiated_at, cr.created_at) AS initiated_at,
                    cr.created_at,
                    cr.reviewer_id,
                    cr.review_comment,
                    cr.reviewed_at,
                    cr.freeze_until
                FROM device_archive_requests cr
                LEFT JOIN devices d ON d.id = cr.device_id
                """;
    }

    private String buildWhereClause(DeviceArchiveRequestQuery query, MapSqlParameterSource parameters) {
        List<String> conditions = new java.util.ArrayList<>();
        if (query.status() != null) {
            conditions.add("cr.status = :status");
            parameters.addValue("status", query.status().name());
        }

        if (query.deviceCode() != null && !query.deviceCode().isBlank()) {
            conditions.add("COALESCE(d.device_code, cr.target_device_code) = :deviceCode");
            parameters.addValue("deviceCode", query.deviceCode());
        }

        if (query.applicantId() != null && !query.applicantId().isBlank()) {
            conditions.add("cr.applicant_id = :applicantId");
            parameters.addValue("applicantId", query.applicantId());
        }

        if (query.type() != null && !query.type().isBlank()) {
            conditions.add("cr.request_type = :type");
            parameters.addValue("type", query.type());
        }

        if (conditions.isEmpty()) {
            return "";
        }

        return " WHERE " + String.join(" AND ", conditions);
    }

    private DeviceArchiveRequest mapArchiveRequest(ResultSet resultSet, int rowNumber) throws SQLException {
        Map<String, DeviceArchiveFieldChange> changes = readChanges(resultSet.getString("changes"));
        return new DeviceArchiveRequest(
                resultSet.getString("id"),
                DeviceArchiveRequestType.valueOf(resultSet.getString("request_type")),
                resultSet.getString("device_id"),
                resultSet.getString("device_code"),
                resolveDeviceName(resultSet.getString("device_name"), changes),
                resultSet.getString("applicant_id"),
                null,
                DeviceArchiveRequestStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("reason"),
                changes,
                resultSet.getObject("initiated_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getString("reviewer_id"),
                resultSet.getString("review_comment"),
                resultSet.getObject("reviewed_at", OffsetDateTime.class),
                resultSet.getObject("freeze_until", OffsetDateTime.class));
    }

    private String resolveDeviceName(String deviceName, Map<String, DeviceArchiveFieldChange> changes) {
        if (deviceName != null && !deviceName.isBlank()) {
            return deviceName;
        }

        DeviceArchiveFieldChange nameChange = changes.get("name");
        if (nameChange != null && nameChange.newValue() != null && !nameChange.newValue().isBlank()) {
            return nameChange.newValue();
        }

        return "-";
    }

    private String writeChanges(Map<String, DeviceArchiveFieldChange> changes) {
        try {
            return objectMapper.writeValueAsString(changes);
        } catch (JsonProcessingException exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private Map<String, DeviceArchiveFieldChange> readChanges(String changesJson) {
        try {
            return objectMapper.readValue(changesJson, CHANGE_MAP_TYPE);
        } catch (JsonProcessingException exception) {
            return new HashMap<>();
        }
    }
}
