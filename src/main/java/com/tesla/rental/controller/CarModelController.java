package com.tesla.rental.controller;

import com.tesla.rental.entity.CarModel;
import com.tesla.rental.repository.CarModelRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/models")
@CrossOrigin(origins = "*")
public class CarModelController {

    @Autowired
    private CarModelRepository carModelRepository;

    // 获取所有车型
    @GetMapping
    public List<CarModel> getAllModels() {
        return carModelRepository.findAll();
    }

    // 添加新车型
    @PostMapping
    public CarModel addModel(@RequestBody CarModel model) {
        return carModelRepository.save(model);
    }

    // 获取单个车型
    @GetMapping("/{id}")
    public CarModel getModelById(@PathVariable Long id) {
        return carModelRepository.findById(id).orElse(null);
    }

    // 删除车型
    @DeleteMapping("/{id}")
    public void deleteModel(@PathVariable Long id) {
        carModelRepository.deleteById(id);
    }
}
