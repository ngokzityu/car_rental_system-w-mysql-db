package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.MaintenanceType;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class MaintenanceTypeConverter implements AttributeConverter<MaintenanceType, String> {
    @Override
    public String convertToDatabaseColumn(MaintenanceType attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public MaintenanceType convertToEntityAttribute(String dbData) {
        return MaintenanceType.from(dbData);
    }
}
