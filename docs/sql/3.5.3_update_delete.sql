-- ============================================
-- Tesla 租车系统 - 数据更新及删除脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.3 数据更新及删除，update/delete 各 ≥10 条
-- ============================================

-- ============================================
-- Part 1: UPDATE 场景（10 条）
-- ============================================

-- UPDATE-1: 更新车辆状态（还车后从"在租"改为"在库"）
-- 前置条件：订单已结算，车辆状态为1（在租）
-- 预期影响行数：1-5 行（取决于当前在租车辆数）
-- 业务场景：订单结算完成后，将车辆状态从在租更新为在库，使其可供下一位客户租用
UPDATE vehicle
SET
    status = 0
WHERE
    vehicle_id IN (
        SELECT vehicle_id
        FROM rental_order
        WHERE
            status = 3
            AND return_soc IS NOT NULL
    )
    AND status = 1;

-- UPDATE-2: 更新车辆电量（充电后更新SOC）
-- 前置条件：车辆ID存在，电量低于50%
-- 预期影响行数：3-6 行（取决于低电量车辆数）
-- 业务场景：门店工作人员对低电量车辆进行充电，充电完成后更新电量至90%以上
UPDATE vehicle
SET
    current_soc = 95.0
WHERE
    current_soc < 50.0
    AND status = 0;

-- UPDATE-3: 车辆调仓（跨门店转移）
-- 前置条件：车辆ID=15，当前在上海门店（store_id=2），状态为在库
-- 预期影响行数：1 行
-- 业务场景：由于北京门店车辆紧张，将上海门店的闲置车辆调拨至北京
UPDATE vehicle
SET
    store_id = 1
WHERE
    vehicle_id = 15
    AND status = 0
    AND store_id = 2;

-- UPDATE-4: 订单状态流转（从"已支付"到"在租"）
-- 前置条件：订单状态为0（已支付），租期开始日期已到
-- 预期影响行数：2-4 行
-- 业务场景：客户已支付押金和租金，到店提车后，系统自动将订单状态更新为在租
UPDATE rental_order
SET
    status = 1
WHERE
    status = 0
    AND rent_start <= NOW();

-- UPDATE-5: 订单状态流转（从"在租"到"已还"）
-- 前置条件：订单状态为1（在租），租期结束日期已过，已填写return_soc
-- 预期影响行数：1-3 行
-- 业务场景：客户按时还车，门店工作人员检查车辆后，将订单状态更新为已还
UPDATE rental_order
SET
    status = 2
WHERE
    status = 1
    AND rent_end < NOW()
    AND return_soc IS NOT NULL;

-- UPDATE-6: 支付补差（租期延长需补租金）
-- 前置条件：订单ID=10 存在租金支付记录
-- 预期影响行数：1 行
-- 业务场景：客户延长租期2天，需补交租金1000元，更新支付记录
UPDATE payment
SET
    amount = amount + 1000.00
WHERE
    order_id = 10
    AND type = 1;

-- UPDATE-7: 客户信用分调整（违章扣分）
-- 前置条件：customer表有credit_score字段，customer_id=5 有违章记录
-- 预期影响行数：1 行
-- 业务场景：系统检测到客户有违章记录，自动扣除信用分20分
-- 注：假设customer表已添加credit_score字段，默认100分
UPDATE customer
SET
    credit_score = GREATEST(credit_score - 20, 0)
WHERE
    customer_id = 5;

-- UPDATE-8: 门店座位数更新（扩建后增加座位）
-- 前置条件：store表有seat_capacity字段，store_id=1
-- 预期影响行数：1 行
-- 业务场景：北京朝阳门店扩建完成，客户休息区座位从20个增加到35个
-- 注：假设store表已添加seat_capacity字段
UPDATE store SET seat_capacity = 35 WHERE store_id = 1;

-- UPDATE-9: 门店地址更新（门店搬迁）
-- 前置条件：store_id=7 存在
-- 预期影响行数：1 行
-- 业务场景：武汉光谷门店搬迁至新地址，更新门店地址信息
UPDATE store SET address = '武汉市东湖新技术开发区光谷中心城' WHERE store_id = 7;

