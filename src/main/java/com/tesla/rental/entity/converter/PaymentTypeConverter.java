package com.tesla.rental.entity.converter;

import com.tesla.rental.entity.enums.PaymentType;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = false)
public class PaymentTypeConverter implements AttributeConverter<PaymentType, String> {

    @Override
    public String convertToDatabaseColumn(PaymentType attribute) {
        return attribute != null ? attribute.getLabel() : null;
    }

    @Override
    public PaymentType convertToEntityAttribute(String dbData) {
        return PaymentType.from(dbData);
    }
}
