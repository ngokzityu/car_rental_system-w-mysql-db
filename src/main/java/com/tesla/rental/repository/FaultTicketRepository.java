package com.tesla.rental.repository;

import com.tesla.rental.entity.FaultTicket;
import com.tesla.rental.entity.enums.FaultStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface FaultTicketRepository extends JpaRepository<FaultTicket, Long> {
    Optional<FaultTicket> findFirstByOrderIdAndStatus(Long orderId, FaultStatus status);
}
