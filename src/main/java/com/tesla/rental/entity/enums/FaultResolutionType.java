package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum FaultResolutionType {
    ON_SITE_REPAIR(0, "现场维修"),
    VEHICLE_SWAP(1, "更换车辆");

    private final int code;
    private final String label;

    FaultResolutionType(int code, String label) {
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
    public static FaultResolutionType from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (FaultResolutionType type : values()) {
            if (String.valueOf(type.code).equals(text)
                    || type.label.equals(text)
                    || type.name().equalsIgnoreCase(text)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown fault resolution type: " + value);
    }
}
