package com.tesla.rental.security;

import com.tesla.rental.entity.SysRole;
import com.tesla.rental.entity.SysUser;
import com.tesla.rental.entity.SysUserRole;
import com.tesla.rental.repository.SysRoleRepository;
import com.tesla.rental.repository.SysUserRepository;
import com.tesla.rental.repository.SysUserRoleRepository;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final SysUserRepository userRepository;
    private final SysUserRoleRepository userRoleRepository;
    private final SysRoleRepository roleRepository;

    public CustomUserDetailsService(SysUserRepository userRepository, SysUserRoleRepository userRoleRepository, SysRoleRepository roleRepository) {
        this.userRepository = userRepository;
        this.userRoleRepository = userRoleRepository;
        this.roleRepository = roleRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        SysUser sysUser = userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with username: " + username));

        List<SysUserRole> userRoles = userRoleRepository.findByUserId(sysUser.getUserId());
        List<Long> roleIds = userRoles.stream().map(SysUserRole::getRoleId).collect(Collectors.toList());
        List<SysRole> roles = roleRepository.findAllById(roleIds);

        List<SimpleGrantedAuthority> authorities = roles.stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.getRoleName())) // 假设 roleName 的值形如 "ADMIN"、"USER"
                .collect(Collectors.toList());

        return new User(sysUser.getUsername(), sysUser.getPasswordHash(), authorities);
    }
}
