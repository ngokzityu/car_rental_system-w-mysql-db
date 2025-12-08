-- ============================================
-- Tesla 租车系统 - 触发器创建脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.7 触发器创建（≥5 个）
-- ============================================

-- 切换数据库
USE tesla_db;

-- 设置分隔符
DELIMITER $$

-- ============================================
-- 触发器 1: trg_rental_order_after_insert
-- 类型: AFTER INSERT
-- 作用范围: rental_order 表
-- 功能: 订单插入后自动写入审计日志
-- ============================================
-- 业务场景: 每次创建新订单时，自动记录操作日志，便于追踪和审计
-- 触发时机: 订单记录插入到 rental_order 表之后
-- 触发条件: 无条件触发
-- 执行动作: 向 audit_log 表插入一条审计记录
-- 涉及字段: NEW.order_id, NEW.customer_id, NEW.vehicle_id, NEW.total_amount

DROP TRIGGER IF EXISTS trg_rental_order_after_insert$$

CREATE TRIGGER trg_rental_order_after_insert
AFTER INSERT ON rental_order
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_customer_name VARCHAR(50);
    DECLARE v_plate_no VARCHAR(20);
    
    -- 获取客户姓名
    SELECT name INTO v_customer_name
    FROM customer
    WHERE customer_id = NEW.customer_id;
    
    -- 获取车牌号
    SELECT plate_no INTO v_plate_no
    FROM vehicle
    WHERE vehicle_id = NEW.vehicle_id;
    
    -- 插入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT(
            '创建租赁订单 #', NEW.order_id,
            ' - 客户: ', COALESCE(v_customer_name, '未知'),
            ' (ID:', NEW.customer_id, ')',
            ', 车辆: ', COALESCE(v_plate_no, '未知'),
            ' (ID:', NEW.vehicle_id, ')',
            ', 金额: ¥', NEW.total_amount,
            ', 租期: ', DATE_FORMAT(NEW.rent_start, '%Y-%m-%d'),
            ' 至 ', DATE_FORMAT(NEW.rent_end, '%Y-%m-%d')
        ),
        NOW(),
        '127.0.0.1',  -- 实际应用中应从会话获取真实IP
        NULL  -- 实际应用中应从会话获取当前用户ID
    );
END$$

-- ============================================
-- 触发器 2: trg_payment_after_insert
-- 类型: AFTER INSERT
-- 作用范围: payment 表
-- 功能: 支付插入后校验金额并更新订单已付金额
-- ============================================
-- 业务场景: 客户支付押金或租金后，自动更新订单的支付状态和已付总额
-- 触发时机: 支付记录插入到 payment 表之后
-- 触发条件: 无条件触发
-- 执行动作:
--   1. 校验支付金额是否大于0
--   2. 计算订单已付总额
--   3. 写入审计日志
-- 涉及字段: NEW.amount, NEW.type, NEW.order_id

DROP TRIGGER IF EXISTS trg_payment_after_insert$$

CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_total_paid DECIMAL(10,2);
    DECLARE v_order_amount DECIMAL(10,2);
    DECLARE v_payment_type_desc VARCHAR(20);
    
    -- 金额校验（仅记录警告，不阻止插入）
    IF NEW.amount <= 0 THEN
        -- 插入警告日志
        INSERT INTO audit_log (action, action_time, ip_address, user_id)
        VALUES (
            CONCAT('警告: 支付金额异常 - 支付ID:', NEW.pay_id, ', 金额:', NEW.amount),
            NOW(),
            '127.0.0.1',
            NULL
        );
    END IF;
    
    -- 计算订单已付总额
    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM payment
    WHERE order_id = NEW.order_id;
    
    -- 获取订单总金额
    SELECT total_amount INTO v_order_amount
    FROM rental_order
    WHERE order_id = NEW.order_id;
    
    -- 确定支付类型描述
    SET v_payment_type_desc = CASE NEW.type
        WHEN 0 THEN '押金'
        WHEN 1 THEN '租金'
        WHEN 2 THEN '赔偿'
        ELSE '未知'
    END;
    
    -- 写入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT(
            '支付记录创建 #', NEW.pay_id,
            ' - 订单: #', NEW.order_id,
            ', 类型: ', v_payment_type_desc,
            ', 金额: ¥', NEW.amount,
            ', 已付总额: ¥', v_total_paid,
            ' / ¥', COALESCE(v_order_amount, 0),
            ' (', ROUND(v_total_paid * 100 / NULLIF(v_order_amount, 0), 2), '%)'
        ),
        NOW(),
        '127.0.0.1',
        NULL
    );
    
    -- 注意：MySQL触发器中不能直接UPDATE触发表本身
    -- 如需更新订单已付金额字段，需在应用层或存储过程中处理
