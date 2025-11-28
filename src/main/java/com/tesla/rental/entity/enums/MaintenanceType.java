package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum MaintenanceType {
    ROUTINE(0, "保养"),
    REPAIR(1, "维修"),
    OTHER(2, "其他");

    private final int code;
    private final String label;

    MaintenanceType(int code, String label) {
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
    public static MaintenanceType from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (MaintenanceType type : values()) {
            if (String.valueOf(type.code).equals(text)
                    || type.label.equals(text)
                    || type.name().equalsIgnoreCase(text)) {
                return type;
            }
        }
        if ("保养".equalsIgnoreCase(text)) {
            return ROUTINE;
        }
        if ("维修".equalsIgnoreCase(text)) {
            return REPAIR;
        }
        return OTHER;
    }
}
