package com.rmf.rdvp.architecture;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

class DomainTableNamingTests {

    private static final Path DOMAIN_CONSTRAINT_MIGRATION =
            Path.of("src/main/resources/db/migration/V32__standardize_domain_constraint_names.sql");
    private static final Path ARCHIVE_FEATURE_VALUE_MIGRATION =
            Path.of("src/main/resources/db/migration/V33__rename_archive_feature_values.sql");
    private static final Path ARCHIVE_DESCRIPTION_VALUE_MIGRATION =
            Path.of("src/main/resources/db/migration/V34__rename_archive_description_values.sql");
    private static final Path OPERATIONS_TASK_NODE_MIGRATION =
            Path.of("src/main/resources/db/migration/V39__align_operations_task_node_constraints.sql");

    private static final Set<String> ALLOWED_DOMAIN_PACKAGES = Set.of(
            "archive",
            "home",
            "log",
            "operations",
            "review",
            "shared",
            "user");

    private static final List<Pattern> LEGACY_TABLE_PATTERNS = List.of(
            Pattern.compile("\\bFROM\\s+devices\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+devices\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+devices\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+devices\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+device_qrcodes\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+device_qrcodes\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+device_qrcodes\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+device_qrcodes\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+device_archive_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+device_archive_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+device_archive_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+device_archive_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+device_verification_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+device_verification_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+device_verification_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+device_verification_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+device_verification_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+device_verification_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+device_verification_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+device_verification_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+fault_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+fault_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+fault_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+fault_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+repair_tasks\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+repair_tasks\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+repair_tasks\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+repair_tasks\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+repair_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+repair_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+repair_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+repair_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+reinspection_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+reinspection_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+reinspection_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+reinspection_records\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+reinspection_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+reinspection_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+reinspection_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+reinspection_reports\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+operations_review_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+operations_review_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+operations_review_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+operations_review_requests\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+audit_logs\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+audit_logs\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+audit_logs\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+audit_logs\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+users\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+users\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+users\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+users\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+user_roles\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+user_roles\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+user_roles\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+user_roles\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+user_permissions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+user_permissions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+user_permissions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+user_permissions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+token_sessions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+token_sessions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+token_sessions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+token_sessions\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+password_verification_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+password_verification_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+password_verification_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+password_verification_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bFROM\\s+login_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bJOIN\\s+login_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bUPDATE\\s+login_attempts\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bINSERT\\s+INTO\\s+login_attempts\\b", Pattern.CASE_INSENSITIVE));

    private static final List<String> REQUIRED_DOMAIN_CONSTRAINT_RENAMES = List.of(
            "ALTER TABLE IF EXISTS archive_devices RENAME CONSTRAINT devices_pkey TO pk_archive_devices;",
            "ALTER TABLE IF EXISTS archive_device_qr_codes RENAME CONSTRAINT device_qrcodes_pkey TO pk_archive_device_qr_codes;",
            "ALTER TABLE IF EXISTS log_entries RENAME CONSTRAINT audit_logs_pkey TO pk_log_entries;",
            "ALTER TABLE IF EXISTS operations_device_verification_reports RENAME CONSTRAINT device_verification_records_pkey TO pk_operations_device_verification_reports;",
            "ALTER TABLE IF EXISTS operations_fault_reports RENAME CONSTRAINT fault_reports_pkey TO pk_operations_fault_reports;",
            "ALTER TABLE IF EXISTS operations_repair_tasks RENAME CONSTRAINT repair_tasks_pkey TO pk_operations_repair_tasks;",
            "ALTER TABLE IF EXISTS operations_repair_reports RENAME CONSTRAINT repair_reports_pkey TO pk_operations_repair_reports;",
            "ALTER TABLE IF EXISTS operations_reinspection_reports RENAME CONSTRAINT reinspection_records_pkey TO pk_operations_reinspection_reports;",
            "ALTER TABLE IF EXISTS review_archive_requests RENAME CONSTRAINT device_archive_requests_pkey TO pk_review_archive_requests;",
            "ALTER TABLE IF EXISTS review_operations_requests RENAME CONSTRAINT operations_review_requests_pkey TO pk_review_operations_requests;",
            "ALTER TABLE IF EXISTS user_accounts RENAME CONSTRAINT users_pkey TO pk_user_accounts;",
            "ALTER TABLE IF EXISTS user_account_roles RENAME CONSTRAINT user_roles_pkey TO pk_user_account_roles;",
            "ALTER TABLE IF EXISTS user_account_permissions RENAME CONSTRAINT user_permissions_pkey TO pk_user_account_permissions;",
            "ALTER TABLE IF EXISTS user_token_sessions RENAME CONSTRAINT token_sessions_pkey TO pk_user_token_sessions;",
            "ALTER TABLE IF EXISTS user_password_verification_attempts RENAME CONSTRAINT password_verification_attempts_pkey TO pk_user_password_verification_attempts;",
            "ALTER TABLE IF EXISTS user_login_attempts RENAME CONSTRAINT login_attempts_pkey TO pk_user_login_attempts;",
            "ALTER INDEX IF EXISTS idx_devices_location_geography RENAME TO idx_archive_devices_location_geography;",
            "ALTER INDEX IF EXISTS idx_fault_reports_status_updated RENAME TO idx_operations_fault_reports_status_updated;",
            "ALTER INDEX IF EXISTS ux_fault_reports_active_device RENAME TO ux_operations_fault_reports_active_device;",
            "ALTER INDEX IF EXISTS idx_repair_tasks_maintainer_status_type RENAME TO idx_operations_repair_tasks_maintainer_status_type;",
            "ALTER INDEX IF EXISTS idx_repair_reports_fault_created RENAME TO idx_operations_repair_reports_fault_created;",
            "ALTER INDEX IF EXISTS idx_device_archive_requests_initiated_at RENAME TO idx_review_archive_requests_initiated_at;",
            "ALTER INDEX IF EXISTS ux_device_archive_requests_pending_target_code RENAME TO ux_review_archive_requests_pending_target_code;");

