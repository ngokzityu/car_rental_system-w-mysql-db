package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum RentalOrderStatus {
    PAID(0, "已支付"),
    RENTED(1, "使用中"),
    PENDING_INSPECTION(2, "待验车"),
    COMPLETED(3, "已完成");

    private final int code;
    private final String label;

    RentalOrderStatus(int code, String label) {
        this.code = code;
        this.label = label;
    }

    public int getCode() {
        return code;
    }

    @JsonValue
    public String getLabel() {
        return label;
    }

    @JsonCreator
    public static RentalOrderStatus from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (RentalOrderStatus status : values()) {
            if (String.valueOf(status.code).equals(text)
                    || status.label.equals(text)
                    || status.name().equalsIgnoreCase(text)) {
                return status;
            }
        }
        if ("active".equalsIgnoreCase(text) || "renting".equalsIgnoreCase(text)) {
            return RENTED;
        }
        throw new IllegalArgumentException("Unknown order status: " + value);
    }
}
