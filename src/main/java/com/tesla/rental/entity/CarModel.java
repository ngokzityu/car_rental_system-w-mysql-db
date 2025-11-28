package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "car_model")
@Data
public class CarModel {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long modelId;
    
    private String name;              // 型号名称 (Model 3/Y)
    private Integer seatCount;        // 座位数
    private Double batteryCapacity;   // 电池容量
    
    @Column(name = "brand_id")
    private Long brandId;             // 关联品牌
}
