package com.rmf.rdvp.user;

import java.util.Optional;

public interface UserAccountRepository {

    Optional<BootstrapUser> findByUsername(String username);

    Optional<BootstrapUser> findById(String id);
}
