package com.tesla.rental.dto;

import lombok.Data;

@Data
public class FaultReportRequest {
    private Long orderId;
    private Long vehicleId;
    private Long customerId;
    private String description;
}
