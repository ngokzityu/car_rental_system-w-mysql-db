package com.tesla.rental.entity.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum PaymentType {
    DEPOSIT(0, "押金"),
    RENTAL_FEE(1, "租金"),
    COMPENSATION(2, "赔偿");

    private final int code;
    private final String label;

    PaymentType(int code, String label) {
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
    public static PaymentType from(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        for (PaymentType type : values()) {
            if (String.valueOf(type.code).equals(text)
                    || type.label.equals(text)
                    || type.name().equalsIgnoreCase(text)) {
                return type;
            }
        }
        if ("deposit".equalsIgnoreCase(text)) {
            return DEPOSIT;
        }
        if ("rent".equalsIgnoreCase(text) || "rental".equalsIgnoreCase(text)) {
            return RENTAL_FEE;
        }
        if ("penalty".equalsIgnoreCase(text) || "fine".equalsIgnoreCase(text)) {
            return COMPENSATION;
        }
        throw new IllegalArgumentException("Unknown payment type: " + value);
    }
}
