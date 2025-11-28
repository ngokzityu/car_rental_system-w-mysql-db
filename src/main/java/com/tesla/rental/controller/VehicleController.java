package com.tesla.rental.controller;

import com.tesla.rental.entity.Vehicle;
import com.tesla.rental.entity.enums.VehicleStatus;
import com.tesla.rental.repository.VehicleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/vehicles") // 前端访问的接口地址
@CrossOrigin(origins = "*") // 允许前端网页跨域访问（这一行非常重要）
public class VehicleController {

    @Autowired
    private VehicleRepository vehicleRepository;

    // 1. 查询所有车辆接口
    @GetMapping
    public List<Vehicle> getAllVehicles() {
        return vehicleRepository.findAll();
    }

    // 2. 添加一辆新车接口
    @PostMapping
    public Vehicle addVehicle(@RequestBody Vehicle vehicle) {
        return vehicleRepository.save(vehicle);
    }

    // 3. 根据ID查询车辆
    @GetMapping("/{id}")
    public Vehicle getVehicleById(@PathVariable Long id) {
        return vehicleRepository.findById(id).orElse(null);
    }

    // 4. 更新车辆信息
    @PutMapping("/{id}")
    public Vehicle updateVehicle(@PathVariable Long id, @RequestBody Vehicle vehicle) {
        vehicle.setVehicleId(id);
        return vehicleRepository.save(vehicle);
    }

    // 5. 删除车辆
    @DeleteMapping("/{id}")
    public void deleteVehicle(@PathVariable Long id) {
        vehicleRepository.deleteById(id);
    }

    @Autowired
    private com.tesla.rental.repository.CarModelRepository carModelRepository;

    // 6. 批量生成随机车辆（用于测试）
    @PostMapping("/generate")
    public List<Vehicle> generateVehicles(@RequestParam(defaultValue = "10") int count) {
        // 确保已存在车型数据
        if (carModelRepository.count() == 0) {
            String[] modelNames = { "Model 3", "Model Y", "Model S", "Model X", "Cybertruck" };
            for (String name : modelNames) {
                com.tesla.rental.entity.CarModel m = new com.tesla.rental.entity.CarModel();
                m.setName(name);
                m.setSeatCount(5); // 默认值
                m.setBatteryCapacity(75.0); // 默认值
                m.setBrandId(1L); // 特斯拉
                carModelRepository.save(m);
            }
        }
        List<com.tesla.rental.entity.CarModel> models = carModelRepository.findAll();

        List<Vehicle> vehicles = new java.util.ArrayList<>();
        java.util.Random random = new java.util.Random();
        String[] provinces = { "京", "沪", "粤", "浙", "苏", "湘", "鄂", "川", "渝" };
        String[] letters = { "A", "B", "C", "D", "E", "F", "D", "F" }; // D/F 表示新能源车牌

        for (int i = 0; i < count; i++) {
            Vehicle v = new Vehicle();

            // 随机生成车牌号
            String province = provinces[random.nextInt(provinces.length)];
            String letter = letters[random.nextInt(letters.length)];
            StringBuilder sb = new StringBuilder();
            for (int j = 0; j < 5; j++) {
                sb.append(random.nextInt(10));
            }
            v.setPlateNo(province + letter + sb.toString());

            // 随机电量和里程值
            v.setCurrentSoc((double) random.nextInt(101)); // 0-100 范围
            v.setCurrentMileage((double) random.nextInt(10000));

            v.setStatus(VehicleStatus.IN_STOCK);

            // 从已有车型中随机选择
            if (!models.isEmpty()) {
                v.setModelId(models.get(random.nextInt(models.size())).getModelId());
            } else {
                v.setModelId(1L); // 兜底值
            }

            v.setStoreId((long) (random.nextInt(5) + 1));

            vehicles.add(v);
        }
        return vehicleRepository.saveAll(vehicles);
    }
}
