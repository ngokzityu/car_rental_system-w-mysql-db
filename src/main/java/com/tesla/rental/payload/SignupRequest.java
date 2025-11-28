package com.tesla.rental.payload;

import lombok.Data;
import java.util.Set;

@Data
public class SignupRequest {
    private String username;
    private String password;
    private Long storeId;
    private Set<String> role;
}
