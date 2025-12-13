package com.tesla.rental.dto;

import com.tesla.rental.entity.enums.FaultResolutionType;
import lombok.Data;

@Data
public class FaultResolveRequest {
    private FaultResolutionType resolutionType;
    private String handledBy;
    private String remark;
    private Long newVehicleId;
}
