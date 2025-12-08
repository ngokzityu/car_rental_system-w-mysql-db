-- ============================================
-- Tesla 租车系统 - 安全方案设计及实现脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.8 安全方案（≥3 类用户）
-- ============================================

-- ============================================
-- 安全方案概述
-- ============================================
-- 本方案实现三权分立的数据库访问控制：
-- 1. admin   - 数据库管理员（DBA）：完整权限，负责系统维护
-- 2. staff   - 业务操作人员：读写业务数据，执行业务流程
-- 3. auditor - 审计人员：只读权限，负责审计和监控
--
-- 权限设计原则：
-- - 最小权限原则：只授予必需的权限
-- - 职责分离：不同角色权限隔离
-- - 禁止高危操作：DROP/TRUNCATE 等仅限 admin
-- - 审计可追溯：所有操作记录到 audit_log

-- ============================================
-- Part 1: 数据库用户创建
-- ============================================

-- --------------------------------------------------------
-- 1.1 创建 admin 用户（数据库管理员）
-- --------------------------------------------------------
-- 用途: 系统管理、架构变更、数据维护
-- 对应应用层角色: sys_role.role_id = 1 (管理员)
-- 密码策略: 强密码，定期更换
-- 访问限制: 仅允许从指定IP访问

-- 从本地访问
CREATE USER IF NOT EXISTS 'tesla_admin' @'localhost' IDENTIFIED BY 'Admin@Tesla2025!';

-- 从内网IP段访问（示例：192.168.1.0/24）
CREATE USER IF NOT EXISTS 'tesla_admin' @'192.168.1.%' IDENTIFIED BY 'Admin@Tesla2025!';

-- --------------------------------------------------------
-- 1.2 创建 staff 用户（业务操作人员）
-- --------------------------------------------------------
-- 用途: 日常业务操作、订单管理、客户服务
-- 对应应用层角色: sys_role.role_id = 2 (店员)
-- 密码策略: 中等强度密码
-- 访问限制: 允许从应用服务器访问

-- 从本地访问
CREATE USER IF NOT EXISTS 'tesla_staff' @'localhost' IDENTIFIED BY 'Staff@Tesla2025';

-- 从应用服务器访问（示例IP）
CREATE USER IF NOT EXISTS 'tesla_staff' @'192.168.1.%' IDENTIFIED BY 'Staff@Tesla2025';

-- --------------------------------------------------------
-- 1.3 创建 auditor 用户（审计人员）
-- --------------------------------------------------------
-- 用途: 数据审计、报表查询、合规检查
-- 对应应用层角色: sys_role.role_id = 3 (审计员)
-- 密码策略: 强密码，只读访问
-- 访问限制: 仅允许从审计工作站访问

-- 从本地访问
CREATE USER IF NOT EXISTS 'tesla_auditor' @'localhost' IDENTIFIED BY 'Auditor@Tesla2025';

-- 从审计工作站访问
CREATE USER IF NOT EXISTS 'tesla_auditor' @'192.168.1.%' IDENTIFIED BY 'Auditor@Tesla2025';

-- ============================================
-- Part 2: 权限授予 - admin 用户（管理员）
-- ============================================

-- --------------------------------------------------------
-- 2.1 admin 用户权限（完整权限）
-- --------------------------------------------------------
-- 授予范围: 整个 tesla_db 数据库
-- 权限级别: ALL PRIVILEGES（包括 DDL 和 DML）
-- 特殊权限: 包括创建视图、存储过程、触发器、索引等

-- 授予所有权限（包括授权权限）
GRANT ALL PRIVILEGES ON tesla_db.* TO 'tesla_admin' @'localhost'
WITH
GRANT OPTION;

GRANT ALL PRIVILEGES ON tesla_db.* TO 'tesla_admin' @'192.168.1.%'
WITH
GRANT OPTION;

-- 说明：
-- - ALL PRIVILEGES 包括：SELECT, INSERT, UPDATE, DELETE, CREATE, DROP,
--   INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE,
--   CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER
-- - WITH GRANT OPTION：允许将权限授予其他用户

-- ============================================
-- Part 3: 权限授予 - staff 用户（业务操作）
-- ============================================