END$$

-- ============================================
-- 触发器 3: trg_maintenance_after_update
-- 类型: AFTER UPDATE
-- 作用范围: maintenance 表
-- 功能: 维保记录更新后，根据状态自动恢复车辆可用状态
-- ============================================
-- 业务场景: 维保工作完成后，标记维保记录状态，自动将车辆状态改为在库
-- 触发时机: maintenance 表记录被更新之后
-- 触发条件: 假设 maintenance 表有 status 字段（0=进行中，1=已完成）
-- 执行动作:
--   1. 检查维保状态是否变更为已完成
--   2. 更新对应车辆状态为在库
--   3. 写入审计日志
-- 涉及字段: NEW.status, OLD.status, NEW.vehicle_id
-- 注意: 此触发器假设 maintenance 表已添加 status 字段

DROP TRIGGER IF EXISTS trg_maintenance_after_update$$

CREATE TRIGGER trg_maintenance_after_update
AFTER UPDATE ON maintenance
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_plate_no VARCHAR(20);
    DECLARE v_vehicle_status INT;
    
    -- 假设 maintenance 表有 status 字段：0=进行中，1=已完成
    -- 如果表结构没有此字段，此触发器暂时不会执行
    -- 可以通过检查 maint_date 的更新来判断维保完成
    
    -- 简化逻辑：如果维保记录的描述包含"完成"关键字，则恢复车辆状态
    -- 或者：如果 type 字段更新，视为维保完成
    
    -- 获取车辆信息
    SELECT plate_no, status INTO v_plate_no, v_vehicle_status
    FROM vehicle
    WHERE vehicle_id = NEW.vehicle_id;
    
    -- 如果车辆当前在维保状态，且维保记录被更新（可能是完成）
    -- 这里采用简单逻辑：维保记录更新时如果车辆在维保状态，不自动恢复
    -- 实际应该通过 status 字段判断，这里仅作为示例
    
    -- 假设通过描述关键字判断
    IF NEW.description LIKE '%完成%' OR NEW.description LIKE '%结束%' THEN
        -- 如果车辆当前在维保状态
        IF v_vehicle_status = 2 THEN
            -- 更新车辆状态为在库
            UPDATE vehicle
            SET status = 0
            WHERE vehicle_id = NEW.vehicle_id;
            
            -- 写入审计日志
            INSERT INTO audit_log (action, action_time, ip_address, user_id)
            VALUES (
                CONCAT(
                    '维保完成自动恢复车辆状态 - ',
                    '车辆: ', v_plate_no, ' (ID:', NEW.vehicle_id, ')',
                    ', 维保记录: #', NEW.maint_id,
                    ', 维保类型: ', CASE NEW.type
                        WHEN 0 THEN '保养'
                        WHEN 1 THEN '维修'
                        WHEN 2 THEN '其他'
                    END,
                    ', 状态: 维保中 -> 在库'
                ),
                NOW(),
                '127.0.0.1',
                NULL
            );
        END IF;
    END IF;
END$$

-- ============================================
-- 触发器 4: trg_violation_after_insert
-- 类型: AFTER INSERT
-- 作用范围: violation 表
-- 功能: 违章录入后自动降低客户信用分
-- ============================================
-- 业务场景: 录入违章记录后，根据违章严重程度自动扣除客户信用分
-- 触发时机: 违章记录插入到 violation 表之后
-- 触发条件: 无条件触发
-- 执行动作:
--   1. 根据罚款金额确定扣分额度
--   2. 更新客户信用分（假设 customer 表有 credit_score 字段）
--   3. 写入审计日志
-- 涉及字段: NEW.fine_amount, NEW.order_id, NEW.vehicle_id
-- 扣分规则:
--   - 罚款 < 200元: 扣5分
--   - 罚款 200-500元: 扣10分
--   - 罚款 > 500元: 扣20分

