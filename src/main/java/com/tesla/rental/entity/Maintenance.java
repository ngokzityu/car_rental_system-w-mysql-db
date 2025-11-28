package com.tesla.rental.entity;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.tesla.rental.entity.converter.MaintenanceTypeConverter;
import com.tesla.rental.entity.enums.MaintenanceType;
import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "maintenance")
@Data
public class Maintenance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long maintId;

    @Column(name = "type")
    @Convert(converter = MaintenanceTypeConverter.class)
    private MaintenanceType type;    // 维保类型编码

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime maintDate; // 维保日期时间

    private String description;    // 描述
    
    @Column(name = "vehicle_id")
    private Long vehicleId;        // 关联车辆
}
