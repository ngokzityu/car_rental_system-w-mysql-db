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

    @Autowired
    private com.tesla.rental.repository.BrandRepository brandRepository;

    @Autowired
    private com.tesla.rental.repository.StoreRepository storeRepository;

    // 6. 批量生成随机车辆（用于测试）
    @PostMapping("/generate")
    public List<Vehicle> generateVehicles(@RequestParam(defaultValue = "10") int count) {
        // 0. 确保已存在品牌数据
        Long brandId;
        if (brandRepository.count() == 0) {
            com.tesla.rental.entity.Brand brand = new com.tesla.rental.entity.Brand();
            brand.setName("Tesla");
            brand = brandRepository.save(brand);
            brandId = brand.getBrandId();
        } else {
            brandId = brandRepository.findAll().get(0).getBrandId();
        }

        // 1. 确保已存在车型数据（10种 Tesla 车型）
        if (carModelRepository.count() == 0) {
            // 定义车型信息：名称、座位数、电池容量
            Object[][] modelData = {
                    { "Model 3 标准续航版", 5, 60.0 },
                    { "Model 3 长续航版", 5, 82.0 },
                    { "Model 3 高性能版", 5, 82.0 },
                    { "Model Y 长续航版", 5, 75.0 },
                    { "Model Y 高性能版", 5, 75.0 },
                    { "Model S 长续航版", 5, 100.0 },
                    { "Model S Plaid", 5, 100.0 },
                    { "Model X 长续航版", 6, 100.0 },
                    { "Model X Plaid", 6, 100.0 },
                    { "Cybertruck 全轮驱动版", 5, 123.0 }
            };
            for (Object[] data : modelData) {
                com.tesla.rental.entity.CarModel m = new com.tesla.rental.entity.CarModel();
                m.setName((String) data[0]);
                m.setSeatCount((Integer) data[1]);
                m.setBatteryCapacity((Double) data[2]);
                m.setBrandId(brandId); // 使用实际的 Brand ID
                carModelRepository.save(m);
            }
        }
        List<com.tesla.rental.entity.CarModel> models = carModelRepository.findAll();

        // 2. 确保已存在门店数据
        if (storeRepository.count() == 0) {
            com.tesla.rental.entity.Store s = new com.tesla.rental.entity.Store();
            s.setName("Tesla Center Shanghai");
            s.setAddress("Shanghai, China");
            storeRepository.save(s);
        }
        List<com.tesla.rental.entity.Store> stores = storeRepository.findAll();

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
            }

            // 从已有门店中随机选择
            if (!stores.isEmpty()) {
                v.setStoreId(stores.get(random.nextInt(stores.size())).getStoreId());
            }

            // 只有在有有效 ModelId 和 StoreId 时才添加，避免外键错误（虽然上面逻辑保证了会有数据）
            if (v.getModelId() != null && v.getStoreId() != null) {
                vehicles.add(v);
            }
        }
        return vehicleRepository.saveAll(vehicles);
    }
}