-- UPDATE-10: 修正车牌/车型关联（数据录入错误修正）
-- 前置条件：vehicle_id=13 车牌为"渝A33333"，当前错误关联为model_id=4
-- 预期影响行数：1 行
-- 业务场景：发现车牌"渝A33333"实际为Model Y高性能版（model_id=5），修正车型关联
UPDATE vehicle
SET
    model_id = 5
WHERE
    vehicle_id = 13
    AND plate_no = '渝A33333';

-- UPDATE-11: 批量更新车辆里程（月度盘点）
-- 前置条件：所有在库车辆
-- 预期影响行数：8-12 行
-- 业务场景：每月门店对在库车辆进行例行检查，同步更新里程数据
UPDATE vehicle
SET
    current_mileage = current_mileage + 10.0
WHERE
    status = 0;

-- UPDATE-12: 更新维保车辆状态（维保完成）
-- 前置条件：vehicle_id=7 和 14 状态为2（维保中）
-- 预期影响行数：2 行
-- 业务场景：维保工作完成，车辆检测合格，更新状态为在库，可继续租用
UPDATE vehicle
SET
    status = 0
WHERE
    vehicle_id IN (7, 14)
    AND status = 2;

-- ============================================
-- Part 2: DELETE 场景（10 条）
-- ============================================

-- DELETE-1: 删除过期优惠券（假设有promotion表）
-- 前置条件：promotion表存在，有end_date < '2025-01-01'的记录
-- 预期影响行数：0-10 行（取决于历史优惠券数量）
-- 业务场景：每季度清理过期优惠券数据，释放存储空间
-- 安全约束：必须有WHERE条件限制过期日期
-- 注：此语句需要promotion表存在才能执行
-- DELETE FROM promotion
-- WHERE end_date < '2025-01-01';

-- DELETE-2: 作废未支付订单（超时自动取消）
-- 前置条件：订单状态为0（已支付）但无支付记录，创建超过24小时
-- 预期影响行数：1-3 行
-- 业务场景：客户下单后24小时内未支付，系统自动取消订单
-- 安全约束：必须检查订单状态和时间，避免误删有效订单
DELETE FROM rental_order
WHERE
    status = 0
    AND order_id NOT IN(
        SELECT DISTINCT
            order_id
        FROM payment
    )
    AND created_at < DATE_SUB(NOW(), INTERVAL 24 HOUR);

-- DELETE-3: 删除测试车辆（测试数据清理）
-- 前置条件：车牌包含"测试"关键字，且无关联订单
-- 预期影响行数：0-2 行
-- 业务场景：开发测试阶段录入的测试车辆，正式上线前需清理
-- 安全约束：必须确保车辆无关联订单，避免外键约束错误
DELETE FROM vehicle
WHERE
    plate_no LIKE '%测试%'
    AND vehicle_id NOT IN(
        SELECT DISTINCT
            vehicle_id
        FROM rental_order
    );

-- DELETE-4: 清理孤立支付流水（订单已删除但支付记录残留）
-- 前置条件：payment表中存在order_id不在rental_order表中的记录
-- 预期影响行数：0-5 行
-- 业务场景：数据清理时发现部分支付记录对应的订单已被删除，清理孤立记录
-- 安全约束：必须检查外键关联，仅删除孤立记录
DELETE FROM payment
WHERE
    order_id NOT IN(
        SELECT order_id
        FROM rental_order
    );

-- DELETE-5: 移除无角色的测试用户（权限清理）
-- 前置条件：sys_user表中存在未分配角色的用户
-- 预期影响行数：0-2 行
-- 业务场景：系统审计发现部分测试账号未分配角色，清理无效账号
-- 安全约束：必须检查用户是否有角色关联，避免误删正常用户
DELETE FROM sys_user
WHERE
    user_id NOT IN(
        SELECT DISTINCT
            user_id
        FROM sys_user_role
    )
    AND username LIKE 'test%';

-- DELETE-6: 删除6个月前的审计日志（数据归档）
-- 前置条件：audit_log表存在，有超过6个月的记录
-- 预期影响行数：10-100 行（取决于系统活跃度）
-- 业务场景：定期清理历史审计日志，保留近6个月数据即可
-- 安全约束：必须限制时间范围，避免删除所有日志
DELETE FROM audit_log
WHERE
    action_time < DATE_SUB(NOW(), INTERVAL 6 MONTH);

