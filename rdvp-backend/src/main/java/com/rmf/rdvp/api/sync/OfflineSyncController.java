package com.rmf.rdvp.api.sync;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.sync.OfflineSyncRecordInput;
import com.rmf.rdvp.sync.OfflineSyncRecordType;
import com.rmf.rdvp.sync.OfflineSyncService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/sync")
public class OfflineSyncController {

    private final OfflineSyncService offlineSyncService;

    public OfflineSyncController(OfflineSyncService offlineSyncService) {
        this.offlineSyncService = offlineSyncService;
    }

    @PostMapping("/offline-records")
    public ResponseEntity<ApiResponse<OfflineSyncBatchResponse>> synchronize(
            @Valid @RequestBody OfflineSyncBatchRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = offlineSyncService.synchronize(
                requestBody.clientBatchId(),
                requestBody.records()
                        .stream()
                        .map(item -> new OfflineSyncRecordInput(
                                item.clientRecordId(),
                                OfflineSyncRecordType.parse(item.recordType()),
                                item.payload(),
                                item.createdOfflineAt()))
                        .toList(),
                user);
        return ResponseEntity.ok(ApiResponse.success(OfflineSyncBatchResponse.from(result), RequestIds.resolve(request)));
    }
}
