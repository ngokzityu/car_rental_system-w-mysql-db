package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum VehicleStatus {
    IN_STOCK(0, "在库"),
    RENTED(1, "在租"),
    MAINTENANCE(2, "维保");

    private final int code;
    private final String label;

    VehicleStatus(int code, String label) {
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
    public static VehicleStatus from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (VehicleStatus status : values()) {
            if (String.valueOf(status.code).equals(text)
                    || status.label.equals(text)
                    || status.name().equalsIgnoreCase(text)) {
                return status;
            }
        }
        if ("available".equalsIgnoreCase(text)) {
            return IN_STOCK;
        }
        if ("active".equalsIgnoreCase(text) || "renting".equalsIgnoreCase(text)) {
            return RENTED;
        }
        if ("maintenance".equalsIgnoreCase(text)) {
            return MAINTENANCE;
        }
        throw new IllegalArgumentException("Unknown vehicle status: " + value);
    }
}
