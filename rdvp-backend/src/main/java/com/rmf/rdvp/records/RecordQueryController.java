package com.rmf.rdvp.records;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1")
public class RecordQueryController {

    private final RecordQueryService recordQueryService;

    public RecordQueryController(RecordQueryService recordQueryService) {
        this.recordQueryService = recordQueryService;
    }

    @GetMapping("/operation-records")
    public ResponseEntity<ApiResponse<RecordListResponse>> queryOperationRecords(
            @RequestParam String category,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        var result = recordQueryService.queryRecords(category, type, keyword, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(result, RequestIds.resolve(request)));
    }
}
