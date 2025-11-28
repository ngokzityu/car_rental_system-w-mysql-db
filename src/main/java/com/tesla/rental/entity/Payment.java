package com.tesla.rental.entity;

import com.tesla.rental.entity.converter.PaymentTypeConverter;
import com.tesla.rental.entity.enums.PaymentType;
import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;

@Entity
@Table(name = "payment")
@Data
public class Payment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long payId;

    private BigDecimal amount; // 金额

    @Column(name = "type")
    @Convert(converter = PaymentTypeConverter.class)
    private PaymentType type;   // 类型：押金/租金/赔偿
    
    @Column(name = "order_id")
    private Long orderId;      // 关联订单
}
