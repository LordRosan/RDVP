package com.rmf.rdvp.sync;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

class OfflineSyncServiceTests {

    @Test
    void synchronizeKeepsBusinessEffectsAndIdempotencyRecordInOneTransaction() throws Exception {
        Transactional transactional = OfflineSyncService.class
                .getMethod("synchronize", String.class, List.class, com.rmf.rdvp.identity.AuthenticatedUser.class)
                .getAnnotation(Transactional.class);

        assertThat(transactional).isNotNull();
    }
}
