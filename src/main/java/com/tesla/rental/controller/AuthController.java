package com.tesla.rental.controller;

import com.tesla.rental.entity.SysRole;
import com.tesla.rental.entity.SysUser;
import com.tesla.rental.entity.SysUserRole;
import com.tesla.rental.payload.JwtResponse;
import com.tesla.rental.payload.LoginRequest;
import com.tesla.rental.payload.MessageResponse;
import com.tesla.rental.payload.SignupRequest;
import com.tesla.rental.repository.SysRoleRepository;
import com.tesla.rental.repository.SysUserRepository;
import com.tesla.rental.repository.SysUserRoleRepository;
import com.tesla.rental.security.JwtUtils;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final SysUserRepository userRepository;
    private final SysRoleRepository roleRepository;
    private final SysUserRoleRepository userRoleRepository;
    private final PasswordEncoder encoder;
    private final JwtUtils jwtUtils;

    public AuthController(AuthenticationManager authenticationManager, SysUserRepository userRepository,
                          SysRoleRepository roleRepository, SysUserRoleRepository userRoleRepository,
                          PasswordEncoder encoder, JwtUtils jwtUtils) {
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.userRoleRepository = userRoleRepository;
        this.encoder = encoder;
        this.jwtUtils = jwtUtils;
    }

    @PostMapping("/signin")
    public ResponseEntity<?> authenticateUser(@RequestBody LoginRequest loginRequest) {

        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword()));

        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);

        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        List<String> roles = userDetails.getAuthorities().stream()
                .map(item -> item.getAuthority())
                .collect(Collectors.toList());
        
        // 获取用户 ID（UserDetails 默认不包含，只能查询或转换自定义实现）
        // 这里通过用户名重新查询，简单且安全
        SysUser user = userRepository.findByUsername(userDetails.getUsername()).orElseThrow();

        return ResponseEntity.ok(new JwtResponse(jwt,
                user.getUserId(),
                userDetails.getUsername(),
                roles));
    }

    @PostMapping("/signup")
    public ResponseEntity<?> registerUser(@RequestBody SignupRequest signUpRequest) {
        if (userRepository.findByUsername(signUpRequest.getUsername()).isPresent()) {
            return ResponseEntity
                    .badRequest()
                    .body(new MessageResponse("Error: Username is already taken!"));
        }

        // 创建新用户账号
        SysUser user = new SysUser();
        user.setUsername(signUpRequest.getUsername());
        user.setPasswordHash(encoder.encode(signUpRequest.getPassword()));
        user.setStoreId(signUpRequest.getStoreId());
        
        SysUser savedUser = userRepository.save(user);

        Set<String> strRoles = signUpRequest.getRole();
        
        if (strRoles == null) {
            // 如需可在这里处理默认角色或抛出错误
        } else {
            strRoles.forEach(role -> {
                SysRole roleEntity = roleRepository.findByRoleName(role)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                
                SysUserRole userRole = new SysUserRole();
                userRole.setUserId(savedUser.getUserId());
                userRole.setRoleId(roleEntity.getRoleId());
                userRoleRepository.save(userRole);
            });
        }

        return ResponseEntity.ok(new MessageResponse("User registered successfully!"));
    }
}
