package com.tesla.rental.controller;

import com.tesla.rental.entity.Maintenance;
import com.tesla.rental.repository.MaintenanceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/maintenance")
@CrossOrigin(origins = "*")
public class MaintenanceController {

    @Autowired
    private MaintenanceRepository maintenanceRepository;

    @GetMapping
    public List<Maintenance> getAllMaintenance() {
        return maintenanceRepository.findAll();
    }

    @PostMapping
    public Maintenance addMaintenance(@RequestBody Maintenance maintenance) {
        return maintenanceRepository.save(maintenance);
    }

    @GetMapping("/{id}")
    public Maintenance getMaintenanceById(@PathVariable Long id) {
        return maintenanceRepository.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Maintenance updateMaintenance(@PathVariable Long id, @RequestBody Maintenance maintenance) {
        maintenance.setMaintId(id);
        return maintenanceRepository.save(maintenance);
    }

    @DeleteMapping("/{id}")
    public void deleteMaintenance(@PathVariable Long id) {
        maintenanceRepository.deleteById(id);
    }
}