    private static final List<String> REQUIRED_ARCHIVE_FEATURE_VALUE_RENAMES = List.of(
            "WHEN 'ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY' THEN 'ARCHIVE_CENTER_ARCHIVE_QUERY'",
            "WHEN 'ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT' THEN 'ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT'",
            "WHEN 'ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT' THEN 'ARCHIVE_CENTER_ARCHIVE_UPDATE_REQUEST_SUBMIT'",
            "WHEN 'ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT' THEN 'ARCHIVE_CENTER_ARCHIVE_DELETE_REQUEST_SUBMIT'",
            "WHEN 'ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT' THEN 'ARCHIVE_CENTER_ARCHIVE_EXPORT'",
            "WHEN 'REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW' THEN 'REVIEW_CENTER_ARCHIVE_REQUEST_REVIEW'",
            "WHEN 'DEVICE_ARCHIVE_QUERY' THEN 'ARCHIVE_QUERY'",
            "WHEN 'DEVICE_ARCHIVE_EXPORT' THEN 'ARCHIVE_EXPORT'",
            "WHEN 'DEVICE_ARCHIVE_REQUEST' THEN 'ARCHIVE_REQUEST'",
            "WHEN 'DEVICE_ARCHIVE_REVIEW' THEN 'ARCHIVE_REVIEW'",
            "WHEN '查询设备档案。' THEN '查询档案。'",
            "WHEN '导出设备档案。' THEN '导出档案。'",
            "WHEN '新增设备档案。' THEN '新增档案。'");

