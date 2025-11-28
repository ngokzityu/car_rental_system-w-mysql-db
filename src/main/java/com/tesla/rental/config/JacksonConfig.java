package com.tesla.rental.config;

import com.fasterxml.jackson.databind.Module;
import com.fasterxml.jackson.databind.module.SimpleModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.LocalDateTime;
import com.tesla.rental.entity.LocalDateTimeDeserializer;

@Configuration
public class JacksonConfig {

    @Bean
    public Module localDateTimeModule() {
        SimpleModule module = new SimpleModule();
        module.addDeserializer(LocalDateTime.class, new LocalDateTimeDeserializer());
        return module;
    }
}
