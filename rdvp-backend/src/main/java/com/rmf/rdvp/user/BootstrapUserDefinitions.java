package com.rmf.rdvp.user;

import java.util.EnumSet;
import java.util.Set;

import org.springframework.security.crypto.password.PasswordEncoder;

final class BootstrapUserDefinitions {

    private BootstrapUserDefinitions() {
    }

    static Set<BootstrapUser> createUsers(PasswordEncoder passwordEncoder, String defaultPassword) {
        Set<PermissionCode> allPermissions = EnumSet.allOf(PermissionCode.class);
        return Set.of(
                create(passwordEncoder, defaultPassword, "usr-admin", "admin", "超级管理员", RoleCode.SUPER_ADMIN, allPermissions),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-archive-admin",
                        "archiveadmin",
                        "档案管理员",
                        RoleCode.ARCHIVE_ADMIN,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_QUERY,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_UPDATE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_DELETE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_EXPORT,
                        PermissionCode.REVIEW_CENTER_ARCHIVE_REQUEST_REVIEW,
                        PermissionCode.LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY,
                        PermissionCode.LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-archivist",
                        "archivist",
                        "档案员",
                        RoleCode.ARCHIVE_STAFF,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_QUERY,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_UPDATE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_DELETE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_EXPORT),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-operations-admin",
                        "operationsadmin",
                        "运维管理员",
                        RoleCode.OPERATIONS_ADMIN,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT,
                        PermissionCode.REVIEW_CENTER_OPERATIONS_REVIEW,
                        PermissionCode.LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY,
                        PermissionCode.LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-operator",
                        "operator",
                        "运维员",
                        RoleCode.OPERATIONS_STAFF,
                        PermissionCode.ARCHIVE_CENTER_ARCHIVE_QUERY,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-manager",
                        "manager",
                        "普通管理员",
                        RoleCode.GENERAL_ADMIN,
                        PermissionCode.REVIEW_CENTER_ARCHIVE_REQUEST_REVIEW,
                        PermissionCode.REVIEW_CENTER_OPERATIONS_REVIEW,
                        PermissionCode.LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY,
                        PermissionCode.LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY,
                        PermissionCode.LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY,
                        PermissionCode.LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY));
    }

    private static BootstrapUser create(
            PasswordEncoder passwordEncoder,
            String password,
            String id,
            String username,
            String displayName,
            RoleCode role,
            PermissionCode... permissions) {
        return create(passwordEncoder, password, id, username, displayName, role, Set.of(permissions));
    }

    private static BootstrapUser create(
            PasswordEncoder passwordEncoder,
            String password,
            String id,
            String username,
            String displayName,
            RoleCode role,
            Set<PermissionCode> permissions) {
        return new BootstrapUser(
                id,
                username,
                passwordEncoder.encode(password),
                displayName,
                UserStatus.ACTIVE,
                Set.of(role),
                Set.copyOf(permissions));
    }
}


