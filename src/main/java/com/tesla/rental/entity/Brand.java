package com.tesla.rental.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "brand")
@Data
public class Brand {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long brandId;
    
    private String name; // 品牌名 (Tesla)
}
