# 课程设计交付改进计划（tesla-rental）

> 目标：一次性梳理 3.5.1~3.5.9 的所有交付物，形成可落地的 SQL/Java 产出清单，并与现有业务模型（车辆、车型、门店、订单、支付、违章、维保、用户/角色）对齐。

## 输出物总览与目录
- SQL 脚本存放：`docs/sql/`，按章节命名（如 `3.5.1_data_init.sql`、`3.5.2_queries.sql`）。
- 说明文档：每个脚本前附“需求描述 + 设计要点”注释，便于验收。
- Java 调用示例：`docs/java-samples/`（用于 3.5.9 演示如何调用查询、视图、存储过程等）。

## 3.5.1 数据初始化脚本（每表 ≥10 条）
- 表范围：brand、car_model、store、vehicle、customer、rental_order、payment、maintenance、violation、sys_user、sys_role、sys_user_role、audit_log 等。
- 数据设计：贴合业务场景，包含真实车型（Model 3/Y/S/X）、门店（城市/站点）、车辆车牌、电量/里程、租期、支付流水、违章、维保记录；在 sys_user/customer 中写入组内成员姓名/学号作为真实数据。
- 约束对齐：保证外键匹配（车辆归属门店、订单关联车辆/客户、支付关联订单），金额、电量、日期取值合理。
- 脚本结构：按“基础静态数据 → 业务数据 → 关联/流水数据”顺序插入，必要处加 `SET FOREIGN_KEY_CHECKS=0/1` 控制。

## 3.5.2 业务查询及查询脚本（≥20 个，每类 ≥2 个）
- 先写清查询需求再写 SQL，按类型分组并标注数据表与业务意义。
- 覆盖类型（每类至少 2 条）：
  - 比较条件（例：在租状态车辆、电量 < 20% 的车辆清单）。
  - 集合比较（`IN/ALL/ANY`，例：门店位于一线城市的订单）。
  - 范围比较（`BETWEEN`/日期区间，例：本月租金收入）。
  - 字符串相似比较（`LIKE`/`REGEXP`，例：车牌/客户姓名模糊）。
  - 多表连接（订单-车辆-客户-支付-门店）。
  - 嵌套查询（子查询筛选高价值客户）。
  - EXISTS 查询（检查客户是否有未结算违章/维保）。
- 输出：`docs/sql/3.5.2_queries.sql`，每条“需求 → SQL”成对出现。

## 3.5.3 数据更新及脚本（update/delete 各 ≥10 条）
- 设计 10 条 update 场景：更新车辆状态、电量、调仓；订单状态流转；支付补差；客户信用分调整；门店座位数/地址更新；修正车牌/车型关联等。
- 设计 10 条 delete 场景：删除过期优惠、作废未支付订单、删除测试车辆、清理孤立支付流水、移除无角色的测试用户等，均需 WHERE 约束和安全注释。
- 输出：`docs/sql/3.5.3_update_delete.sql`，附“前置条件/预期影响行数”说明。

## 3.5.4 视图创建脚本（≥5 个）
- 视图与查询联动，用于后续业务查询/Java 调用：
  - `vw_active_orders`：在租订单+车辆+客户信息。
  - `vw_store_utilization`：门店车辆利用率统计。
  - `vw_customer_value`：客户订单数、累计租金、违章次数。
  - `vw_payment_summary`：订单支付/押金/赔偿汇总。
  - `vw_maintenance_pending`：待处理维保/下一次保养里程提醒。
- 输出：`docs/sql/3.5.4_views.sql`，注明依赖表与用途。

## 3.5.5 索引创建脚本（≥10 个）
- 原则：贴合 3.5.2 查询与 3.5.4 视图的过滤/关联字段，避免盲目建索引。
- 计划索引：vehicle(plate_no), vehicle(store_id,status), rental_order(vehicle_id), rental_order(customer_id,status), payment(order_id,type), maintenance(vehicle_id,maint_date), violation(vehicle_id,violation_date), customer(phone/email 唯一索引), sys_user(username 唯一), sys_user_role(user_id,role_id) 组合索引等。
- 输出：`docs/sql/3.5.5_indexes.sql`，包含建索引原因注释。

## 3.5.6 存储过程创建脚本（≥5 个）
- 设计围绕订单全流程的过程：
  - 创建租赁订单（含车辆状态检查与更新）。
  - 订单结算（计算租金、生成支付记录、更新状态）。
  - 车辆调拨（门店之间转移并写审计）。
  - 客户信用分更新（基于违章/逾期）。
  - 维保登记（写维保、更新车辆状态、回写下次保养里程）。
- 输出：`docs/sql/3.5.6_procedures.sql`，包含输入/输出参数说明与异常处理。

## 3.5.7 触发器创建脚本（≥5 个）
- 触发器围绕一致性与审计：
  - 订单插入后自动写 audit_log。
  - 支付插入后校验金额并更新订单已付金额。
  - 维保完成后自动恢复车辆状态为在库。
  - 违章录入后降低客户信用分。
  - 删除车辆前阻断存在进行中订单的删除（或转存归档表）。
- 输出：`docs/sql/3.5.7_triggers.sql`，注明 BEFORE/AFTER、作用范围。

## 3.5.8 安全方案设计及实现脚本（≥3 类用户）
- 角色设计：DB 层定义 admin（DBA/全权限）、staff（业务操作）、auditor（只读审计）；与应用层的 sys_role 做映射说明。
- MySQL 用户与授权：创建三类用户，授予库/表/视图/过程的精确权限（SELECT/INSERT/UPDATE/DELETE/EXECUTE 等），禁止高危操作；附撤权脚本。
- 输出：`docs/sql/3.5.8_security.sql`，同时在说明中写明 3 类用户可用功能清单。

## 3.5.9 应用系统设计（Java 调用示例）
- 在现有 Spring Boot 中新增示例代码（不改业务逻辑，只做调用演示）：
  - DAO/Repository 层增加调用视图与存储过程的示例方法。
  - Controller 或 CommandLineRunner 展示对 3.5.2 查询、3.5.4 视图、3.5.6 存储过程的调用，打印结果供验收。
- 用角色区分功能：文档说明 admin/staff/auditor 能访问的接口/查询范围，必要时在 SecurityConfig 增加示例鉴权。
- 输出：`docs/java-samples/3.5.9_usage.md` + 对应 Java 类引用路径说明。

## 时间/顺序建议
1) 先完成 3.5.1 基础数据，作为后续所有查询/过程的依赖。  
2) 同步编写 3.5.2 查询需求与 3.5.4 视图草案，以便 3.5.5 索引设计。  
3) 在有稳定数据与视图后完成 3.5.6/3.5.7，最后补 3.5.8 权限和 3.5.9 Java 调用示例。  
4) 每个脚本落库前在本地 MySQL 校验执行，无误后纳入仓库。
