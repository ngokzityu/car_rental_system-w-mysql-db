package com.tesla.rental.config;

import com.tesla.rental.entity.Store;
import com.tesla.rental.repository.StoreRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DataInitializer {

    @Bean
    public CommandLineRunner initData(StoreRepository storeRepository) {
        return args -> {
            if (storeRepository.count() == 0) {
                Store store = new Store();
                store.setName("Tesla Center Shanghai");
                store.setAddress("Shanghai, China");
                storeRepository.save(store);
                System.out.println("Initialized default store: Tesla Center Shanghai");
            }
        };
    }
}
