package com.tesla.rental.controller;

import com.tesla.rental.entity.Violation;
import com.tesla.rental.repository.ViolationRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/violations")
@CrossOrigin(origins = "*")
public class ViolationController {

    @Autowired
    private ViolationRepository violationRepository;

    @GetMapping
    public List<Violation> getAllViolations() {
        return violationRepository.findAll();
    }

    @PostMapping
    public Violation addViolation(@RequestBody Violation violation) {
        return violationRepository.save(violation);
    }

    @GetMapping("/{id}")
    public Violation getViolationById(@PathVariable Long id) {
        return violationRepository.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Violation updateViolation(@PathVariable Long id, @RequestBody Violation violation) {
        violation.setVioId(id);
        return violationRepository.save(violation);
    }

    @DeleteMapping("/{id}")
    public void deleteViolation(@PathVariable Long id) {
        violationRepository.deleteById(id);
    }
}
