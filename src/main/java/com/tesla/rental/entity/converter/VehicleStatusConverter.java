package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.VehicleStatus;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class VehicleStatusConverter implements AttributeConverter<VehicleStatus, String> {

    @Override
    public String convertToDatabaseColumn(VehicleStatus attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public VehicleStatus convertToEntityAttribute(String dbData) {
        return VehicleStatus.from(dbData);
    }
}
