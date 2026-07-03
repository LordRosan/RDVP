package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcOperationsRepository implements OperationsRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcOperationsRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void createFaultReport(FaultReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO operations_fault_reports (
                            id,
                            fault_report_no,
                            device_id,
                            reporter_id,
                            fault_type,
                            severity,
                            status,
                            occurred_at,
                            description,
                            scene_condition,
                            longitude,
                            latitude,
                            created_at,
                            updated_at
                        ) VALUES (
                            :id,
                            :faultReportNo,
                            :deviceId,
                            :reporterId,
                            :faultType,
                            :severity,
                            'PENDING_ACCEPTANCE',
                            :occurredAt,
                            :description,
                            :sceneCondition,
                            :longitude,
                            :latitude,
                            :createdAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("faultReportNo", create.faultReportNo())
                        .addValue("deviceId", create.deviceId())
                        .addValue("reporterId", create.reporterId())
                        .addValue("faultType", create.faultType().name())
                        .addValue("severity", create.severity().name())
                        .addValue("occurredAt", create.occurredAt())
                        .addValue("description", create.description())
                        .addValue("sceneCondition", create.sceneCondition())
                        .addValue("longitude", create.longitude())
                        .addValue("latitude", create.latitude())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo) {
        List<FaultReportRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            fault_report_no,
                            device_id,
                            reporter_id,
                            fault_type,
                            severity,
                            status,
                            description,
                            scene_condition,
                            occurred_at,
                            longitude,
                            latitude,
                            accepted_task_id,
                            created_at,
                            updated_at
                        FROM operations_fault_reports
                        WHERE id = :idOrNo
                           OR fault_report_no = :idOrNo
                        """,
                Map.of("idOrNo", idOrNo),
                this::mapFaultReport);
        return results.stream().findFirst();
    }

    @Override
    public boolean hasActiveFaultForDevice(String deviceId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_fault_reports
                        WHERE device_id = :deviceId
                          AND status <> 'CLOSED'
                        """,
                Map.of("deviceId", deviceId),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public List<TaskAcceptanceItem> listTaskAcceptance(
            FaultSeverity severity,
            int radiusKm,
            BigDecimal longitude,
            BigDecimal latitude,
            boolean includeRepairTasks,
            boolean includeReinspectionTasks,
            int limit) {
        List<String> repairConditions = new ArrayList<>();
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("longitude", longitude)
                .addValue("latitude", latitude)
                .addValue("radiusMeters", BigDecimal.valueOf(radiusKm).multiply(BigDecimal.valueOf(1000)));
        repairConditions.add("f.status = 'PENDING_ACCEPTANCE'");
        repairConditions.add("d.deleted_at IS NULL");
        if (severity != null) {
            repairConditions.add("f.severity = :severity");
            parameters.addValue("severity", severity.name());
        }

        boolean hasLocation = longitude != null && latitude != null;
        String repairDistanceExpr = hasLocation
                ? """
                ROUND((
                    ST_DistanceSphere(
                        ST_MakePoint(:longitude, :latitude),
                        ST_MakePoint(d.longitude, d.latitude)
                    ) / 1000.0
                )::numeric, 2) AS distance_km
                """
                : "NULL::numeric AS distance_km";
        String reinspectionDistanceExpr = hasLocation
                ? repairDistanceExpr.replace("d.", "d2.")
                : "NULL::numeric AS distance_km";

        String repairSelect = """
                SELECT
                    f.id,
                    f.fault_report_no,
                    d.device_code,
                    d.name AS device_name,
                    f.fault_type,
                    f.severity,
                    %s,
                    d.address,
                    d.longitude,
                    d.latitude,
                    f.created_at,
                    'REPAIR' AS task_type
                FROM operations_fault_reports f
                JOIN archive_devices d ON d.id = f.device_id
                """.formatted(repairDistanceExpr);

        List<String> geoConditions = new ArrayList<>();
        if (hasLocation) {
            geoConditions.add("d.longitude IS NOT NULL");
            geoConditions.add("d.latitude IS NOT NULL");
            geoConditions.add("""
                    ST_DistanceSphere(
                        ST_MakePoint(:longitude, :latitude),
                        ST_MakePoint(d.longitude, d.latitude)
                    ) <= :radiusMeters
                    """);
        }

        String repairWhere = " WHERE " + String.join(" AND ", repairConditions);
        if (!geoConditions.isEmpty()) {
            repairWhere += " AND " + String.join(" AND ", geoConditions);
        }

        List<String> reinspectionConditions = new ArrayList<>();
        reinspectionConditions.add("f2.status = 'PENDING_REINSPECTION'");
        reinspectionConditions.add("d2.deleted_at IS NULL");
        reinspectionConditions.add("""
                NOT EXISTS (
                    SELECT 1 FROM operations_repair_tasks rt2
                    WHERE rt2.fault_report_id = f2.id
                      AND rt2.task_type = 'REINSPECTION'
                      AND rt2.status IN ('ACCEPTED', 'PROCESSING')
                )
                """);
        if (severity != null) {
            reinspectionConditions.add("f2.severity = :severity");
        }
        if (!geoConditions.isEmpty()) {
            reinspectionConditions.addAll(geoConditions.stream()
                    .map(c -> c.replace("d.", "d2."))
                    .toList());
        }

        String reinspectionSelect = """
                SELECT
                    f2.id,
                    f2.fault_report_no,
                    d2.device_code,
                    d2.name AS device_name,
                    f2.fault_type,
                    f2.severity,
                    %s,
                    d2.address,
                    d2.longitude,
                    d2.latitude,
                    f2.created_at,
                    'REINSPECTION' AS task_type
                FROM operations_fault_reports f2
                JOIN archive_devices d2 ON d2.id = f2.device_id
                """.formatted(reinspectionDistanceExpr);

        String reinspectionWhere = " WHERE " + String.join(" AND ", reinspectionConditions);

        List<String> selectParts = new ArrayList<>();
        if (includeRepairTasks) {
            selectParts.add(repairSelect + repairWhere);
        }
        if (includeReinspectionTasks) {
            selectParts.add(reinspectionSelect + reinspectionWhere);
        }
        if (selectParts.isEmpty()) {
            return List.of();
        }

        String sql = String.join(" UNION ALL ", selectParts)
                + " ORDER BY distance_km ASC NULLS LAST, created_at DESC"
                + " LIMIT :limit";

        return jdbcTemplate.query(sql, parameters, this::mapTaskAcceptance);
    }

    @Override
    public long countPendingAcceptanceFaults() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_fault_reports f
                        JOIN archive_devices d ON d.id = f.device_id
                        WHERE f.status = 'PENDING_ACCEPTANCE'
                          AND d.deleted_at IS NULL
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countTaskPoolItems() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM (
                            SELECT f.id
                            FROM operations_fault_reports f
                            JOIN archive_devices d ON d.id = f.device_id
                            WHERE f.status = 'PENDING_ACCEPTANCE'
                              AND d.deleted_at IS NULL
                            UNION ALL
                            SELECT f2.id
                            FROM operations_fault_reports f2
                            JOIN archive_devices d2 ON d2.id = f2.device_id
                            WHERE f2.status = 'PENDING_REINSPECTION'
                              AND d2.deleted_at IS NULL
                              AND NOT EXISTS (
                                  SELECT 1 FROM operations_repair_tasks rt2
                                  WHERE rt2.fault_report_id = f2.id
                                    AND rt2.task_type = 'REINSPECTION'
                                    AND rt2.status IN ('ACCEPTED', 'PROCESSING')
                              )
                        ) pool_items
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countFaultReports() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_fault_reports
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countRepairTasks() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_repair_tasks
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public boolean hasActiveRepairTaskForFault(String faultReportId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_repair_tasks
                        WHERE fault_report_id = :faultReportId
                          AND status <> 'REPORT_SUBMITTED'
                        """,
                Map.of("faultReportId", faultReportId),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public boolean hasActiveReinspectionTaskForFault(String faultReportId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_repair_tasks
                        WHERE fault_report_id = :faultReportId
                          AND task_type = 'REINSPECTION'
                          AND status IN ('ACCEPTED', 'PROCESSING')
                        """,
                Map.of("faultReportId", faultReportId),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public int countActiveRepairTasksByMaintainer(String maintainerId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_repair_tasks
                        WHERE maintainer_id = :maintainerId
                          AND status IN ('ACCEPTED', 'PROCESSING')
                        """,
                Map.of("maintainerId", maintainerId),
                Integer.class);
        return count == null ? 0 : count;
    }

    @Override
    public void createRepairTask(RepairTaskCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO operations_repair_tasks (
                            id,
                            repair_task_no,
                            fault_report_id,
                            maintainer_id,
                            status,
                            task_type,
                            accepted_longitude,
                            accepted_latitude,
                            accepted_at,
                            created_at,
                            updated_at
                        ) VALUES (
                            :id,
                            :repairTaskNo,
                            :faultReportId,
                            :maintainerId,
                            'ACCEPTED',
                            :taskType,
                            :acceptedLongitude,
                            :acceptedLatitude,
                            :acceptedAt,
                            :acceptedAt,
                            :acceptedAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("repairTaskNo", create.repairTaskNo())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("maintainerId", create.maintainerId())
                        .addValue("taskType", create.taskType() != null ? create.taskType() : "REPAIR")
                        .addValue("acceptedLongitude", create.acceptedLongitude())
                        .addValue("acceptedLatitude", create.acceptedLatitude())
                        .addValue("acceptedAt", create.acceptedAt()));
    }

    @Override
    public boolean markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE operations_fault_reports
                        SET status = 'ACCEPTED',
                            accepted_task_id = :repairTaskId,
                            updated_at = :updatedAt
                        WHERE id = :faultReportId
                          AND status = 'PENDING_ACCEPTANCE'
                          AND accepted_task_id IS NULL
                        """,
                new MapSqlParameterSource()
                        .addValue("faultReportId", faultReportId)
                        .addValue("repairTaskId", repairTaskId)
                        .addValue("updatedAt", updatedAt));
        return updated > 0;
    }

    @Override
    public List<RepairTaskItem> listRepairTasks(String maintainerId, int limit) {
        return jdbcTemplate.query(
                """
                        SELECT
                            rt.id,
                            rt.repair_task_no,
                            f.fault_report_no,
                            d.device_code,
                            d.name AS device_name,
                            f.fault_type,
                            f.severity,
                            rt.accepted_at,
                            rt.status
                        FROM operations_repair_tasks rt
                        JOIN operations_fault_reports f ON f.id = rt.fault_report_id
                        JOIN archive_devices d ON d.id = f.device_id
                        WHERE rt.maintainer_id = :maintainerId
                          AND rt.status <> 'REPORT_SUBMITTED'
                          AND d.deleted_at IS NULL
                        ORDER BY rt.accepted_at DESC
                        LIMIT :limit
                        """,
                Map.of("maintainerId", maintainerId, "limit", limit),
                this::mapRepairTaskItem);
    }

    @Override
    public Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo) {
        List<RepairTaskRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            rt.id,
                            rt.repair_task_no,
                            rt.fault_report_id,
                            f.device_id,
                            rt.maintainer_id,
                            f.severity,
                            rt.status,
                            rt.accepted_longitude,
                            rt.accepted_latitude,
                            rt.accepted_at,
                            rt.completed_at
                        FROM operations_repair_tasks rt
                        JOIN operations_fault_reports f ON f.id = rt.fault_report_id
                        WHERE rt.id = :idOrNo
                           OR rt.repair_task_no = :idOrNo
                        """,
                Map.of("idOrNo", idOrNo),
                this::mapRepairTaskRecord);
        return results.stream().findFirst();
    }

    @Override
    public List<ReinspectionTaskSummary> listPendingReinspections(int limit) {
        return jdbcTemplate.query(
                """
                        SELECT
                            f.id,
                            f.fault_report_no,
                            d.device_code,
                            d.name AS device_name,
                            f.severity,
                            d.address,
                            d.longitude,
                            d.latitude,
                            latest_report.repaired_at,
                            f.status
                        FROM operations_fault_reports f
                        JOIN archive_devices d ON d.id = f.device_id
                        LEFT JOIN LATERAL (
                            SELECT rr.repaired_at
                            FROM operations_repair_reports rr
                            WHERE rr.fault_report_id = f.id
                            ORDER BY rr.created_at DESC
                            LIMIT 1
                        ) latest_report ON TRUE
                        WHERE f.status = 'PENDING_REINSPECTION'
                          AND d.deleted_at IS NULL
                        ORDER BY f.updated_at DESC
                        LIMIT :limit
                        """,
                Map.of("limit", limit),
                this::mapReinspectionTask);
    }

    @Override
    public long countPendingReinspections() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_fault_reports f
                        JOIN archive_devices d ON d.id = f.device_id
                        WHERE f.status = 'PENDING_REINSPECTION'
                          AND d.deleted_at IS NULL
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public void createRepairReport(RepairReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO operations_repair_reports (
                            id,
                            repair_report_no,
                            repair_task_id,
                            fault_report_id,
                            maintainer_id,
                            result,
                            repaired_at,
                            process_description,
                            parts_used,
                            requires_reinspection,
                            created_at
                        ) VALUES (
                            :id,
                            :repairReportNo,
                            :repairTaskId,
                            :faultReportId,
                            :maintainerId,
                            :result,
                            :repairedAt,
                            :processDescription,
                            :partsUsed,
                            :requiresReinspection,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("repairReportNo", create.repairReportNo())
                        .addValue("repairTaskId", create.repairTaskId())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("maintainerId", create.maintainerId())
                        .addValue("result", create.result().name())
                        .addValue("repairedAt", create.repairedAt())
                        .addValue("processDescription", create.processDescription())
                        .addValue("partsUsed", create.partsUsed())
                        .addValue("requiresReinspection", create.requiresReinspection())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public long countRepairReports() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_repair_reports
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId) {
        List<RepairReportRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            repair_report_no,
                            repair_task_id,
                            fault_report_id,
                            maintainer_id,
                            result,
                            repaired_at,
                            process_description,
                            parts_used,
                            requires_reinspection,
                            created_at
                        FROM operations_repair_reports
                        WHERE fault_report_id = :faultReportId
                        ORDER BY created_at DESC
                        LIMIT 1
                        """,
                Map.of("faultReportId", faultReportId),
                this::mapRepairReport);
        return results.stream().findFirst();
    }

    @Override
    public boolean markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE operations_repair_tasks
                        SET status = 'REPORT_SUBMITTED',
                            completed_at = :completedAt,
                            updated_at = :completedAt
                        WHERE id = :repairTaskId
                          AND status IN ('ACCEPTED', 'PROCESSING')
                        """,
                new MapSqlParameterSource()
                        .addValue("repairTaskId", repairTaskId)
                        .addValue("completedAt", completedAt));
        return updated > 0;
    }

    @Override
    public boolean markReinspectionTaskReported(String faultReportId, OffsetDateTime completedAt) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE operations_repair_tasks
                        SET status = 'REPORT_SUBMITTED',
                            completed_at = :completedAt,
                            updated_at = :completedAt
                        WHERE fault_report_id = :faultReportId
                          AND task_type = 'REINSPECTION'
                          AND status IN ('ACCEPTED', 'PROCESSING')
                        """,
                new MapSqlParameterSource()
                        .addValue("faultReportId", faultReportId)
                        .addValue("completedAt", completedAt));
        return updated > 0;
    }

    @Override
    public boolean updateFaultStatusIfCurrent(
            String faultReportId,
            FaultStatus expectedStatus,
            FaultStatus status,
            OffsetDateTime updatedAt) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE operations_fault_reports
                        SET status = :status,
                            closed_at = CASE WHEN :status = 'CLOSED' THEN :updatedAt ELSE closed_at END,
                            accepted_task_id = CASE WHEN :status = 'PENDING_ACCEPTANCE' THEN NULL ELSE accepted_task_id END,
                            updated_at = :updatedAt
                        WHERE id = :faultReportId
                          AND status = :expectedStatus
                        """,
                new MapSqlParameterSource()
                        .addValue("faultReportId", faultReportId)
                        .addValue("expectedStatus", expectedStatus.name())
                        .addValue("status", status.name())
                        .addValue("updatedAt", updatedAt));
        return updated > 0;
    }

    @Override
    public void createReinspectionReport(ReinspectionReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO operations_reinspection_reports (
                            id,
                            reinspection_report_no,
                            fault_report_id,
                            repair_report_id,
                            reinspector_id,
                            result,
                            reinspected_at,
                            description,
                            created_at
                        ) VALUES (
                            :id,
                            :reinspectionReportNo,
                            :faultReportId,
                            :repairReportId,
                            :reinspectorId,
                            :result,
                            :reinspectedAt,
                            :description,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("reinspectionReportNo", create.reinspectionReportNo())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("repairReportId", create.repairReportId())
                        .addValue("reinspectorId", create.reinspectorId())
                        .addValue("result", create.result().name())
                        .addValue("reinspectedAt", create.reinspectedAt())
                        .addValue("description", create.description())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public long countReinspectionReports() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_reinspection_reports
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public void createOperationsReviewRequest(OperationsReviewRequestCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO review_operations_requests (
                            id,
                            request_type,
                            target_id,
                            target_no,
                            fault_report_id,
                            device_id,
                            operator_id,
                            summary,
                            status,
                            submitted_at,
                            created_at,
                            updated_at
                        ) VALUES (
                            :id,
                            :requestType,
                            :targetId,
                            :targetNo,
                            :faultReportId,
                            :deviceId,
                            :operatorId,
                            :summary,
                            'PENDING_REVIEW',
                            :submittedAt,
                            :createdAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("requestType", create.type().name())
                        .addValue("targetId", create.targetId())
                        .addValue("targetNo", create.targetNo())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("deviceId", create.deviceId())
                        .addValue("operatorId", create.operatorId())
                        .addValue("summary", create.summary())
                        .addValue("submittedAt", create.submittedAt())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public Optional<OperationsReviewRequest> findOperationsReviewRequestById(String id) {
        List<OperationsReviewRequest> results = jdbcTemplate.query(
                operationsReviewSelectSql() + " WHERE rr.id = :id",
                Map.of("id", id),
                this::mapOperationsReviewRequest);
        return results.stream().findFirst();
    }

    @Override
    public OperationsReviewRequestPage listOperationsReviewRequests(
            OperationsReviewRequestStatus status,
            OperationsReviewRequestType type,
            String keyword,
            int limit,
            int offset) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("offset", offset);
        if (status != null) {
            conditions.add("rr.status = :status");
            parameters.addValue("status", status.name());
        }
        if (type != null) {
            conditions.add("rr.request_type = :type");
            parameters.addValue("type", type.name());
        }
        if (keyword != null && !keyword.isBlank()) {
            conditions.add("(d.device_code ILIKE :keyword OR d.name ILIKE :keyword OR rr.target_no ILIKE :keyword)");
            parameters.addValue("keyword", "%" + keyword.trim() + "%");
        }

        String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
        List<OperationsReviewRequest> items = jdbcTemplate.query(
                operationsReviewSelectSql()
                        + where
                        + " ORDER BY rr.submitted_at DESC"
                        + " LIMIT :limit OFFSET :offset",
                parameters,
                this::mapOperationsReviewRequest);
        Long total = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM review_operations_requests rr
                        JOIN archive_devices d ON d.id = rr.device_id
                        LEFT JOIN user_accounts op ON op.id = rr.operator_id
                        """
                        + where,
                parameters,
                Long.class);
        return new OperationsReviewRequestPage(items, total == null ? 0 : total);
    }

    @Override
    public boolean markOperationsReviewRequestReviewed(
            String id,
            OperationsReviewRequestStatus status,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE review_operations_requests
                        SET status = :status,
                            reviewer_id = :reviewerId,
                            review_comment = :reviewComment,
                            reviewed_at = :reviewedAt,
                            updated_at = :reviewedAt
                        WHERE id = :id
                          AND status = 'PENDING_REVIEW'
                        """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("status", status.name())
                        .addValue("reviewerId", reviewerId)
                        .addValue("reviewComment", reviewComment)
                        .addValue("reviewedAt", reviewedAt));
        return updated > 0;
    }

    @Override
    public long countPendingOperationsReviews() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM review_operations_requests
                        WHERE status = 'PENDING_REVIEW'
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public long countReviewedOperationsReviews() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM review_operations_requests
                        WHERE status IN ('APPROVED', 'REJECTED')
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    private String operationsReviewSelectSql() {
        return """
                SELECT
                    rr.id,
                    rr.request_type,
                    rr.target_id,
                    rr.target_no,
                    rr.fault_report_id,
                    rr.device_id,
                    d.device_code,
                    d.name AS device_name,
                    rr.operator_id,
                    COALESCE(op.display_name, op.username, rr.operator_id) AS operator_name,
                    rr.summary,
                    rr.status,
                    rr.submitted_at,
                    rr.reviewer_id,
                    rr.review_comment,
                    rr.reviewed_at
                FROM review_operations_requests rr
                JOIN archive_devices d ON d.id = rr.device_id
                LEFT JOIN user_accounts op ON op.id = rr.operator_id
                """;
    }

    private OperationsReviewRequest mapOperationsReviewRequest(ResultSet resultSet, int rowNumber) throws SQLException {
        return new OperationsReviewRequest(
                resultSet.getString("id"),
                OperationsReviewRequestType.valueOf(resultSet.getString("request_type")),
                resultSet.getString("target_id"),
                resultSet.getString("target_no"),
                resultSet.getString("fault_report_id"),
                resultSet.getString("device_id"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                resultSet.getString("operator_id"),
                resultSet.getString("operator_name"),
                resultSet.getString("summary"),
                OperationsReviewRequestStatus.valueOf(resultSet.getString("status")),
                resultSet.getObject("submitted_at", OffsetDateTime.class),
                resultSet.getString("reviewer_id"),
                resultSet.getString("review_comment"),
                resultSet.getObject("reviewed_at", OffsetDateTime.class));
    }

    private FaultReportRecord mapFaultReport(ResultSet resultSet, int rowNumber) throws SQLException {
        return new FaultReportRecord(
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_id"),
                resultSet.getString("reporter_id"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                FaultStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("description"),
                resultSet.getString("scene_condition"),
                resultSet.getObject("occurred_at", OffsetDateTime.class),
                resultSet.getBigDecimal("longitude"),
                resultSet.getBigDecimal("latitude"),
                resultSet.getString("accepted_task_id"),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class));
    }

    private TaskAcceptanceItem mapTaskAcceptance(ResultSet resultSet, int rowNumber) throws SQLException {
        return new TaskAcceptanceItem(
                resultSet.getString("id"),
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                resultSet.getBigDecimal("distance_km"),
                new TaskAcceptanceItem.DeviceLocation(
                        resultSet.getString("address"),
                        resultSet.getBigDecimal("longitude"),
                        resultSet.getBigDecimal("latitude")),
                resultSet.getObject("created_at", OffsetDateTime.class),
                RepairTaskStatus.AVAILABLE,
                resultSet.getString("task_type"));
    }

    private RepairTaskItem mapRepairTaskItem(ResultSet resultSet, int rowNumber) throws SQLException {
        return new RepairTaskItem(
                resultSet.getString("id"),
                resultSet.getString("repair_task_no"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                resultSet.getObject("accepted_at", OffsetDateTime.class),
                RepairTaskStatus.valueOf(resultSet.getString("status")));
    }

    private RepairTaskRecord mapRepairTaskRecord(ResultSet resultSet, int rowNumber) throws SQLException {
        return new RepairTaskRecord(
                resultSet.getString("id"),
                resultSet.getString("repair_task_no"),
                resultSet.getString("fault_report_id"),
                resultSet.getString("device_id"),
                resultSet.getString("maintainer_id"),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                RepairTaskStatus.valueOf(resultSet.getString("status")),
                resultSet.getBigDecimal("accepted_longitude"),
                resultSet.getBigDecimal("accepted_latitude"),
                resultSet.getObject("accepted_at", OffsetDateTime.class),
                resultSet.getObject("completed_at", OffsetDateTime.class));
    }

    private ReinspectionTaskSummary mapReinspectionTask(ResultSet resultSet, int rowNumber) throws SQLException {
        return new ReinspectionTaskSummary(
                resultSet.getString("id"),
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                new TaskAcceptanceItem.DeviceLocation(
                        resultSet.getString("address"),
                        resultSet.getBigDecimal("longitude"),
                        resultSet.getBigDecimal("latitude")),
                resultSet.getObject("repaired_at", OffsetDateTime.class),
                FaultStatus.valueOf(resultSet.getString("status")));
    }

    private RepairReportRecord mapRepairReport(ResultSet resultSet, int rowNumber) throws SQLException {
        return new RepairReportRecord(
                resultSet.getString("id"),
                resultSet.getString("repair_report_no"),
                resultSet.getString("repair_task_id"),
                resultSet.getString("fault_report_id"),
                resultSet.getString("maintainer_id"),
                RepairReportResult.valueOf(resultSet.getString("result")),
                resultSet.getObject("repaired_at", OffsetDateTime.class),
                resultSet.getString("process_description"),
                resultSet.getString("parts_used"),
                resultSet.getBoolean("requires_reinspection"),
                resultSet.getObject("created_at", OffsetDateTime.class));
    }
}
