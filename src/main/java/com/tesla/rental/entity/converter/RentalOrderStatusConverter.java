package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.RentalOrderStatus;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class RentalOrderStatusConverter implements AttributeConverter<RentalOrderStatus, String> {
    @Override
    public String convertToDatabaseColumn(RentalOrderStatus attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public RentalOrderStatus convertToEntityAttribute(String dbData) {
        return RentalOrderStatus.from(dbData);
    }
}
