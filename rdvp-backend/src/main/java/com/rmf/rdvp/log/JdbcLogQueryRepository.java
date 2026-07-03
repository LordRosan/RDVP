package com.rmf.rdvp.log;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcLogQueryRepository implements LogQueryRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcLogQueryRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public LogList queryArchiveLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        MapSqlParameterSource parameters = basePageParameters(limit, offset);
        String normalizedType = normalize(type);

        List<String> requestConditions = new ArrayList<>();
        List<String> logEntryConditions = new ArrayList<>();
        logEntryConditions.add("al.action IN ('DEVICE_ARCHIVE_QUERY', 'DEVICE_ARCHIVE_EXPORT')");

        if (!normalizedType.isBlank()) {
            if (isArchiveRequestType(normalizedType)) {
                requestConditions.add("cr.request_type = :type");
                logEntryConditions.add("1 = 0");
            } else if (isArchiveLogEntryType(normalizedType)) {
                requestConditions.add("1 = 0");
                logEntryConditions.add("al.action = :type");
            } else {
                requestConditions.add("1 = 0");
                logEntryConditions.add("1 = 0");
            }
            parameters.addValue("type", normalizedType);
        }

        addKeyword(keyword, parameters);
        if (hasKeyword(keyword)) {
            requestConditions.add("""
                    (
                        COALESCE(d.device_code, cr.target_device_code) ILIKE :keyword
                        OR d.name ILIKE :keyword
                        OR COALESCE(applicant.display_name, applicant.username, cr.applicant_id) ILIKE :keyword
                    )
                    """);
            logEntryConditions.add("""
                    (
                        COALESCE(al.target_no, al.target_id) ILIKE :keyword
                        OR COALESCE(al.actor_name, al.actor_id) ILIKE :keyword
                        OR al.description ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(requestConditions, "COALESCE(cr.initiated_at, cr.created_at)", timeRange, parameters);
        addTimeConditions(logEntryConditions, "al.occurred_at", timeRange, parameters);

        String requestSql = """
                SELECT
                    cr.request_type AS log_type,
                    COALESCE(d.device_code, cr.target_device_code) AS device_code,
                    cr.id AS task_no,
                    COALESCE(applicant.display_name, applicant.username, cr.applicant_id) AS operator_name,
                    COALESCE(cr.initiated_at, cr.created_at) AS occurred_at,
                    cr.status AS business_status,
                    cr.reason AS description,
                    'ARCHIVE_OPERATION' AS log_category
                FROM review_archive_requests cr
                LEFT JOIN archive_devices d ON d.id = cr.device_id
                LEFT JOIN user_accounts applicant ON applicant.id = cr.applicant_id
                """
                + buildWhereClause(requestConditions);

        String logEntrySql = """
                SELECT
                    al.action AS log_type,
                    COALESCE(al.target_no, al.target_id, '-') AS device_code,
                    al.id AS task_no,
                    COALESCE(al.actor_name, al.actor_id, '-') AS operator_name,
                    al.occurred_at AS occurred_at,
                    al.status AS business_status,
                    al.description AS description,
                    'ARCHIVE_OPERATION' AS log_category
                FROM log_entries al
                """
                + buildWhereClause(logEntryConditions);

        return queryUnion(requestSql + " UNION ALL " + logEntrySql, parameters);
    }

    @Override
    public LogList queryArchiveReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        MapSqlParameterSource parameters = basePageParameters(limit, offset);

        List<String> archiveConditions = new ArrayList<>();
        archiveConditions.add("cr.reviewed_at IS NOT NULL");

        String normalizedType = normalize(type);
        if (!normalizedType.isBlank()) {
            archiveConditions.add("cr.request_type = :type");
            parameters.addValue("type", normalizedType);
        }

        addKeyword(keyword, parameters);
        if (hasKeyword(keyword)) {
            archiveConditions.add("""
                    (
                        COALESCE(d.device_code, cr.target_device_code) ILIKE :keyword
                        OR d.name ILIKE :keyword
                        OR COALESCE(reviewer.display_name, reviewer.username, applicant.display_name, applicant.username, cr.reviewer_id, cr.applicant_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(archiveConditions, "cr.reviewed_at", timeRange, parameters);

        String archiveSql = """
                SELECT
                    cr.request_type AS log_type,
                    COALESCE(d.device_code, cr.target_device_code) AS device_code,
                    cr.id AS task_no,
                    COALESCE(reviewer.display_name, reviewer.username, applicant.display_name, applicant.username, cr.reviewer_id, cr.applicant_id) AS operator_name,
                    cr.reviewed_at AS occurred_at,
                    cr.status AS business_status,
                    cr.review_comment AS description,
                    'ARCHIVE_REVIEW' AS log_category
                FROM review_archive_requests cr
                LEFT JOIN archive_devices d ON d.id = cr.device_id
                LEFT JOIN user_accounts applicant ON applicant.id = cr.applicant_id
                LEFT JOIN user_accounts reviewer ON reviewer.id = cr.reviewer_id
                """
                + buildWhereClause(archiveConditions);

        return queryUnion(archiveSql, parameters);
    }

    @Override
    public LogList queryOperationsReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        MapSqlParameterSource parameters = basePageParameters(limit, offset);
        List<String> operationConditions = new ArrayList<>();
        operationConditions.add("orr.reviewed_at IS NOT NULL");

        String normalizedType = normalize(type);
        if (!normalizedType.isBlank()) {
            operationConditions.add("orr.request_type = :type");
            parameters.addValue("type", normalizedType);
        }

        addKeyword(keyword, parameters);
        if (hasKeyword(keyword)) {
            operationConditions.add("""
                    (
                        d.device_code ILIKE :keyword
                        OR d.name ILIKE :keyword
                        OR orr.target_no ILIKE :keyword
                        OR COALESCE(review_op.display_name, review_op.username, op.display_name, op.username, orr.reviewer_id, orr.operator_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(operationConditions, "orr.reviewed_at", timeRange, parameters);

        String operationSql = """
                SELECT
                    orr.request_type AS log_type,
                    d.device_code AS device_code,
                    orr.target_no AS task_no,
                    COALESCE(review_op.display_name, review_op.username, op.display_name, op.username, orr.reviewer_id, orr.operator_id) AS operator_name,
                    orr.reviewed_at AS occurred_at,
                    orr.status AS business_status,
                    orr.review_comment AS description,
                    'OPERATIONS_REVIEW' AS log_category
                FROM review_operations_requests orr
                LEFT JOIN archive_devices d ON d.id = orr.device_id
                LEFT JOIN user_accounts op ON op.id = orr.operator_id
                LEFT JOIN user_accounts review_op ON review_op.id = orr.reviewer_id
                """
                + buildWhereClause(operationConditions);

        return queryUnion(operationSql, parameters);
    }

    @Override
    public LogList queryOperationsLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        MapSqlParameterSource parameters = basePageParameters(limit, offset);
        String normalizedType = normalize(type);
        addKeyword(keyword, parameters);

        List<String> selects = new ArrayList<>();
        selects.add(deviceVerificationSql(normalizedType, keyword, timeRange, parameters));
        selects.add(faultReportSql(normalizedType, keyword, timeRange, parameters));
        selects.add(repairTaskSql(normalizedType, keyword, timeRange, parameters));
        selects.add(repairReportSql(normalizedType, keyword, timeRange, parameters));
        selects.add(reinspectionReportSql(normalizedType, keyword, timeRange, parameters));

        return queryUnion(String.join(" UNION ALL ", selects), parameters);
    }

    private String deviceVerificationSql(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        addTypeFilter(conditions, type, "DEVICE_VERIFICATION");
        if (hasKeyword(keyword)) {
            conditions.add("""
                    (
                        dvrd.device_code ILIKE :keyword
                        OR dvrd.name ILIKE :keyword
                        OR COALESCE(operator.display_name, operator.username, dvr.operator_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(conditions, "dvr.verified_at", timeRange, parameters);
        return """
                SELECT
                    'DEVICE_VERIFICATION' AS log_type,
                    dvrd.device_code,
                    dvr.id AS task_no,
                    COALESCE(operator.display_name, operator.username, dvr.operator_id) AS operator_name,
                    dvr.verified_at AS occurred_at,
                    dvr.result AS business_status,
                    dvr.description,
                    'OPERATIONS_OPERATION' AS log_category
                FROM operations_device_verification_reports dvr
                JOIN archive_devices dvrd ON dvrd.id = dvr.device_id
                LEFT JOIN user_accounts operator ON operator.id = dvr.operator_id
                """
                + buildWhereClause(conditions);
    }

    private String faultReportSql(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        addTypeFilter(conditions, type, "FAULT_REPORT");
        if (hasKeyword(keyword)) {
            conditions.add("""
                    (
                        frd.device_code ILIKE :keyword
                        OR frd.name ILIKE :keyword
                        OR COALESCE(reporter.display_name, reporter.username, fr.reporter_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(conditions, "fr.occurred_at", timeRange, parameters);
        return """
                SELECT
                    'FAULT_REPORT' AS log_type,
                    frd.device_code,
                    fr.fault_report_no AS task_no,
                    COALESCE(reporter.display_name, reporter.username, fr.reporter_id) AS operator_name,
                    fr.occurred_at AS occurred_at,
                    fr.status AS business_status,
                    fr.description,
                    'OPERATIONS_OPERATION' AS log_category
                FROM operations_fault_reports fr
                JOIN archive_devices frd ON frd.id = fr.device_id
                LEFT JOIN user_accounts reporter ON reporter.id = fr.reporter_id
                """
                + buildWhereClause(conditions);
    }

    private String repairTaskSql(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        addTypeFilter(conditions, type, "REPAIR_TASK_ACCEPT");
        if (hasKeyword(keyword)) {
            conditions.add("""
                    (
                        rtd.device_code ILIKE :keyword
                        OR rtd.name ILIKE :keyword
                        OR COALESCE(maintainer.display_name, maintainer.username, rt.maintainer_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(conditions, "rt.accepted_at", timeRange, parameters);
        return """
                SELECT
                    'REPAIR_TASK_ACCEPT' AS log_type,
                    rtd.device_code,
                    rt.repair_task_no AS task_no,
                    COALESCE(maintainer.display_name, maintainer.username, rt.maintainer_id) AS operator_name,
                    rt.accepted_at AS occurred_at,
                    rt.status AS business_status,
                    '' AS description,
                    'OPERATIONS_OPERATION' AS log_category
                FROM operations_repair_tasks rt
                JOIN operations_fault_reports frt ON frt.id = rt.fault_report_id
                JOIN archive_devices rtd ON rtd.id = frt.device_id
                LEFT JOIN user_accounts maintainer ON maintainer.id = rt.maintainer_id
                """
                + buildWhereClause(conditions);
    }

    private String repairReportSql(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        addTypeFilter(conditions, type, "REPAIR_REPORT");
        if (hasKeyword(keyword)) {
            conditions.add("""
                    (
                        rrd.device_code ILIKE :keyword
                        OR rrd.name ILIKE :keyword
                        OR COALESCE(maintainer.display_name, maintainer.username, rr.maintainer_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(conditions, "rr.repaired_at", timeRange, parameters);
        return """
                SELECT
                    'REPAIR_REPORT' AS log_type,
                    rrd.device_code,
                    rr.repair_report_no AS task_no,
                    COALESCE(maintainer.display_name, maintainer.username, rr.maintainer_id) AS operator_name,
                    rr.repaired_at AS occurred_at,
                    rr.result AS business_status,
                    rr.process_description AS description,
                    'OPERATIONS_OPERATION' AS log_category
                FROM operations_repair_reports rr
                JOIN operations_fault_reports frr ON frr.id = rr.fault_report_id
                JOIN archive_devices rrd ON rrd.id = frr.device_id
                LEFT JOIN user_accounts maintainer ON maintainer.id = rr.maintainer_id
                """
                + buildWhereClause(conditions);
    }

    private String reinspectionReportSql(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        addTypeFilter(conditions, type, "REINSPECTION_REPORT");
        if (hasKeyword(keyword)) {
            conditions.add("""
                    (
                        rid.device_code ILIKE :keyword
                        OR rid.name ILIKE :keyword
                        OR COALESCE(reinspector.display_name, reinspector.username, ri.reinspector_id) ILIKE :keyword
                    )
                    """);
        }
        addTimeConditions(conditions, "ri.reinspected_at", timeRange, parameters);
        return """
                SELECT
                    'REINSPECTION_REPORT' AS log_type,
                    rid.device_code,
                    ri.reinspection_report_no AS task_no,
                    COALESCE(reinspector.display_name, reinspector.username, ri.reinspector_id) AS operator_name,
                    ri.reinspected_at AS occurred_at,
                    ri.result AS business_status,
                    ri.description,
                    'OPERATIONS_OPERATION' AS log_category
                FROM operations_reinspection_reports ri
                JOIN operations_fault_reports fir ON fir.id = ri.fault_report_id
                JOIN archive_devices rid ON rid.id = fir.device_id
                LEFT JOIN user_accounts reinspector ON reinspector.id = ri.reinspector_id
                """
                + buildWhereClause(conditions);
    }

    private LogList queryUnion(String unionSql, MapSqlParameterSource parameters) {
        List<LogItem> items = jdbcTemplate.query(
                "SELECT * FROM (" + unionSql + ") logs"
                        + " ORDER BY occurred_at DESC"
                        + " LIMIT :limit OFFSET :offset",
                parameters,
                this::mapLogItem);
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM (" + unionSql + ") logs",
                parameters,
                Long.class);
        return new LogList(items, total == null ? 0 : total);
    }

    private LogItem mapLogItem(ResultSet rs, int rowNum) throws SQLException {
        return new LogItem(
                rs.getString("log_category"),
                rs.getString("log_type"),
                rs.getString("device_code"),
                rs.getString("task_no"),
                rs.getString("operator_name"),
                rs.getObject("occurred_at", java.time.OffsetDateTime.class),
                rs.getString("business_status"),
                rs.getString("description"));
    }

    private MapSqlParameterSource basePageParameters(int limit, int offset) {
        return new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("offset", offset);
    }

    private void addKeyword(String keyword, MapSqlParameterSource parameters) {
        if (hasKeyword(keyword)) {
            parameters.addValue("keyword", "%" + keyword.trim() + "%");
        }
    }

    private boolean hasKeyword(String keyword) {
        return keyword != null && !keyword.isBlank();
    }

    private void addTimeConditions(
            List<String> conditions,
            String occurredAtExpression,
            LogQueryTimeRange timeRange,
            MapSqlParameterSource parameters) {
        if (timeRange == null) {
            return;
        }

        if (timeRange.startInclusive() != null) {
            conditions.add(occurredAtExpression + " >= :startAt");
            parameters.addValue("startAt", timeRange.startInclusive());
        }

        if (timeRange.endExclusive() != null) {
            conditions.add(occurredAtExpression + " < :endAt");
            parameters.addValue("endAt", timeRange.endExclusive());
        }
    }

    private void addTypeFilter(List<String> conditions, String requestedType, String acceptedType) {
        if (requestedType.isBlank() || acceptedType.equalsIgnoreCase(requestedType)) {
            return;
        }

        conditions.add("1 = 0");
    }

    private String buildWhereClause(List<String> conditions) {
        return conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim().toUpperCase();
    }

    private boolean isArchiveRequestType(String type) {
        return "CREATE".equalsIgnoreCase(type)
                || "UPDATE".equalsIgnoreCase(type)
                || "DELETE".equalsIgnoreCase(type);
    }

    private boolean isArchiveLogEntryType(String type) {
        return "DEVICE_ARCHIVE_QUERY".equalsIgnoreCase(type)
                || "DEVICE_ARCHIVE_EXPORT".equalsIgnoreCase(type);
    }
}


