package com.rmf.rdvp.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class RoleCodeTests {

    @Test
    void resolvesCurrentRoleCodesOnly() {
        assertThat(RoleCode.fromCode("superadmin")).isEqualTo(RoleCode.SUPER_ADMIN);
        assertThat(RoleCode.fromCode("archiveadmin")).isEqualTo(RoleCode.ARCHIVE_ADMIN);
        assertThat(RoleCode.fromCode("archivestaff")).isEqualTo(RoleCode.ARCHIVE_STAFF);
        assertThat(RoleCode.fromCode("operationsadmin")).isEqualTo(RoleCode.OPERATIONS_ADMIN);
        assertThat(RoleCode.fromCode("operationsstaff")).isEqualTo(RoleCode.OPERATIONS_STAFF);
        assertThat(RoleCode.fromCode("admin")).isEqualTo(RoleCode.GENERAL_ADMIN);
    }

    @Test
    void rejectsLegacyRoleCodes() {
        for (String legacyCode : new String[] {
                "SUPER_ADMIN",
                "SYSTEM_ADMIN",
                "DEVICE_ADMIN",
                "ARCHIVIST",
                "OPERATIONS_OPERATOR",
                "READ_ONLY"
        }) {
            assertThatThrownBy(() -> RoleCode.fromCode(legacyCode))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessage("Unknown role code: " + legacyCode);
        }
    }
}
