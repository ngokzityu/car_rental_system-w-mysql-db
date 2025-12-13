package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.FaultStatus;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class FaultStatusConverter implements AttributeConverter<FaultStatus, String> {
    @Override
    public String convertToDatabaseColumn(FaultStatus attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public FaultStatus convertToEntityAttribute(String dbData) {
        return FaultStatus.from(dbData);
    }
}
