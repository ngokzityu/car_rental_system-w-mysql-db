package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "audit_log")
@Data
public class AuditLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long logId;

    private String action;          // 操作内容
    private LocalDateTime actionTime; // 操作时间
    private String ipAddress;       // IP地址
    
    @Column(name = "user_id")
    private Long userId;            // 操作用户
}
