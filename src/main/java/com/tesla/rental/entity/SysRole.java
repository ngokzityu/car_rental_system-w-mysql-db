package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "sys_role")
@Data
public class SysRole {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long roleId;

    private String roleName;       // 角色名：管理员/店员
}
