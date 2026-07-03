package com.rmf.rdvp.shared.system;

import java.time.Instant;
import java.util.Arrays;

import org.springframework.boot.availability.ApplicationAvailability;
import org.springframework.boot.availability.ReadinessState;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.config.RdvpRuntimeProperties;

@RestController
public class SystemHealthController {

    private final RdvpRuntimeProperties runtimeProperties;
    private final ApplicationAvailability availability;
    private final Environment environment;
    private final Instant startedAt;

    public SystemHealthController(
            RdvpRuntimeProperties runtimeProperties,
            ApplicationAvailability availability,
            Environment environment) {
        this.runtimeProperties = runtimeProperties;
        this.availability = availability;
        this.environment = environment;
        this.startedAt = Instant.now();
    }

    @GetMapping("/healthz")
    public SystemHealthResponse health() {
        return createResponse("ok");
    }

    @GetMapping("/readyz")
    public ResponseEntity<SystemHealthResponse> readiness() {
        boolean ready = availability.getReadinessState() == ReadinessState.ACCEPTING_TRAFFIC;
        HttpStatus status = ready ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;
        return ResponseEntity.status(status).body(createResponse(ready ? "ready" : "not_ready"));
    }

    private SystemHealthResponse createResponse(String status) {
        return new SystemHealthResponse(
                status,
                runtimeProperties.getService().getName(),
                runtimeProperties.getService().getVersion(),
                activeEnvironment(),
                startedAt);
    }

    private String activeEnvironment() {
        String[] activeProfiles = environment.getActiveProfiles();
        if (activeProfiles.length == 0) {
            return "default";
        }

        return String.join(",", Arrays.stream(activeProfiles).sorted().toList());
    }
}
