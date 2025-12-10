package com.tesla.rental.dto;

import lombok.Data;

@Data
public class ReturnApplicationRequest {
    private Long returnStoreId; // 可选：用户指定还车门店
}
