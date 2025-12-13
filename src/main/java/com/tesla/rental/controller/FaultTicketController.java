package com.tesla.rental.controller;

import com.tesla.rental.dto.FaultReportRequest;
import com.tesla.rental.dto.FaultResolveRequest;
import com.tesla.rental.entity.FaultTicket;
import com.tesla.rental.entity.RentalOrder;
import com.tesla.rental.entity.Vehicle;
import com.tesla.rental.entity.enums.FaultResolutionType;
import com.tesla.rental.entity.enums.FaultStatus;
import com.tesla.rental.entity.enums.RentalOrderStatus;
import com.tesla.rental.entity.enums.VehicleStatus;
import com.tesla.rental.repository.FaultTicketRepository;
import com.tesla.rental.repository.RentalOrderRepository;
import com.tesla.rental.repository.VehicleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/faults")
@CrossOrigin(origins = "*")
public class FaultTicketController {

    @Autowired
    private FaultTicketRepository faultTicketRepository;

    @Autowired
    private RentalOrderRepository orderRepository;

    @Autowired
    private VehicleRepository vehicleRepository;

    @GetMapping
    public List<FaultTicket> getAll() {
        return faultTicketRepository.findAll(Sort.by(Sort.Direction.DESC, "reportedTime"));
    }

    @GetMapping("/{id}")
    public FaultTicket getById(@PathVariable Long id) {
        return faultTicketRepository.findById(id).orElse(null);
    }

    /**
     * 顾客报故障，生成待解决工单
     */
    @PostMapping
    public FaultTicket reportFault(@RequestBody FaultReportRequest request) {
        if (request.getOrderId() == null) {
            throw new RuntimeException("orderId 不能为空");
        }
        RentalOrder order = orderRepository.findById(request.getOrderId())
                .orElseThrow(() -> new RuntimeException("订单不存在"));

        if (order.getStatus() != RentalOrderStatus.RENTED
                && order.getStatus() != RentalOrderStatus.PENDING_INSPECTION) {
            throw new RuntimeException("仅在租或待验车订单可报故障");
        }

        faultTicketRepository.findFirstByOrderIdAndStatus(order.getOrderId(), FaultStatus.PENDING)
                .ifPresent(t -> {
                    throw new RuntimeException("该订单已有待解决的故障工单");
                });

        Long orderVehicleId = order.getCurrentVehicleId() != null ? order.getCurrentVehicleId() : order.getVehicleId();
        Long vehicleId = request.getVehicleId() != null ? request.getVehicleId() : orderVehicleId;
        // 允许传入订单原始车辆或当前车辆
        if (vehicleId != null && !(vehicleId.equals(orderVehicleId) || vehicleId.equals(order.getVehicleId()))) {
            throw new RuntimeException("报障车辆与订单车辆不一致");
        }
        if (request.getCustomerId() != null && !request.getCustomerId().equals(order.getCustomerId())) {
            throw new RuntimeException("报障客户与订单客户不一致");
        }

        FaultTicket ticket = new FaultTicket();
        ticket.setOrderId(order.getOrderId());
        ticket.setVehicleId(orderVehicleId);
        ticket.setCustomerId(order.getCustomerId());
        ticket.setDescription(request.getDescription());
        ticket.setStatus(FaultStatus.PENDING);
        ticket.setReportedTime(LocalDateTime.now());

        // 报障后立即将车辆标记为维保，避免继续外租
        if (orderVehicleId != null) {
            vehicleRepository.findById(orderVehicleId).ifPresent(v -> {
                if (v.getStatus() != VehicleStatus.MAINTENANCE) {
                    v.setStatus(VehicleStatus.MAINTENANCE);
                    vehicleRepository.save(v);
                }
            });
        }
        return faultTicketRepository.save(ticket);
    }

    /**
     * 员工处理故障：现场维修或更换车辆
     */
    @PutMapping("/{ticketId}/resolve")
    @Transactional
    public FaultTicket resolve(@PathVariable Long ticketId, @RequestBody FaultResolveRequest request) {
        FaultTicket ticket = faultTicketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("工单不存在"));

        if (ticket.getStatus() != FaultStatus.PENDING) {
            throw new RuntimeException("工单已处理或状态异常");
        }
        if (request.getResolutionType() == null) {
            throw new RuntimeException("处理方案不能为空");
        }

        RentalOrder order = orderRepository.findById(ticket.getOrderId())
                .orElseThrow(() -> new RuntimeException("关联订单不存在"));

        if (order.getStatus() == RentalOrderStatus.COMPLETED) {
            throw new RuntimeException("已完成订单不可处理故障");
        }

        if (request.getResolutionType() == FaultResolutionType.VEHICLE_SWAP) {
            handleVehicleSwap(order, ticket, request);
        } else {
            // 现场维修：保持订单车辆不变，恢复车辆状态为在租
            Long currentVehicleId = order.getCurrentVehicleId() != null ? order.getCurrentVehicleId() : order.getVehicleId();
            if (currentVehicleId != null) {
                vehicleRepository.findById(currentVehicleId).ifPresent(v -> {
                    v.setStatus(VehicleStatus.RENTED);
                    vehicleRepository.save(v);
                });
            }
            ticket.setResolutionType(FaultResolutionType.ON_SITE_REPAIR);
        }

        ticket.setStatus(FaultStatus.RESOLVED);
        ticket.setHandledBy(request.getHandledBy());
        ticket.setRemark(request.getRemark());
        ticket.setResolvedTime(LocalDateTime.now());

        return faultTicketRepository.save(ticket);
    }

    private void handleVehicleSwap(RentalOrder order, FaultTicket ticket, FaultResolveRequest request) {
        if (request.getNewVehicleId() == null) {
            throw new RuntimeException("更换车辆时 newVehicleId 不能为空");
        }
        if (ticket.getVehicleId() != null && ticket.getVehicleId().equals(request.getNewVehicleId())) {
            throw new RuntimeException("新车不能与故障车辆相同");
        }

        Vehicle newVehicle = vehicleRepository.findById(request.getNewVehicleId())
                .orElseThrow(() -> new RuntimeException("新车辆不存在"));
        if (newVehicle.getStatus() != VehicleStatus.IN_STOCK) {
            throw new RuntimeException("新车辆必须处于在库状态");
        }

        // 更新订单当前车辆为新车，保持原始车辆ID不变
        order.setCurrentVehicleId(newVehicle.getVehicleId());
        orderRepository.save(order);

        // 新车置为在租
        newVehicle.setStatus(VehicleStatus.RENTED);
        vehicleRepository.save(newVehicle);

        // 故障车置为维修中
        Optional<Vehicle> oldVehicleOpt = ticket.getVehicleId() != null
                ? vehicleRepository.findById(ticket.getVehicleId()) : Optional.empty();
        oldVehicleOpt.ifPresent(v -> {
            v.setStatus(VehicleStatus.MAINTENANCE);
            vehicleRepository.save(v);
        });

        ticket.setNewVehicleId(newVehicle.getVehicleId());
        ticket.setResolutionType(FaultResolutionType.VEHICLE_SWAP);
    }
}