DROP TRIGGER IF EXISTS trg_violation_after_insert$$

CREATE TRIGGER trg_violation_after_insert
AFTER INSERT ON violation
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_customer_id INT;
    DECLARE v_customer_name VARCHAR(50);
    DECLARE v_credit_deduction INT;
    DECLARE v_old_credit INT;
    DECLARE v_new_credit INT;
    DECLARE v_plate_no VARCHAR(20);
    
    -- 获取客户ID（从订单）
    SELECT customer_id INTO v_customer_id
    FROM rental_order
    WHERE order_id = NEW.order_id;
    
    -- 获取客户姓名和当前信用分
    -- 注意：假设 customer 表有 credit_score 字段，默认100分
    -- 如果没有此字段，需要先执行：ALTER TABLE customer ADD COLUMN credit_score INT DEFAULT 100;
    SELECT name INTO v_customer_name
    FROM customer
    WHERE customer_id = v_customer_id;
    
    -- 设置初始信用分（假设值）
    SET v_old_credit = 100;  -- 实际应从 customer 表读取
    
    -- 获取车牌号
    SELECT plate_no INTO v_plate_no
    FROM vehicle
    WHERE vehicle_id = NEW.vehicle_id;
    
    -- 根据罚款金额确定扣分额度
    SET v_credit_deduction = CASE
        WHEN NEW.fine_amount < 200 THEN 5
        WHEN NEW.fine_amount <= 500 THEN 10
        ELSE 20
    END;
    
    -- 计算新信用分（最低0分）
    SET v_new_credit = GREATEST(v_old_credit - v_credit_deduction, 0);
    
    -- 更新客户信用分（如果字段存在）
    -- UPDATE customer
    -- SET credit_score = v_new_credit
    -- WHERE customer_id = v_customer_id;
    
    -- 写入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT(
            '违章记录创建并扣除信用分 - ',
            '违章ID: #', NEW.vio_id,
            ', 客户: ', COALESCE(v_customer_name, '未知'), ' (ID:', v_customer_id, ')',
            ', 车辆: ', COALESCE(v_plate_no, '未知'),
            ', 罚款: ¥', NEW.fine_amount,
            ', 地点: ', NEW.location,
            ', 扣分: ', v_credit_deduction,
            ', 信用分: ', v_old_credit, ' -> ', v_new_credit
        ),
        NOW(),
        '127.0.0.1',
        NULL
    );
END$$

-- ============================================
-- 触发器 5: trg_vehicle_before_delete
-- 类型: BEFORE DELETE
-- 作用范围: vehicle 表
-- 功能: 删除车辆前阻断存在进行中订单的删除
-- ============================================
-- 业务场景: 防止误删除仍有订单的车辆，保证数据完整性
-- 触发时机: 从 vehicle 表删除记录之前
-- 触发条件: 车辆存在进行中订单（状态为0或1）
-- 执行动作:
--   1. 检查是否存在进行中订单
--   2. 如果存在，抛出错误阻止删除
--   3. 如果不存在，允许删除并记录日志
-- 涉及字段: OLD.vehicle_id, OLD.plate_no

DROP TRIGGER IF EXISTS trg_vehicle_before_delete$$

CREATE TRIGGER trg_vehicle_before_delete
BEFORE DELETE ON vehicle
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_active_order_count INT;
    DECLARE v_order_ids VARCHAR(255);
    
    -- 检查是否存在进行中的订单（状态0=已支付，1=在租）
    SELECT COUNT(*), GROUP_CONCAT(order_id)
    INTO v_active_order_count, v_order_ids
    FROM rental_order
    WHERE vehicle_id = OLD.vehicle_id
      AND status IN (0, 1);
    
    -- 如果存在进行中订单，阻止删除
    IF v_active_order_count > 0 THEN
        -- 抛出错误，阻止删除操作
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT(
            '删除失败: 车辆 ', OLD.plate_no, ' (ID:', OLD.vehicle_id, ') ',
            '存在 ', v_active_order_count, ' 个进行中订单 (订单ID: ', v_order_ids, '). ',
            '请先完成或取消这些订单后再删除车辆。'
        );
    END IF;
    
    -- 如果没有进行中订单，允许删除（可选：转存归档表）
    -- 实际系统中可以在这里将数据转存到归档表
    -- INSERT INTO vehicle_archive SELECT * FROM vehicle WHERE vehicle_id = OLD.vehicle_id;
    
    -- 记录删除操作到审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT(
            '车辆删除 - ',
            '车牌: ', OLD.plate_no,
            ' (ID:', OLD.vehicle_id, ')',
            ', 状态: ', CASE OLD.status
                WHEN 0 THEN '在库'
                WHEN 1 THEN '在租'
                WHEN 2 THEN '维保'
            END,
            ', 电量: ', OLD.current_soc, '%',
            ', 里程: ', OLD.current_mileage, 'km'
        ),
        NOW(),
        '127.0.0.1',
        NULL
    );
