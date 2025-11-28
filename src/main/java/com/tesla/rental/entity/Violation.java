package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;

@Entity
@Table(name = "violation")
@Data
public class Violation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long vioId;

    private BigDecimal fineAmount;  // 罚款金额
    private String location;        // 违章位置
    
    @Column(name = "vehicle_id")
    private Long vehicleId;         // 关联车辆
    
    @Column(name = "order_id")
    private Long orderId;           // 关联订单
}
