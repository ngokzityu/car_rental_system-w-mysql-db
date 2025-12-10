package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.RentalOrderStatus;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class RentalOrderStatusConverter implements AttributeConverter<RentalOrderStatus, String> {
    @Override
    public String convertToDatabaseColumn(RentalOrderStatus attribute) {
        // Store as Stringified code ("0", "1") to be compatible with VARCHAR column
        // but numerically correct in content.
        return attribute != null ? String.valueOf(attribute.getCode()) : null;
    }

    @Override
    public RentalOrderStatus convertToEntityAttribute(String dbData) {
        // Handles "0", "1", "已支付", "PAID" etc via from()
        return RentalOrderStatus.from(dbData);
    }
}