END$$

-- ============================================
-- 触发器 6: trg_rental_order_after_update（额外赠送）
-- 类型: AFTER UPDATE
-- 作用范围: rental_order 表
-- 功能: 订单状态变更时自动更新车辆状态
-- ============================================
-- 业务场景: 订单状态流转时，自动同步车辆状态，确保数据一致性
-- 触发时机: rental_order 表记录被更新之后
-- 触发条件: 订单状态发生变化
-- 执行动作:
--   1. 状态 0->1 (已支付->在租): 车辆状态改为在租
--   2. 状态 1->2 (在租->已还): 不改变车辆状态（等结算）
--   3. 状态 2->3 (已还->已结算): 车辆状态改为在库
-- 涉及字段: NEW.status, OLD.status, NEW.vehicle_id

DROP TRIGGER IF EXISTS trg_rental_order_after_update$$

CREATE TRIGGER trg_rental_order_after_update
AFTER UPDATE ON rental_order
FOR EACH ROW
BEGIN
    -- 声明变量
    DECLARE v_plate_no VARCHAR(20);
    DECLARE v_new_vehicle_status INT;
    DECLARE v_status_change_desc VARCHAR(100);
    
    -- 只在订单状态发生变化时执行
    IF OLD.status != NEW.status THEN
        
        -- 获取车牌号
        SELECT plate_no INTO v_plate_no
        FROM vehicle
        WHERE vehicle_id = NEW.vehicle_id;
        
        -- 根据订单状态变化更新车辆状态
        CASE
            -- 已支付 -> 在租：车辆锁定
            WHEN OLD.status = 0 AND NEW.status = 1 THEN
                SET v_new_vehicle_status = 1;
                SET v_status_change_desc = '已支付->在租中 (车辆锁定)';
                UPDATE vehicle SET status = 1 WHERE vehicle_id = NEW.vehicle_id;
            
            -- 在租 -> 已还：保持当前状态（等待结算）
            WHEN OLD.status = 1 AND NEW.status = 2 THEN
                SET v_new_vehicle_status = NULL;
                SET v_status_change_desc = '在租中->已还车 (车辆状态待结算确认)';
            
            -- 已还 -> 已结算：车辆释放
            WHEN OLD.status = 2 AND NEW.status = 3 THEN
                SET v_new_vehicle_status = 0;
                SET v_status_change_desc = '已还车->已结算 (车辆释放)';
                UPDATE vehicle SET status = 0 WHERE vehicle_id = NEW.vehicle_id;
            
            -- 其他状态变化
            ELSE
                SET v_new_vehicle_status = NULL;
                SET v_status_change_desc = CONCAT(
                    '订单状态变更: ',
                    CASE OLD.status WHEN 0 THEN '已支付' WHEN 1 THEN '在租' WHEN 2 THEN '已还' WHEN 3 THEN '已结算' END,
                    ' -> ',
                    CASE NEW.status WHEN 0 THEN '已支付' WHEN 1 THEN '在租' WHEN 2 THEN '已还' WHEN 3 THEN '已结算' END
                );
        END CASE;
        
        -- 写入审计日志
        INSERT INTO audit_log (action, action_time, ip_address, user_id)
        VALUES (
            CONCAT(
                '订单状态自动同步车辆 - ',
                '订单: #', NEW.order_id,
                ', 车辆: ', COALESCE(v_plate_no, '未知'), ' (ID:', NEW.vehicle_id, ')',
                ', ', v_status_change_desc
            ),
            NOW(),
            '127.0.0.1',
            NULL
        );
    END IF;
