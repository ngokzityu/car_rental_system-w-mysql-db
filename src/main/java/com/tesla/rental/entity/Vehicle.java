package com.tesla.rental.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.tesla.rental.entity.converter.VehicleStatusConverter;
import com.tesla.rental.entity.enums.VehicleStatus;
import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "vehicle")
@Data
public class Vehicle {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long vehicleId;

    @Column(unique = true, nullable = false)
    private String plateNo; // 车牌(Unique)

    private Double currentSoc; // 当前电量%
    private Double currentMileage; // 当前里程

    @Column(name = "status")
    @Convert(converter = VehicleStatusConverter.class)
    private VehicleStatus status; // 0 在库 / 1 在租 / 2 维保

    @Column(name = "model_id", nullable = false)
    private Long modelId; // 关联车型

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "model_id", insertable = false, updatable = false)
    private CarModel carModel;

    @Column(name = "store_id")
    private Long storeId; // 当前停放门店

    // 为前端提供 carModelName 字段
    @JsonProperty("carModelName")
    public String getCarModelName() {
        return carModel != null ? carModel.getName() : null;
    }
}
