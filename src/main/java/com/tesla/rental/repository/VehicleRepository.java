package com.tesla.rental.repository;

import com.tesla.rental.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VehicleRepository extends JpaRepository<Vehicle, Long> {
    // 这里其实有一对大括号，虽然里面是空的
}