-- --------------------------------------------------------
-- 3.1 基础数据表权限（业务核心表）
-- --------------------------------------------------------

-- 3.1.1 rental_order 表（订单表）- 完整 CRUD 权限
GRANT
SELECT,
INSERT
,
UPDATE ON tesla_db.rental_order TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';
-- 不授予 DELETE：订单不应删除，只能更新状态

-- 3.1.2 customer 表（客户表）- 读写权限
GRANT
SELECT,
INSERT
,
UPDATE ON tesla_db.customer TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';
-- 不授予 DELETE：客户数据需保留用于历史查询

-- 3.1.3 vehicle 表（车辆表）- 读写权限
GRANT
SELECT,
INSERT
,
UPDATE ON tesla_db.vehicle TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';
-- 允许更新车辆状态、电量、里程等

-- 3.1.4 payment 表（支付表）- 插入和查询权限
GRANT
SELECT,
INSERT
    ON tesla_db.payment TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';
-- 不授予 UPDATE/DELETE：支付记录不可修改，确保财务数据完整性

-- 3.1.5 maintenance 表（维保表）- 完整权限
GRANT
SELECT,
INSERT
,
UPDATE ON tesla_db.maintenance TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';
-- 允许登记和更新维保记录

-- 3.1.6 violation 表（违章表）- 插入和查询权限
GRANT
SELECT,
INSERT
    ON tesla_db.violation TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';
-- 不授予 UPDATE：违章记录录入后不可修改

-- --------------------------------------------------------
-- 3.2 基础配置表权限（只读）
-- --------------------------------------------------------

-- 3.2.1 brand、car_model、store 表 - 只读
GRANT
SELECT
    ON tesla_db.brand TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.car_model TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.store TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

-- 说明：配置表由管理员维护，staff 只读

-- --------------------------------------------------------
-- 3.3 系统表权限（受限访问）
-- --------------------------------------------------------

-- 3.3.1 sys_user 表 - 只读自己的信息
GRANT
SELECT
    ON tesla_db.sys_user TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';
-- 应用层需额外控制：只能查询自己的用户信息

-- 3.3.2 sys_role、sys_user_role 表 - 只读
GRANT
SELECT
    ON tesla_db.sys_role TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.sys_user_role TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

-- 3.3.3 audit_log 表 - 只能插入
GRANT
INSERT
    ON tesla_db.audit_log TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';
-- 不授予 SELECT：防止员工查看和篡改审计日志

-- --------------------------------------------------------
-- 3.4 视图权限（业务视图）
-- --------------------------------------------------------

-- 授予所有业务视图的查询权限
GRANT
SELECT
    ON tesla_db.vw_active_orders TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_store_utilization TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_customer_value TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_payment_summary TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_maintenance_pending TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_vehicle_details TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_violation_summary TO 'tesla_staff' @'localhost',
    'tesla_staff' @'192.168.1.%';

-- --------------------------------------------------------
-- 3.5 存储过程权限（业务流程）
-- --------------------------------------------------------

-- 授予存储过程执行权限
GRANT EXECUTE ON PROCEDURE tesla_db.sp_create_rental_order 
TO 'tesla_staff'@'localhost', 'tesla_staff'@'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_settle_rental_order TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_transfer_vehicle TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_update_customer_credit TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_register_maintenance TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_complete_maintenance TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

GRANT
EXECUTE ON PROCEDURE tesla_db.sp_pay_deposit TO 'tesla_staff' @'localhost',
'tesla_staff' @'192.168.1.%';

-- ============================================
-- Part 4: 权限授予 - auditor 用户（审计员）
-- ============================================

-- --------------------------------------------------------
-- 4.1 所有业务表只读权限
-- --------------------------------------------------------

-- 核心业务表
GRANT
SELECT
    ON tesla_db.rental_order TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.customer TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vehicle TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.payment TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.maintenance TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.violation TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

-- 配置表
GRANT
SELECT
    ON tesla_db.brand TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.car_model TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.store TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

-- 系统表
GRANT
SELECT
    ON tesla_db.sys_user TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.sys_role TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.sys_user_role TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

-- 审计日志表（重要：审计员必须能查看日志）
GRANT
SELECT
    ON tesla_db.audit_log TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

