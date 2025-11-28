package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "sys_user")
@Data
public class SysUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long userId;

    @Column(unique = true, nullable = false)
    private String username;       // 用户名
    
    private String passwordHash;   // 密码哈希
    
    @Column(name = "store_id")
    private Long storeId;          // 所属门店
}