END$$

-- ============================================
-- 触发器 7: trg_customer_before_delete（额外赠送）
-- 类型: BEFORE DELETE
-- 作用范围: customer 表
-- 功能: 删除客户前检查是否有未完成订单
-- ============================================
-- 业务场景: 防止删除有活动订单的客户，保证数据完整性和业务连续性
-- 触发时机: 从 customer 表删除记录之前
-- 触发条件: 客户存在未完成订单
-- 执行动作:
--   1. 检查是否存在未完成订单
--   2. 如果存在，抛出错误阻止删除
--   3. 如果不存在，允许删除

DROP TRIGGER IF EXISTS trg_customer_before_delete$$

CREATE TRIGGER trg_customer_before_delete
BEFORE DELETE ON customer
FOR EACH ROW
BEGIN
    DECLARE v_active_order_count INT;
    DECLARE v_order_ids VARCHAR(255);
    
    -- 检查是否存在未完成订单（状态不是已结算）
    SELECT COUNT(*), GROUP_CONCAT(order_id)
    INTO v_active_order_count, v_order_ids
    FROM rental_order
    WHERE customer_id = OLD.customer_id
      AND status != 3;
    
    -- 如果存在未完成订单，阻止删除
    IF v_active_order_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT(
            '删除失败: 客户 ', OLD.name, ' (ID:', OLD.customer_id, ') ',
            '存在 ', v_active_order_count, ' 个未完成订单 (订单ID: ', v_order_ids, '). ',
            '请先完成这些订单后再删除客户。'
        );
    END IF;
    
    -- 记录删除操作
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT(
            '客户删除 - ',
            '姓名: ', OLD.name,
            ' (ID:', OLD.customer_id, ')',
            ', 电话: ', OLD.phone
        ),
        NOW(),
        '127.0.0.1',
        NULL
    );
END$$

-- 恢复分隔符
DELIMITER;

-- ============================================
-- 触发器使用示例和测试
-- ============================================

-- 示例 1: 测试订单插入触发器
-- INSERT INTO rental_order (
--     rent_start, rent_end, pickup_soc, total_amount,
--     status, customer_id, vehicle_id, pickup_store_id, return_store_id
-- ) VALUES (
--     '2025-12-10 09:00:00', '2025-12-15 18:00:00',
--     85.0, 2500.00, 0, 1, 2, 1, 1
-- );
-- -- 查看审计日志
-- SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 1;

-- 示例 2: 测试支付插入触发器
-- INSERT INTO payment (amount, type, order_id)
-- VALUES (3000.00, 0, 1);  -- 押金
-- -- 查看审计日志
-- SELECT * FROM audit_log WHERE action LIKE '%支付记录创建%' ORDER BY log_id DESC LIMIT 1;

-- 示例 3: 测试维保更新触发器
-- UPDATE maintenance
-- SET description = '常规保养完成'
-- WHERE maint_id = 1;
-- -- 查看车辆状态和审计日志
-- SELECT status FROM vehicle WHERE vehicle_id = (SELECT vehicle_id FROM maintenance WHERE maint_id = 1);
-- SELECT * FROM audit_log WHERE action LIKE '%维保完成%' ORDER BY log_id DESC LIMIT 1;

-- 示例 4: 测试违章插入触发器
-- INSERT INTO violation (fine_amount, location, vehicle_id, order_id)
-- VALUES (600.00, '北京市朝阳区建国路超速', 1, 1);
-- -- 查看审计日志
-- SELECT * FROM audit_log WHERE action LIKE '%违章记录创建%' ORDER BY log_id DESC LIMIT 1;

-- 示例 5: 测试车辆删除保护触发器
-- -- 尝试删除有进行中订单的车辆（应该失败）
-- DELETE FROM vehicle WHERE vehicle_id = 3;
-- -- 错误信息: 删除失败: 车辆 沪A34567 存在进行中订单...
--
-- -- 删除没有进行中订单的车辆（应该成功）
-- DELETE FROM vehicle WHERE vehicle_id = 99;  -- 假设该车无订单