-- --------------------------------------------------------
-- 4.2 所有视图只读权限
-- --------------------------------------------------------

GRANT
SELECT
    ON tesla_db.vw_active_orders TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_store_utilization TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_customer_value TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_payment_summary TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_maintenance_pending TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_vehicle_details TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

GRANT
SELECT
    ON tesla_db.vw_violation_summary TO 'tesla_auditor' @'localhost',
    'tesla_auditor' @'192.168.1.%';

-- --------------------------------------------------------
-- 4.3 存储过程权限（仅查询类）
-- --------------------------------------------------------

-- 审计员不授予存储过程执行权限
-- 原因：存储过程可能涉及数据修改，审计员应仅读取数据
-- 如需执行查询类存储过程，应单独创建只读存储过程并授权

-- ============================================
-- Part 5: 应用权限刷新
-- ============================================

-- 刷新权限使其立即生效
FLUSH PRIVILEGES;

-- ============================================
-- Part 6: 权限验证查询
-- ============================================

-- 查看 admin 用户权限
SHOW GRANTS FOR 'tesla_admin' @'localhost';
-- SHOW GRANTS FOR 'tesla_admin'@'192.168.1.%';

-- 查看 staff 用户权限
SHOW GRANTS FOR 'tesla_staff' @'localhost';
-- SHOW GRANTS FOR 'tesla_staff'@'192.168.1.%';

-- 查看 auditor 用户权限
SHOW GRANTS FOR 'tesla_auditor' @'localhost';
-- SHOW GRANTS FOR 'tesla_auditor'@'192.168.1.%';

-- ============================================
-- Part 7: 权限撤销脚本（紧急情况使用）
-- ============================================

-- --------------------------------------------------------
-- 7.1 撤销 admin 用户权限
-- --------------------------------------------------------
-- 使用场景：管理员离职或权限滥用

-- REVOKE ALL PRIVILEGES, GRANT OPTION
-- FROM 'tesla_admin'@'localhost';
--
-- REVOKE ALL PRIVILEGES, GRANT OPTION
-- FROM 'tesla_admin'@'192.168.1.%';

-- --------------------------------------------------------
-- 7.2 撤销 staff 用户权限
-- --------------------------------------------------------
-- 使用场景：员工离职或调岗

-- 撤销所有表权限
-- REVOKE ALL PRIVILEGES
-- FROM 'tesla_staff'@'localhost';
--
-- REVOKE ALL PRIVILEGES
-- FROM 'tesla_staff'@'192.168.1.%';

-- --------------------------------------------------------
-- 7.3 撤销 auditor 用户权限
-- --------------------------------------------------------
-- 使用场景：审计员离职

-- REVOKE ALL PRIVILEGES
-- FROM 'tesla_auditor'@'localhost';
--
-- REVOKE ALL PRIVILEGES
-- FROM 'tesla_auditor'@'192.168.1.%';

-- --------------------------------------------------------
-- 7.4 删除用户（完全移除账户）
-- --------------------------------------------------------
-- 警告：删除前确保已撤销所有权限

-- DROP USER IF EXISTS 'tesla_admin'@'localhost';
-- DROP USER IF EXISTS 'tesla_admin'@'192.168.1.%';
--
-- DROP USER IF EXISTS 'tesla_staff'@'localhost';
-- DROP USER IF EXISTS 'tesla_staff'@'192.168.1.%';
--
-- DROP USER IF EXISTS 'tesla_auditor'@'localhost';
-- DROP USER IF EXISTS 'tesla_auditor'@'192.168.1.%';

-- 刷新权限
-- FLUSH PRIVILEGES;

-- ============================================
-- Part 8: 与应用层角色映射说明
-- ============================================