-- DELETE-7: 删除已结算订单的历史维保记录（数据归档）
-- 前置条件：maintenance表中有1年前的维保记录
-- 预期影响行数：2-8 行
-- 业务场景：每年归档历史维保数据到备份库，删除主库1年前数据
-- 安全约束：必须限制时间范围，避免误删近期维保记录
DELETE FROM maintenance
WHERE
    maint_date < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- DELETE-8: 删除无效违章记录（撤销错误录入）
-- 前置条件：violation表存在，有违章金额为0的无效记录
-- 预期影响行数：0-3 行
-- 业务场景：工作人员录入错误，违章金额为0的记录需要删除
-- 安全约束：必须检查金额字段，仅删除明确无效的记录
DELETE FROM violation WHERE fine_amount = 0 OR fine_amount IS NULL;

-- DELETE-9: 删除重复的客户记录（数据去重）
-- 前置条件：customer表中存在手机号重复的记录，保留ID最小的
-- 预期影响行数：0-5 行
-- 业务场景：数据迁移时产生重复客户记录，清理重复数据
-- 安全约束：必须使用子查询确保仅删除重复记录，保留一条
DELETE FROM customer
WHERE
    customer_id NOT IN(
        SELECT MIN(customer_id)
        FROM (
                SELECT *
                FROM customer
            ) AS temp
        GROUP BY
            phone
    );

-- DELETE-10: 删除未关联车辆的车型（冗余数据清理）
-- 前置条件：car_model表中存在未被vehicle表引用的车型
-- 预期影响行数：0-2 行
-- 业务场景：业务调整后某些车型不再使用，清理冗余车型配置
-- 安全约束：必须检查外键关联，仅删除未被使用的车型
DELETE FROM car_model
WHERE
    model_id NOT IN(
        SELECT DISTINCT
            model_id
        FROM vehicle
    )
    AND model_id > 10;
-- 保留前10个基础车型

-- DELETE-11: 删除已完成且无异常的临时订单数据（数据清理）
-- 前置条件：订单状态为3（已结算），无赔偿记录，结算时间超过3个月
-- 预期影响行数：3-8 行
-- 业务场景：定期归档无纠纷的历史订单，减少主库数据量
-- 安全约束：必须确保订单已结算且无赔偿记录
DELETE FROM rental_order
WHERE
    status = 3
    AND order_id NOT IN(
        SELECT DISTINCT
            order_id
        FROM payment
        WHERE
            type = 2
    )
    AND updated_at < DATE_SUB(NOW(), INTERVAL 3 MONTH);

-- DELETE-12: 删除门店被撤销后的孤立车辆记录（数据一致性维护）
-- 前置条件：vehicle表中存在store_id不在store表中的车辆
-- 预期影响行数：0 行（正常情况下应无此类数据）
-- 业务场景：门店关闭后未正确清理车辆数据，清理孤立记录
-- 安全约束：必须检查外键关联，避免误删正常车辆
DELETE FROM vehicle
WHERE
    store_id NOT IN(
        SELECT store_id
        FROM store
    );

-- ============================================
-- 执行注意事项
-- ============================================
-- 1. 所有DELETE语句均包含WHERE条件，避免全表删除
-- 2. 涉及外键关联的删除，需先检查依赖关系
-- 3. 建议在执行DELETE前先执行SELECT验证影响范围
-- 4. 重要数据删除前应做好备份
-- 5. 部分UPDATE/DELETE假设了表结构扩展（如credit_score、seat_capacity等）
--    如实际表结构不包含这些字段，需先执行ALTER TABLE添加字段
-- 6. DELETE-1涉及promotion表为假设表，需根据实际情况调整
-- 7. 所有时间相关操作基于当前时间NOW()，实际执行时需考虑数据现状

-- ============================================
-- 验证建议
-- ============================================
-- 执行UPDATE前验证示例：
-- SELECT * FROM vehicle WHERE current_soc < 50.0 AND status = 0;

-- 执行DELETE前验证示例：
-- SELECT COUNT(*) FROM maintenance WHERE maint_date < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- ============================================
-- 回滚建议
-- ============================================
-- 1. 在事务中执行：START TRANSACTION; ... COMMIT;
-- 2. 重要操作前备份相关表数据
-- 3. 记录操作日志便于审计和回滚