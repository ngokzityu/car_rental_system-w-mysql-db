package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "sys_user_role")
@Data
public class SysUserRole {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;           // 用户ID
    
    @Column(name = "role_id", nullable = false)
    private Long roleId;           // 角色ID
}