/*
数据库层用户与应用层角色映射关系：

+-------------------+------------------+------------------------+
| 数据库用户         | 应用层角色        | sys_role 表对应关系     |
+-------------------+------------------+------------------------+
| tesla_admin       | 管理员           | role_id = 1 (管理员)    |
|                   |                  | role_name = '管理员'    |
+-------------------+------------------+------------------------+
| tesla_staff       | 店员             | role_id = 2 (店员)      |
|                   |                  | role_name = '店员'      |
+-------------------+------------------+------------------------+
| tesla_auditor     | 审计员           | role_id = 3 (审计员)    |
|                   |                  | role_name = '审计员'    |
+-------------------+------------------+------------------------+

应用层实现建议：
1. 用户登录后，根据 sys_user_role 表确定用户角色
2. 应用层根据角色选择对应的数据库用户连接数据库
3. 使用连接池，为不同角色配置独立的连接池
4. 敏感操作（如删除、导出）需二次验证用户身份

示例配置（application.properties）：

# Admin 数据源配置
spring.datasource.admin.url=jdbc:mysql://localhost:3306/tesla_db
spring.datasource.admin.username=tesla_admin
spring.datasource.admin.password=Admin@Tesla2025!

# Staff 数据源配置
spring.datasource.staff.url=jdbc:mysql://localhost:3306/tesla_db
spring.datasource.staff.username=tesla_staff
spring.datasource.staff.password=Staff@Tesla2025

# Auditor 数据源配置
spring.datasource.auditor.url=jdbc:mysql://localhost:3306/tesla_db
spring.datasource.auditor.username=tesla_auditor
spring.datasource.auditor.password=Auditor@Tesla2025
*/

