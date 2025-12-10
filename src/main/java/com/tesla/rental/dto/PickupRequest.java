package com.tesla.rental.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.tesla.rental.entity.LocalDateTimeDeserializer;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class PickupRequest {
    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime actualPickupTime;

    private Integer pickupMileage;
    private Double actualPickupSoc;
}
