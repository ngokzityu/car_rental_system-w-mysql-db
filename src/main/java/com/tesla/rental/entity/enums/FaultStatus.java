package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum FaultStatus {
    PENDING(0, "待解决"),
    RESOLVED(1, "已解决");

    private final int code;
    private final String label;

    FaultStatus(int code, String label) {
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
    public static FaultStatus from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (FaultStatus status : values()) {
            if (String.valueOf(status.code).equals(text)
                    || status.label.equals(text)
                    || status.name().equalsIgnoreCase(text)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Unknown fault status: " + value);
    }
}