-- ============================================
-- Part 9: 三类用户功能清单
-- ============================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│ 1. admin 用户（数据库管理员）功能清单                                   │
├─────────────────────────────────────────────────────────────────────┤
│ 权限级别：ALL PRIVILEGES (完整权限)                                   │
│                                                                      │
│ ✅ 数据定义（DDL）：                                                   │
│    - CREATE/DROP/ALTER 表、视图、索引、存储过程、触发器               │
│    - 创建和删除数据库对象                                             │
│    - 修改表结构和约束                                                 │
│                                                                      │
│ ✅ 数据操作（DML）：                                                   │
│    - SELECT：查询所有表和视图                                         │
│    - INSERT/UPDATE/DELETE：修改所有表数据                             │
│    - TRUNCATE：清空表数据                                             │
│                                                                      │
│ ✅ 存储过程和函数：                                                    │
│    - 创建、修改、删除存储过程和函数                                    │
│    - 执行所有存储过程                                                 │
│                                                                      │
│ ✅ 用户管理：                                                          │
│    - 创建和删除用户                                                   │
│    - 授予和撤销权限（WITH GRANT OPTION）                              │
│    - 修改用户密码                                                     │
│                                                                      │
│ ✅ 系统维护：                                                          │
│    - 数据备份和恢复                                                   │
│    - 性能优化（ANALYZE/OPTIMIZE TABLE）                               │
│    - 索引维护                                                         │
│    - 查看服务器状态和系统变量                                         │
│                                                                      │
│ ⚠️  使用场景：                                                         │
│    - 系统初始化和架构升级                                             │
│    - 紧急数据修复                                                     │
│    - 性能调优和监控                                                   │
│    - 用户权限管理                                                     │
│                                                                      │
│ 🔒 安全建议：                                                          │
│    - 仅限 DBA 使用，不用于日常业务操作                                │
│    - 强密码策略，定期更换密码                                         │
│    - 限制访问IP，仅允许内网访问                                       │
│    - 所有操作应记录到独立审计日志                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 2. staff 用户（业务操作人员）功能清单                                   │
├─────────────────────────────────────────────────────────────────────┤
│ 权限级别：受限的 DML 权限 + 存储过程执行权限                          │
│                                                                      │
│ ✅ 订单管理：                                                          │
│    - rental_order 表：SELECT, INSERT, UPDATE                         │
│    - 创建订单：执行 sp_create_rental_order                            │
│    - 订单结算：执行 sp_settle_rental_order                            │
│    - 查询订单：SELECT vw_active_orders                                │
│    - ❌ 禁止：DELETE 订单（防止数据丢失）                              │
│                                                                      │
│ ✅ 客户管理：                                                          │
│    - customer 表：SELECT, INSERT, UPDATE                             │
│    - 新增客户注册                                                     │
│    - 更新客户信息                                                     │
│    - 更新客户信用分：执行 sp_update_customer_credit                   │
│    - 查询客户价值：SELECT vw_customer_value                           │
│    - ❌ 禁止：DELETE 客户（保留历史数据）                              │
│                                                                      │
│ ✅ 车辆管理：                                                          │
│    - vehicle 表：SELECT, INSERT, UPDATE                              │
│    - 更新车辆状态、电量、里程                                         │
│    - 车辆调拨：执行 sp_transfer_vehicle                               │
│    - 查询车辆详情：SELECT vw_vehicle_details                          │
│    - 查询门店利用率：SELECT vw_store_utilization                      │
│    - ❌ 禁止：DELETE 车辆（防止误删）                                  │
│                                                                      │
│ ✅ 支付管理：                                                          │
│    - payment 表：SELECT, INSERT                                      │
│    - 录入支付记录（押金、租金）                                       │
│    - 支付押金：执行 sp_pay_deposit                                    │
│    - 查询支付汇总：SELECT vw_payment_summary                          │
│    - ❌ 禁止：UPDATE/DELETE 支付记录（财务数据不可篡改）               │
│                                                                      │
│ ✅ 维保管理：                                                          │
│    - maintenance 表：SELECT, INSERT, UPDATE                          │
│    - 登记维保：执行 sp_register_maintenance                           │
│    - 维保完成：执行 sp_complete_maintenance                           │
│    - 查询维保提醒：SELECT vw_maintenance_pending                      │
│                                                                      │
│ ✅ 违章管理：                                                          │
│    - violation 表：SELECT, INSERT                                    │
│    - 录入违章记录                                                     │
│    - 查询违章汇总：SELECT vw_violation_summary                        │
│    - ❌ 禁止：UPDATE/DELETE 违章（录入后不可修改）                     │
│                                                                      │
│ ✅ 配置查询（只读）：                                                   │
│    - brand、car_model、store 表：SELECT                              │
│    - 查询品牌、车型、门店信息                                         │
│    - ❌ 禁止：修改配置数据（由管理员维护）                             │
│                                                                      │
│ ✅ 系统功能：                                                          │
│    - sys_user、sys_role、sys_user_role 表：SELECT                    │
│    - audit_log 表：INSERT（记录自己的操作）                           │
│    - ❌ 禁止：查看或修改审计日志（防止篡改）                           │
│                                                                      │
│ ⚠️  使用场景：                                                         │
│    - 日常订单处理                                                     │
│    - 客户服务和管理                                                   │
│    - 车辆调度和维保                                                   │
│    - 支付和违章录入                                                   │
│                                                                      │
│ 🔒 安全限制：                                                          │
│    - 不能删除核心业务数据                                             │
│    - 不能修改支付和违章记录                                           │
│    - 不能查看审计日志                                                 │
│    - 不能修改系统配置                                                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 3. auditor 用户（审计人员）功能清单                                     │
├─────────────────────────────────────────────────────────────────────┤
│ 权限级别：只读权限（SELECT ONLY）                                     │
│                                                                      │
│ ✅ 业务数据查询：                                                      │
│    - 所有业务表：rental_order, customer, vehicle, payment,           │
│      maintenance, violation - SELECT                                │
│    - 查询所有历史订单和交易记录                                       │
│    - 分析业务数据和趋势                                               │
│    - 生成业务报表                                                     │
│                                                                      │
│ ✅ 配置数据查询：                                                      │
│    - brand, car_model, store 表 - SELECT                            │
│    - 查询系统配置和基础数据                                           │
│                                                                      │
│ ✅ 系统数据查询：                                                      │
│    - sys_user, sys_role, sys_user_role 表 - SELECT                  │
│    - 审查用户和角色配置                                               │
│    - 检查权限分配合规性                                               │
│                                                                      │
│ ✅ 审计日志查询（核心功能）：                                           │
│    - audit_log 表 - SELECT                                           │
│    - 查询所有操作日志                                                 │
│    - 追踪异常操作                                                     │
│    - 生成合规审计报告                                                 │
│                                                                      │
│ ✅ 视图查询：                                                          │
│    - 所有业务视图 - SELECT                                            │
│    - vw_active_orders：在租订单分析                                   │
│    - vw_store_utilization：门店运营分析                               │
│    - vw_customer_value：客户价值分析                                  │
│    - vw_payment_summary：财务对账                                     │
│    - vw_maintenance_pending：维保合规检查                             │
│    - vw_vehicle_details：资产盘点                                     │
│    - vw_violation_summary：违章风险分析                               │
│                                                                      │
│ ✅ 审计分析功能：                                                      │
│    - 财务对账和异常检测                                               │
│    - 操作日志审计和合规检查                                           │
│    - 业务数据统计和趋势分析                                           │
│    - 风险预警和问题追踪                                               │
│    - 生成各类审计报告                                                 │
│                                                                      │
│ ❌ 禁止操作：                                                          │
│    - INSERT/UPDATE/DELETE：不能修改任何数据                           │
│    - EXECUTE：不能执行存储过程                                        │
│    - CREATE/DROP/ALTER：不能修改数据库结构                            │
│    - 不能授予或撤销权限                                               │
│                                                                      │
│ ⚠️  使用场景：                                                         │
│    - 定期审计和合规检查                                               │
│    - 异常操作调查                                                     │
│    - 财务对账和报表                                                   │
│    - 业务数据分析                                                     │
│                                                                      │
│ 🔒 安全保障：                                                          │
│    - 完全只读，不能修改任何数据                                       │
│    - 独立账号，与业务操作隔离                                         │
│    - 审计日志完整访问权限                                             │
│    - 支持独立审计和监督                                               │
└─────────────────────────────────────────────────────────────────────┘
*/

