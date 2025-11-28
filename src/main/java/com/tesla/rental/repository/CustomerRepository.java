package com.tesla.rental.repository;

import com.tesla.rental.entity.Customer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CustomerRepository extends JpaRepository<Customer, Long> {
	java.util.Optional<Customer> findByPhone(String phone);
}
