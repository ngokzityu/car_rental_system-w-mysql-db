package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "customer")
@Data
public class Customer {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long customerId;

    private String name;              // 姓名
    
    @Column(unique = true, nullable = false)
    private String phone;             // 电话(Unique)
    
    private String idCard;            // 身份证
    private String driverLicense;     // 驾照号
}