-- ============================================
-- Part 10: 权限使用示例
-- ============================================

/*
-- 示例 1: staff 用户创建订单
CALL sp_create_rental_order(
1, 1, '2025-12-10 09:00', '2025-12-15 18:00',
1, 1, 2500.00, @order_id, @code, @msg
);

-- 示例 2: staff 用户查询在租订单
SELECT * FROM vw_active_orders WHERE customer_id = 1;

-- 示例 3: auditor 用户查询审计日志
SELECT * FROM audit_log 
WHERE action_time >= '2025-12-01'
ORDER BY log_id DESC;

-- 示例 4: admin 用户创建新索引
CREATE INDEX idx_test ON vehicle(plate_no);
-- 其他用户无此权限

-- 示例 5: staff 尝试删除订单（应失败）
DELETE FROM rental_order WHERE order_id = 1;
-- ERROR 1142: DELETE command denied
*/

-- ============================================
-- Part 11: 密码管理和安全建议
-- ============================================

/*
密码策略：
1. 复杂度要求：
- 长度: 至少 12 位
- 包含: 大写字母、小写字母、数字、特殊字符
- admin: Admin@Tesla2025! (强密码)
- staff: Staff@Tesla2025 (中等密码)
- auditor: Auditor@Tesla2025 (强密码)

2. 定期更换：
- admin/auditor: 每 90 天
- staff: 每 180 天

3. 修改密码示例：
ALTER USER 'tesla_admin'@'localhost' 
IDENTIFIED BY 'NewAdmin@Tesla2025!';
FLUSH PRIVILEGES;

访问控制：
1. IP 白名单：
- 仅允许内网 IP 段（192.168.1.0/24）
- 生产环境严格限制访问源

2. 连接限制：
ALTER USER 'tesla_staff'@'localhost' 
WITH MAX_QUERIES_PER_HOUR 500 
MAX_UPDATES_PER_HOUR 100 
MAX_CONNECTIONS_PER_HOUR 10;

3. SSL/TLS 加密（生产环境必须）：
REQUIRE SSL

审计和监控：
1. 启用 MySQL 审计插件
2. 记录所有 DDL 和高危 DML 操作
3. 定期审查权限变更
4. 监控异常登录和查询
*/

-- ============================================
-- 脚本执行完成
-- ============================================

-- 显示当前所有用户
SELECT User, Host FROM mysql.user WHERE User LIKE 'tesla_%';

-- 确认权限生效
SELECT '安全方案配置完成！' AS Status;

SELECT '三类用户已创建并授权：tesla_admin, tesla_staff, tesla_auditor' AS Info;

SELECT '请查看功能清单了解各用户权限详情' AS Note;