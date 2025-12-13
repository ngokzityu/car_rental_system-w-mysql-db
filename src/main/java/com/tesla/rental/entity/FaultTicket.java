package com.tesla.rental.entity;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.tesla.rental.entity.converter.FaultResolutionTypeConverter;
import com.tesla.rental.entity.converter.FaultStatusConverter;
import com.tesla.rental.entity.enums.FaultResolutionType;
import com.tesla.rental.entity.enums.FaultStatus;
import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "fault_ticket")
@Data
public class FaultTicket {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long ticketId;

    @Column(name = "order_id")
    private Long orderId;

    @Column(name = "vehicle_id")
    private Long vehicleId;

    @Column(name = "customer_id")
    private Long customerId;

    private String description;

    @Column(name = "status")
    @Convert(converter = FaultStatusConverter.class)
    private FaultStatus status; // 待解决/已解决

    @Column(name = "resolution_type")
    @Convert(converter = FaultResolutionTypeConverter.class)
    private FaultResolutionType resolutionType; // 现场维修/更换车辆

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime reportedTime;

    private String handledBy;

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime resolvedTime;

    @Column(name = "new_vehicle_id")
    private Long newVehicleId; // 换车场景下的新车ID

    private String remark;
}
