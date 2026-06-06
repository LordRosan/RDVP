package com.rmf.rdvp.sync;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
@Profile("!test")
public class JdbcOfflineSyncRepository implements OfflineSyncRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcOfflineSyncRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<OfflineSyncBatchResult> findBatchResult(String userId, String clientBatchId) {
        List<OfflineSyncBatchStatus> batches = jdbcTemplate.query(
                """
                        SELECT status
                        FROM offline_sync_batches
                        WHERE user_id = :userId
                          AND client_batch_id = :clientBatchId
                        """,
                Map.of("userId", userId, "clientBatchId", clientBatchId),
                (resultSet, rowNumber) -> OfflineSyncBatchStatus.valueOf(resultSet.getString("status")));
        if (batches.isEmpty()) {
            return Optional.empty();
        }

        List<OfflineSyncRecordResult> records = jdbcTemplate.query(
                """
                        SELECT client_record_id, record_type, status, server_record_id, error_code, error_message
                        FROM offline_sync_records
                        WHERE user_id = :userId
                          AND batch_id = (
                              SELECT id
                              FROM offline_sync_batches
                              WHERE user_id = :userId
                                AND client_batch_id = :clientBatchId
                              LIMIT 1
                          )
                        ORDER BY created_at ASC, id ASC
                        """,
                Map.of("userId", userId, "clientBatchId", clientBatchId),
                this::mapRecordResult);
        return Optional.of(new OfflineSyncBatchResult(clientBatchId, batches.getFirst(), records));
    }

    @Override
    public Optional<OfflineSyncStoredRecord> findRecord(String userId, String clientRecordId) {
        List<OfflineSyncStoredRecord> records = jdbcTemplate.query(
                """
                        SELECT client_record_id,
                               record_type,
                               payload_hash,
                               status,
                               server_record_id,
                               error_code,
                               error_message
                        FROM offline_sync_records
                        WHERE user_id = :userId
                          AND client_record_id = :clientRecordId
                        ORDER BY processed_at DESC NULLS LAST, created_at DESC, id DESC
                        LIMIT 1
                        """,
                Map.of("userId", userId, "clientRecordId", clientRecordId),
                this::mapStoredRecord);
        return records.stream().findFirst();
    }

    @Override
    @Transactional
    public void saveBatch(OfflineSyncBatchCreate batch) {
        jdbcTemplate.update(
                """
                        INSERT INTO offline_sync_batches (
                            id,
                            client_batch_id,
                            user_id,
                            status,
                            submitted_at,
                            created_at
                        ) VALUES (
                            :id,
                            :clientBatchId,
                            :userId,
                            :status,
                            :submittedAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", batch.id())
                        .addValue("clientBatchId", batch.clientBatchId())
                        .addValue("userId", batch.userId())
                        .addValue("status", batch.status().name())
                        .addValue("submittedAt", batch.submittedAt())
                        .addValue("createdAt", batch.createdAt()));

        for (OfflineSyncRecordCreate record : batch.records()) {
            jdbcTemplate.update(
                    """
                            INSERT INTO offline_sync_records (
                                id,
                                batch_id,
                                user_id,
                                client_record_id,
                                record_type,
                                payload,
                                payload_hash,
                                status,
                                server_record_id,
                                error_code,
                                error_message,
                                created_offline_at,
                                processed_at,
                                created_at
                            ) VALUES (
                                :id,
                                :batchId,
                                :userId,
                                :clientRecordId,
                                :recordType,
                                CAST(:payload AS jsonb),
                                :payloadHash,
                                :status,
                                :serverRecordId,
                                :errorCode,
                                :errorMessage,
                                :createdOfflineAt,
                                :processedAt,
                                :createdAt
                            )
                            """,
                    new MapSqlParameterSource()
                            .addValue("id", record.id())
                            .addValue("batchId", batch.id())
                            .addValue("userId", batch.userId())
                            .addValue("clientRecordId", record.clientRecordId())
                            .addValue("recordType", record.recordType().name())
                            .addValue("payload", record.payloadJson())
                            .addValue("payloadHash", record.payloadHash())
                            .addValue("status", record.status().name())
                            .addValue("serverRecordId", record.serverRecordId())
                            .addValue("errorCode", record.errorCode())
                            .addValue("errorMessage", record.errorMessage())
                            .addValue("createdOfflineAt", record.createdOfflineAt())
                            .addValue("processedAt", record.processedAt())
                            .addValue("createdAt", record.createdAt()));
        }
    }

    private OfflineSyncRecordResult mapRecordResult(ResultSet resultSet, int rowNumber) throws SQLException {
        return new OfflineSyncRecordResult(
                resultSet.getString("client_record_id"),
                OfflineSyncRecordType.valueOf(resultSet.getString("record_type")),
                OfflineSyncRecordStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("server_record_id"),
                resultSet.getString("error_code"),
                resultSet.getString("error_message"));
    }

    private OfflineSyncStoredRecord mapStoredRecord(ResultSet resultSet, int rowNumber) throws SQLException {
        OfflineSyncRecordType recordType = OfflineSyncRecordType.valueOf(resultSet.getString("record_type"));
        return new OfflineSyncStoredRecord(
                recordType,
                resultSet.getString("payload_hash"),
                new OfflineSyncRecordResult(
                        resultSet.getString("client_record_id"),
                        recordType,
                        OfflineSyncRecordStatus.valueOf(resultSet.getString("status")),
                        resultSet.getString("server_record_id"),
                        resultSet.getString("error_code"),
                        resultSet.getString("error_message")));
    }
}
