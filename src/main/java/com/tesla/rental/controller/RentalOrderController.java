package com.tesla.rental.controller;

import com.tesla.rental.entity.RentalOrder;
import com.tesla.rental.entity.Vehicle;
import com.tesla.rental.entity.enums.RentalOrderStatus;
import com.tesla.rental.entity.enums.VehicleStatus;
import com.tesla.rental.repository.RentalOrderRepository;
import com.tesla.rental.repository.VehicleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/orders")
@CrossOrigin(origins = "*")
public class RentalOrderController {

    @Autowired
    private RentalOrderRepository orderRepository;

    @Autowired
    private VehicleRepository vehicleRepository;

    @GetMapping
    public List<RentalOrder> getAllOrders() {
        return orderRepository.findAll();
    }

    @PostMapping
    public RentalOrder addOrder(@RequestBody RentalOrder order) {
        if (order.getStatus() == null) {
            order.setStatus(RentalOrderStatus.PAID);
        }
        // 保存订单
        RentalOrder savedOrder = orderRepository.save(order);

        // 更新车辆状态为"在租"
        if (order.getVehicleId() != null) {
            Optional<Vehicle> vehicleOpt = vehicleRepository.findById(order.getVehicleId());
            if (vehicleOpt.isPresent()) {
                Vehicle vehicle = vehicleOpt.get();
                vehicle.setStatus(VehicleStatus.RENTED);
                vehicleRepository.save(vehicle);
            }
        }

        return savedOrder;
    }

    @GetMapping("/{id}")
    public RentalOrder getOrderById(@PathVariable Long id) {
        return orderRepository.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public RentalOrder updateOrder(@PathVariable Long id, @RequestBody RentalOrder order) {
        order.setOrderId(id);
        return orderRepository.save(order);
    }

    @DeleteMapping("/{id}")
    public void deleteOrder(@PathVariable Long id) {
        orderRepository.deleteById(id);
    }
}
