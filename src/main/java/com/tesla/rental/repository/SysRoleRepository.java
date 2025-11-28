package com.tesla.rental.repository;

import com.tesla.rental.entity.SysRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SysRoleRepository extends JpaRepository<SysRole, Long> {
    Optional<SysRole> findByRoleName(String roleName);
}