    @Test
    void jdbcSqlUsesDomainTableNames() throws IOException {
        Path sourceRoot = Path.of("src/main/java");

        List<String> violations;
        try (Stream<Path> files = Files.walk(sourceRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .flatMap(DomainTableNamingTests::legacyTableViolations)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void backendLogDomainUsesSingularLogNaming() throws IOException {
        Path sourceRoot = Path.of("src/main/java");

        List<String> violations;
        try (Stream<Path> files = Files.walk(sourceRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .flatMap(DomainTableNamingTests::legacyLogDomainViolations)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void backendPackagesUseDomainFirstLayout() throws IOException {
        Path sourceRoot = Path.of("src/main/java");

        List<String> violations;
        try (Stream<Path> files = Files.walk(sourceRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .flatMap(DomainTableNamingTests::domainPackageViolations)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void javaPackagesMatchSourcePaths() throws IOException {
        List<String> violations = Stream.concat(
                        packagePathViolations(Path.of("src/main/java/com/rmf/rdvp")),
                        packagePathViolations(Path.of("src/test/java/com/rmf/rdvp")))
                .toList();

        assertThat(violations).isEmpty();
    }

    @Test
    void domainConstraintMigrationRenamesLegacyPhysicalObjectNames() throws IOException {
        String migration = Files.readString(DOMAIN_CONSTRAINT_MIGRATION, StandardCharsets.UTF_8);

        assertThat(migration.lines().map(String::trim).toList())
                .containsAll(REQUIRED_DOMAIN_CONSTRAINT_RENAMES);
    }

    @Test
    void archiveFeatureValueMigrationRenamesPersistedLegacyValues() throws IOException {
        assertThat(ARCHIVE_FEATURE_VALUE_MIGRATION)
                .exists();

        String migration = Files.readString(ARCHIVE_FEATURE_VALUE_MIGRATION, StandardCharsets.UTF_8);

        assertThat(migration.lines().map(String::trim).toList())
                .containsAll(REQUIRED_ARCHIVE_FEATURE_VALUE_RENAMES);
    }

    @Test
    void archiveDescriptionValueMigrationRemovesLegacyDeviceArchivePhrase() throws IOException {
        assertThat(ARCHIVE_DESCRIPTION_VALUE_MIGRATION)
                .exists();

        String migration = Files.readString(ARCHIVE_DESCRIPTION_VALUE_MIGRATION, StandardCharsets.UTF_8);

        assertThat(migration.lines().map(String::trim).toList())
                .contains(
                        "SET description = replace(description, '设备档案', '档案')",
                        "WHERE description LIKE '%设备档案%';");
    }

    @Test
    void archiveDomainDoesNotOwnOperationsDeviceVerificationConcepts() throws IOException {
        Path archiveRoot = Path.of("src/main/java/com/rmf/rdvp/archive");

        List<String> violations;
        try (Stream<Path> files = Files.walk(archiveRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .filter(DomainTableNamingTests::containsDeviceVerificationToken)
                    .map(Path::toString)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void archiveDomainUsesArchiveFeatureNaming() throws IOException {
        Path sourceRoot = Path.of("src/main/java");

        List<String> violations;
        try (Stream<Path> files = Files.walk(sourceRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> !path.toString().contains("db/migration"))
                    .flatMap(DomainTableNamingTests::legacyArchiveFeatureViolations)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void sourceTextDoesNotUseLegacyDeviceArchivePhrase() throws IOException {
        List<String> violations = Stream.concat(
                        legacyDeviceArchivePhraseViolations(Path.of("src/main/java")),
                        legacyDeviceArchivePhraseViolations(Path.of("../entry/src/main/ets")))
                .toList();

        assertThat(violations).isEmpty();
    }

    @Test
    void operationsAbnormalVerificationSubmissionDropsLegacyCombinedNaming() throws IOException {
        Path sourceRoot = Path.of("src/main/java");

        List<String> violations;
        try (Stream<Path> files = Files.walk(sourceRoot)) {
            violations = files
                    .filter(path -> path.toString().endsWith(".java"))
                    .flatMap(DomainTableNamingTests::legacyCombinedVerificationSubmissionViolations)
                    .toList();
        }

        assertThat(violations).isEmpty();
    }

    @Test
    void operationsSourceTextDoesNotUseLegacyDeviceVerificationPhrase() throws IOException {
        List<String> violations = Stream.concat(
                        legacyDeviceVerificationPhraseViolations(Path.of("src/main/java")),
                        legacyDeviceVerificationPhraseViolations(Path.of("../entry/src/main/ets")))
                .toList();

        assertThat(violations).isEmpty();
    }

    @Test
    void operationsTaskNodeMigrationReplacesLegacyActiveFaultUniqueness() throws IOException {
        assertThat(OPERATIONS_TASK_NODE_MIGRATION)
                .exists();

        String migration = Files.readString(OPERATIONS_TASK_NODE_MIGRATION, StandardCharsets.UTF_8);

        assertThat(migration)
                .contains("DROP INDEX IF EXISTS ux_operations_repair_tasks_active_fault")
                .contains("ux_operations_repair_tasks_active_fault_node")
                .contains("WHERE status IN ('AVAILABLE', 'ACCEPTED', 'PROCESSING')")
                .contains("fk_operations_repair_tasks_parent_task");
    }

    private static Stream<String> legacyTableViolations(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            return LEGACY_TABLE_PATTERNS.stream()
                    .filter(pattern -> pattern.matcher(content).find())
                    .map(pattern -> file + " contains " + pattern.pattern());
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> legacyLogDomainViolations(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            return Stream.of(
                            "package com.rmf.rdvp.audit",
                            "package com.rmf.rdvp.logs",
                            "package com.rmf.rdvp.api.audit",
                            "import com.rmf.rdvp.audit",
                            "import com.rmf.rdvp.logs",
                            "/api/v1/audit-logs")
                    .filter(content::contains)
                    .map(legacyToken -> file + " contains " + legacyToken);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> domainPackageViolations(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            var matcher = Pattern.compile("^package\\s+com\\.rmf\\.rdvp\\.([a-z]+)", Pattern.MULTILINE).matcher(content);
            if (!matcher.find()) {
                return Stream.empty();
            }

            String firstSegment = matcher.group(1);
            if (ALLOWED_DOMAIN_PACKAGES.contains(firstSegment)) {
                return Stream.empty();
            }

            return Stream.of(file + " uses top-level package " + firstSegment);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> packagePathViolations(Path sourceRoot) {
        try {
            return Files.walk(sourceRoot)
                    .filter(path -> path.toString().endsWith(".java"))
                    .flatMap(file -> packagePathViolation(sourceRoot, file));
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + sourceRoot, exception);
        }
    }

    private static Stream<String> packagePathViolation(Path sourceRoot, Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            var matcher = Pattern.compile("^package\\s+([^;]+);", Pattern.MULTILINE).matcher(content);
            if (!matcher.find()) {
                return Stream.empty();
            }

            Path relativeParent = sourceRoot.relativize(file).getParent();
            String expectedPackage = "com.rmf.rdvp";
            if (relativeParent != null) {
                expectedPackage = expectedPackage + "." + relativeParent.toString().replace('\\', '.').replace('/', '.');
            }

            String actualPackage = matcher.group(1);
            if (expectedPackage.equals(actualPackage)) {
                return Stream.empty();
            }

            return Stream.of(file + " declares " + actualPackage + " but lives under " + expectedPackage);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> legacyArchiveFeatureViolations(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            return Stream.of(
                            "DeviceArchive",
                            "DEVICE_ARCHIVE",
                            "device-archive")
                    .filter(content::contains)
                    .map(legacyToken -> file + " contains " + legacyToken);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> legacyDeviceArchivePhraseViolations(Path sourceRoot) throws IOException {
        if (!Files.exists(sourceRoot)) {
            return Stream.empty();
        }

        return Files.walk(sourceRoot)
                .filter(Files::isRegularFile)
                .filter(path -> path.toString().endsWith(".java") || path.toString().endsWith(".ets"))
                .flatMap(file -> {
                    try {
                        String content = Files.readString(file, StandardCharsets.UTF_8);
                        return Stream.of("device archive", "Device Archive", "设备档案")
                                .filter(content::contains)
                                .map(legacyToken -> file + " contains " + legacyToken);
                    } catch (IOException exception) {
                        throw new IllegalStateException("Failed to inspect " + file, exception);
                    }
                });
    }

    private static Stream<String> legacyCombinedVerificationSubmissionViolations(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            return Stream.of(
                            "Device" + "Verification" + "And" + "Fault" + "Report",
                            "Verification" + "And" + "Fault" + "Report",
                            "DEVICE_VERIFICATION" + "_AND_FAULT_REPORT")
                    .filter(content::contains)
                    .map(legacyToken -> file + " contains " + legacyToken);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }

    private static Stream<String> legacyDeviceVerificationPhraseViolations(Path sourceRoot) throws IOException {
        if (!Files.exists(sourceRoot)) {
            return Stream.empty();
        }

        return Files.walk(sourceRoot)
                .filter(Files::isRegularFile)
                .filter(path -> path.toString().endsWith(".java") || path.toString().endsWith(".ets"))
                .flatMap(file -> {
                    try {
                        String content = Files.readString(file, StandardCharsets.UTF_8);
                        return Stream.of("设备核验")
                                .filter(content::contains)
                                .map(legacyToken -> file + " contains " + legacyToken);
                    } catch (IOException exception) {
                        throw new IllegalStateException("Failed to inspect " + file, exception);
                    }
                });
    }

    private static boolean containsDeviceVerificationToken(Path file) {
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8);
            return content.contains("DeviceVerification");
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to inspect " + file, exception);
        }
    }
}
