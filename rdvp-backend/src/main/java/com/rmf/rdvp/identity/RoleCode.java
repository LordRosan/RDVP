package com.rmf.rdvp.identity;

public enum RoleCode {
    SUPER_ADMIN("superadmin"),
    ARCHIVE_ADMIN("archiveadmin"),
    ARCHIVE_STAFF("archivestaff"),
    OPERATIONS_ADMIN("operationsadmin"),
    OPERATIONS_STAFF("operationsstaff"),
    GENERAL_ADMIN("admin");

    private final String code;

    RoleCode(String code) {
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static RoleCode fromCode(String code) {
        for (RoleCode role : values()) {
            if (role.code.equals(code)) {
                return role;
            }
        }

        throw new IllegalArgumentException("Unknown role code: " + code);
    }
}
