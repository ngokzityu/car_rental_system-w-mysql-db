package com.tesla.rental.controller;

import com.tesla.rental.entity.RentalOrder;
import com.tesla.rental.entity.Vehicle;
import com.tesla.rental.entity.enums.RentalOrderStatus;
import com.tesla.rental.entity.enums.VehicleStatus;
import com.tesla.rental.repository.RentalOrderRepository;
import com.tesla.rental.repository.VehicleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.data.domain.Sort;

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
        return orderRepository.findAll(Sort.by(Sort.Direction.DESC, "orderId"));
    }

    @PostMapping
    public RentalOrder addOrder(@RequestBody RentalOrder order) {
        if (order.getStatus() == null) {
            order.setStatus(RentalOrderStatus.PAID);
        }
        // 初始化当前用车ID，保持原始车辆ID不可变
        if (order.getCurrentVehicleId() == null) {
            order.setCurrentVehicleId(order.getVehicleId());
        }
        // 保存订单
        RentalOrder savedOrder = orderRepository.save(order);

        // 更新车辆状态为"在租"
        Long vehicleIdToRent = order.getCurrentVehicleId() != null ? order.getCurrentVehicleId() : order.getVehicleId();
        if (vehicleIdToRent != null) {
            Optional<Vehicle> vehicleOpt = vehicleRepository.findById(vehicleIdToRent);
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

    // ========== 租车闭环功能 ==========

    /**
     * 确认取车
     */
    @PutMapping("/{orderId}/pickup")
    public RentalOrder confirmPickup(
            @PathVariable Long orderId,
            @RequestBody com.tesla.rental.dto.PickupRequest request) {

        RentalOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("订单不存在"));

        // 验证订单状态
        if (order.getStatus() != RentalOrderStatus.PAID) {
            throw new RuntimeException("订单状态不正确，当前状态：" + order.getStatus().getLabel());
        }

        // 更新订单状态和取车信息
        order.setStatus(RentalOrderStatus.RENTED);
        order.setActualPickupTime(request.getActualPickupTime());
        order.setPickupMileage(request.getPickupMileage());
        order.setActualPickupSoc(request.getActualPickupSoc());

        return orderRepository.save(order);
    }

    /**
     * 申请还车
     */
    @PutMapping("/{orderId}/apply-return")
    public RentalOrder applyReturn(
            @PathVariable Long orderId,
            @RequestBody(required = false) com.tesla.rental.dto.ReturnApplicationRequest request) {

        RentalOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("订单不存在"));

        // 验证订单状态
        if (order.getStatus() != RentalOrderStatus.RENTED) {
            throw new RuntimeException("订单状态不正确，当前状态：" + order.getStatus().getLabel());
        }

        // 更新订单状态
        order.setStatus(RentalOrderStatus.PENDING_INSPECTION);

        // 如果用户指定了还车门店，更新还车门店
        if (request != null && request.getReturnStoreId() != null) {
            order.setReturnStoreId(request.getReturnStoreId());
        }

        return orderRepository.save(order);
    }

    /**
     * 确认还车（验车通过）
     */
    @PutMapping("/{orderId}/confirm-return")
    @Transactional
    public RentalOrder confirmReturn(
            @PathVariable Long orderId,
            @RequestBody com.tesla.rental.dto.ReturnConfirmationRequest request) {

        RentalOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("订单不存在"));

        // 验证订单状态
        if (order.getStatus() != RentalOrderStatus.PENDING_INSPECTION) {
            throw new RuntimeException("订单状态不正确，当前状态：" + order.getStatus().getLabel());
        }

        // 验证还车里程必须大于等于取车里程
        if (request.getReturnMileage() != null && order.getPickupMileage() != null) {
            if (request.getReturnMileage() < order.getPickupMileage()) {
                throw new RuntimeException("还车里程不能小于取车里程");
            }
        }

        // 更新订单状态和还车信息
        order.setStatus(RentalOrderStatus.COMPLETED);
        order.setActualReturnTime(request.getActualReturnTime());
        order.setReturnMileage(request.getReturnMileage());
        order.setActualReturnSoc(request.getActualReturnSoc());

        RentalOrder savedOrder = orderRepository.save(order);

        // 【关键】释放车辆：更新车辆状态为"在库"，并更新车辆当前里程和电量
        Long vehicleIdToRelease = order.getCurrentVehicleId() != null ? order.getCurrentVehicleId() : order.getVehicleId();
        if (vehicleIdToRelease != null) {
            Optional<Vehicle> vehicleOpt = vehicleRepository.findById(vehicleIdToRelease);
            if (vehicleOpt.isPresent()) {
                Vehicle vehicle = vehicleOpt.get();
                vehicle.setStatus(VehicleStatus.IN_STOCK); // 0=在库

                // 更新车辆当前里程和电量
                if (request.getReturnMileage() != null) {
                    vehicle.setCurrentMileage(request.getReturnMileage().doubleValue());
                }
                if (request.getActualReturnSoc() != null) {
                    vehicle.setCurrentSoc(request.getActualReturnSoc());
                }

                vehicleRepository.save(vehicle);
            }
        }

        return savedOrder;
    }
}
