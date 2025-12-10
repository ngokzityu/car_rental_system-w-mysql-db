package com.tesla.rental.entity;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.tesla.rental.entity.converter.RentalOrderStatusConverter;
import com.tesla.rental.entity.enums.RentalOrderStatus;
import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "rental_order")
@Data
public class RentalOrder {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long orderId;

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime rentStart; // 计划取车时间

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime rentEnd; // 计划还车时间

    private Double pickupSoc; // 取车电量(%)
    private Double returnSoc; // 还车电量(%)
    private BigDecimal totalAmount; // 订单总额

    @Column(name = "status")
    @Convert(converter = RentalOrderStatusConverter.class)
    private RentalOrderStatus status; // 已支付/在租/已还/结算

    // 核心关联
    @Column(name = "customer_id")
    private Long customerId; // 客户ID

    @Column(name = "vehicle_id")
    private Long vehicleId; // 车辆ID

    @Column(name = "pickup_store_id")
    private Long pickupStoreId; // 取车门店

    @Column(name = "return_store_id")
    private Long returnStoreId; // 还车门店

    // 实际取还车信息
    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime actualPickupTime; // 实际取车时间

    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime actualReturnTime; // 实际还车时间

    private Integer pickupMileage; // 取车里程
    private Integer returnMileage; // 还车里程
    private Double actualPickupSoc; // 实际取车电量
    private Double actualReturnSoc; // 实际还车电量
}
