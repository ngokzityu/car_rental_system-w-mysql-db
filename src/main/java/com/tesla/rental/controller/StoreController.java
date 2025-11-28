package com.tesla.rental.controller;

import com.tesla.rental.entity.Store;
import com.tesla.rental.repository.StoreRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/stores")
@CrossOrigin(origins = "*")
public class StoreController {

    @Autowired
    private StoreRepository storeRepository;

    @GetMapping
    public List<Store> getAllStores() {
        return storeRepository.findAll();
    }

    @PostMapping
    public Store addStore(@RequestBody Store store) {
        return storeRepository.save(store);
    }

    @GetMapping("/{id}")
    public Store getStoreById(@PathVariable Long id) {
        return storeRepository.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Store updateStore(@PathVariable Long id, @RequestBody Store store) {
        store.setStoreId(id);
        return storeRepository.save(store);
    }

    @DeleteMapping("/{id}")
    public void deleteStore(@PathVariable Long id) {
        storeRepository.deleteById(id);
    }
}
