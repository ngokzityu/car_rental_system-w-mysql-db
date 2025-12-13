package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.FaultResolutionType;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class FaultResolutionTypeConverter implements AttributeConverter<FaultResolutionType, String> {
    @Override
    public String convertToDatabaseColumn(FaultResolutionType attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public FaultResolutionType convertToEntityAttribute(String dbData) {
        return FaultResolutionType.from(dbData);
    }
}
