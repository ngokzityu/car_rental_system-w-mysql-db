package com.tesla.rental.controller;

import com.tesla.rental.entity.Customer;
import com.tesla.rental.repository.CustomerRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customers")
@CrossOrigin(origins = "*")
public class CustomerController {

    @Autowired
    private CustomerRepository customerRepository;

    @GetMapping
    public List<Customer> getAllCustomers() {
        return customerRepository.findAll();
    }

    @PostMapping
    public Customer addCustomer(@RequestBody Customer customer) {
        // 如果提供了手机号，则按手机号查找并更新已有客户（相当于按手机号 upsert）
        if (customer.getPhone() != null && !customer.getPhone().isEmpty()) {
            java.util.Optional<Customer> existing = customerRepository.findByPhone(customer.getPhone());
            if (existing.isPresent()) {
                Customer exist = existing.get();
                // 如果传入对应字段就更新其值
                if (customer.getName() != null) exist.setName(customer.getName());
                if (customer.getIdCard() != null) exist.setIdCard(customer.getIdCard());
                if (customer.getDriverLicense() != null) exist.setDriverLicense(customer.getDriverLicense());
                return customerRepository.save(exist);
            }
        }
        return customerRepository.save(customer);
    }

    @GetMapping("/{id}")
    public Customer getCustomerById(@PathVariable Long id) {
        return customerRepository.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Customer updateCustomer(@PathVariable Long id, @RequestBody Customer customer) {
        customer.setCustomerId(id);
        return customerRepository.save(customer);
    }

    @DeleteMapping("/{id}")
    public void deleteCustomer(@PathVariable Long id) {
        customerRepository.deleteById(id);
    }
}