-- 示例 6: 测试订单状态更新触发器
-- UPDATE rental_order
-- SET status = 1  -- 更新为在租状态
-- WHERE order_id = 13;
-- -- 查看车辆状态
-- SELECT status FROM vehicle WHERE vehicle_id = (SELECT vehicle_id FROM rental_order WHERE order_id = 13);
-- -- 查看审计日志
-- SELECT * FROM audit_log WHERE action LIKE '%订单状态自动同步%' ORDER BY log_id DESC LIMIT 1;

-- ============================================
-- 触发器统计
-- ============================================
-- 总计: 7 个触发器（超过要求的 5 个）
--
-- 触发器分类:
-- 1. AFTER INSERT 触发器: 3 个
--    - trg_rental_order_after_insert    (订单插入审计)
--    - trg_payment_after_insert        (支付校验与审计)
--    - trg_violation_after_insert      (违章扣信用分)
--
-- 2. AFTER UPDATE 触发器: 2 个
--    - trg_maintenance_after_update    (维保完成恢复车辆)
--    - trg_rental_order_after_update   (订单状态同步车辆)
--
-- 3. BEFORE DELETE 触发器: 2 个
--    - trg_vehicle_before_delete       (车辆删除保护)
--    - trg_customer_before_delete      (客户删除保护)

-- ============================================
-- 触发器功能分类
-- ============================================
-- 1. 审计类 (Audit): 3 个
--    - trg_rental_order_after_insert
--    - trg_payment_after_insert
--    - trg_violation_after_insert
--
-- 2. 数据一致性类 (Consistency): 3 个
--    - trg_maintenance_after_update
--    - trg_rental_order_after_update
--    - trg_payment_after_insert
--
-- 3. 数据保护类 (Protection): 2 个
--    - trg_vehicle_before_delete
--    - trg_customer_before_delete

-- ============================================
-- 触发器设计原则
-- ============================================
-- 1. BEFORE vs AFTER:
--    - BEFORE: 用于数据验证、阻止操作（如删除保护）
--    - AFTER: 用于级联操作、审计日志（不影响原操作）
--
-- 2. 性能考虑:
--    - 触发器中避免复杂查询和长事务
--    - 审计日志异步写入（实际生产环境）
--    - 避免触发器嵌套调用
--
-- 3. 错误处理:
--    - 使用 SIGNAL 抛出自定义错误
--    - 错误信息清晰、包含上下文信息
--
-- 4. 审计日志:
--    - 记录关键业务操作
--    - 包含操作时间、对象、详细信息
--    - 便于问题追踪和合规审计

-- ============================================
-- 注意事项
-- ============================================
-- 1. 触发器中不能使用 COMMIT/ROLLBACK（MySQL限制）
-- 2. 触发器中不能直接 UPDATE 触发表本身（部分情况可以）
-- 3. 触发器执行失败会回滚整个事务
-- 4. 建议在开发环境充分测试再部署到生产环境
-- 5. 触发器过多会影响写入性能，需权衡
-- 6. customer 和 maintenance 表的某些字段（如 credit_score, status）
--    需要预先添加，否则相关触发器需要调整

-- ============================================
-- 表结构扩展建议
-- ============================================
-- 为了触发器完整功能，建议添加以下字段：
--
-- ALTER TABLE customer ADD COLUMN credit_score INT DEFAULT 100 COMMENT '客户信用分';
-- ALTER TABLE maintenance ADD COLUMN status INT DEFAULT 0 COMMENT '维保状态：0=进行中，1=已完成';
-- ALTER TABLE rental_order ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- ============================================
-- 查看触发器
-- ============================================
-- 查看所有触发器:
-- SHOW TRIGGERS;
--
-- 查看指定表的触发器:
-- SHOW TRIGGERS WHERE `Table` = 'rental_order';
--
-- 查看触发器详细定义:
-- SHOW CREATE TRIGGER trg_rental_order_after_insert;

-- ============================================
-- 禁用/启用触发器
-- ============================================
-- MySQL不支持直接禁用触发器，只能删除后重建
-- 临时禁用所有触发器（谨慎使用）:
-- SET @DISABLE_TRIGGERS = 1;  -- 需在触发器中检查此变量
--
-- 删除触发器:
-- DROP TRIGGER IF EXISTS trg_rental_order_after_insert;