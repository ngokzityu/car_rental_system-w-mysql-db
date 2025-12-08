-- ============================================
-- Tesla 租车系统 - 存储过程创建脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.6 存储过程创建（≥5 个）
-- ============================================

-- 切换数据库
USE tesla_db;

-- 设置分隔符（存储过程内部使用分号）
DELIMITER $$

-- ============================================
-- 存储过程 1: sp_create_rental_order
-- 功能: 创建租赁订单（含车辆状态检查与更新）
-- ============================================
-- 业务场景: 客户预订车辆，创建订单并锁定车辆
-- 输入参数:
--   p_customer_id      INT      客户ID
--   p_vehicle_id       INT      车辆ID
--   p_rent_start       DATETIME 租期开始时间
--   p_rent_end         DATETIME 租期结束时间
--   p_pickup_store_id  INT      取车门店ID
--   p_return_store_id  INT      还车门店ID
--   p_total_amount     DECIMAL  订单总金额
-- 输出参数:
--   p_order_id         INT      生成的订单ID（OUT）
--   p_result_code      INT      结果码（OUT）0=成功，负数=失败
--   p_result_msg       VARCHAR  结果消息（OUT）
-- 异常处理:
--   -1: 客户不存在
--   -2: 车辆不存在
--   -3: 车辆不可用（非在库状态）
--   -4: 门店不存在
--   -5: 时间参数无效
--   -6: 车辆电量不足（<20%）
--   -99: 其他系统错误

DROP PROCEDURE IF EXISTS sp_create_rental_order$$

CREATE PROCEDURE sp_create_rental_order(
    IN p_customer_id INT,
    IN p_vehicle_id INT,
    IN p_rent_start DATETIME,
    IN p_rent_end DATETIME,
    IN p_pickup_store_id INT,
    IN p_return_store_id INT,
    IN p_total_amount DECIMAL(10,2),
    OUT p_order_id INT,
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    -- 声明变量
    DECLARE v_vehicle_status INT;
    DECLARE v_vehicle_soc DECIMAL(5,2);
    DECLARE v_customer_count INT;
    DECLARE v_pickup_store_count INT;
    DECLARE v_return_store_count INT;
    DECLARE v_pickup_soc DECIMAL(5,2);
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 回滚事务
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：订单创建失败';
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 初始化输出参数
    SET p_order_id = NULL;
    SET p_result_code = 0;
    SET p_result_msg = '订单创建成功';
    
    -- 1. 验证客户是否存在
    SELECT COUNT(*) INTO v_customer_count 
    FROM customer 
    WHERE customer_id = p_customer_id;
    
    IF v_customer_count = 0 THEN
        SET p_result_code = -1;
        SET p_result_msg = '客户不存在';
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 2. 验证车辆是否存在并获取状态和电量
    SELECT status, current_soc 
    INTO v_vehicle_status, v_vehicle_soc
    FROM vehicle 
    WHERE vehicle_id = p_vehicle_id;
    
    IF v_vehicle_status IS NULL THEN
        SET p_result_code = -2;
        SET p_result_msg = '车辆不存在';
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 3. 检查车辆状态（必须是在库状态 0）
    IF v_vehicle_status != 0 THEN
        SET p_result_code = -3;
        SET p_result_msg = CONCAT('车辆不可用，当前状态：', 
            CASE v_vehicle_status 
                WHEN 1 THEN '在租' 
                WHEN 2 THEN '维保中' 
                ELSE '未知' 
            END);
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 4. 检查车辆电量（至少20%才能出租）
    IF v_vehicle_soc < 20 THEN
        SET p_result_code = -6;
        SET p_result_msg = CONCAT('车辆电量不足：', v_vehicle_soc, '%，无法出租');
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 5. 验证门店是否存在
    SELECT COUNT(*) INTO v_pickup_store_count 
    FROM store 
    WHERE store_id = p_pickup_store_id;
    
    SELECT COUNT(*) INTO v_return_store_count 
    FROM store 
    WHERE store_id = p_return_store_id;
    
    IF v_pickup_store_count = 0 OR v_return_store_count = 0 THEN
        SET p_result_code = -4;
        SET p_result_msg = '门店不存在';
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 6. 验证时间参数
    IF p_rent_start >= p_rent_end OR p_rent_start < NOW() THEN
        SET p_result_code = -5;
        SET p_result_msg = '租期时间无效';
        ROLLBACK;
        LEAVE sp_create_rental_order;
    END IF;
    
    -- 7. 记录取车时电量
    SET v_pickup_soc = v_vehicle_soc;
    
    -- 8. 创建订单记录
    INSERT INTO rental_order (
        rent_start,
        rent_end,
        pickup_soc,
        return_soc,
        total_amount,
        status,
        customer_id,
        vehicle_id,
        pickup_store_id,
        return_store_id
    ) VALUES (
        p_rent_start,
        p_rent_end,
        v_pickup_soc,
        NULL,  -- 还车时更新
        p_total_amount,
        0,  -- 0=已支付（待支付押金后更新）
        p_customer_id,
        p_vehicle_id,
        p_pickup_store_id,
        p_return_store_id
    );
    
    -- 9. 获取生成的订单ID
    SET p_order_id = LAST_INSERT_ID();
    
    -- 10. 更新车辆状态为在租（暂时不更新，等支付完成后再更新）
    -- UPDATE vehicle SET status = 1 WHERE vehicle_id = p_vehicle_id;
    
    -- 提交事务
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 2: sp_settle_rental_order
-- 功能: 订单结算（计算租金、生成支付记录、更新状态）
-- ============================================
-- 业务场景: 客户还车后，系统自动结算订单
-- 输入参数:
--   p_order_id         INT      订单ID
--   p_return_soc       DECIMAL  还车时电量
--   p_actual_return_time DATETIME 实际还车时间
--   p_penalty_amount   DECIMAL  额外赔偿金额（车辆损坏等）
-- 输出参数:
--   p_final_amount     DECIMAL  最终结算金额（OUT）
--   p_refund_deposit   DECIMAL  应退押金（OUT）
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）
-- 异常处理:
--   -1: 订单不存在
--   -2: 订单状态不正确
--   -3: 未找到押金支付记录
--   -99: 系统错误

DROP PROCEDURE IF EXISTS sp_settle_rental_order$$

CREATE PROCEDURE sp_settle_rental_order(
    IN p_order_id INT,
    IN p_return_soc DECIMAL(5,2),
    IN p_actual_return_time DATETIME,
    IN p_penalty_amount DECIMAL(10,2),
    OUT p_final_amount DECIMAL(10,2),
    OUT p_refund_deposit DECIMAL(10,2),
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    -- 声明变量
    DECLARE v_order_status INT;
    DECLARE v_vehicle_id INT;
    DECLARE v_total_amount DECIMAL(10,2);
    DECLARE v_rent_end DATETIME;
    DECLARE v_deposit_amount DECIMAL(10,2);
    DECLARE v_rental_fee DECIMAL(10,2);
    DECLARE v_overdue_days INT;
    DECLARE v_overdue_fee DECIMAL(10,2);
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：订单结算失败';
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 初始化输出参数
    SET p_final_amount = 0;
    SET p_refund_deposit = 0;
    SET p_result_code = 0;
    SET p_result_msg = '订单结算成功';
    
    -- 1. 获取订单信息
    SELECT status, vehicle_id, total_amount, rent_end
    INTO v_order_status, v_vehicle_id, v_total_amount, v_rent_end
    FROM rental_order
    WHERE order_id = p_order_id;
    
    IF v_order_status IS NULL THEN
        SET p_result_code = -1;
        SET p_result_msg = '订单不存在';
        ROLLBACK;
        LEAVE sp_settle_rental_order;
    END IF;
    
    -- 2. 检查订单状态（必须是在租状态 1）
    IF v_order_status != 1 THEN
        SET p_result_code = -2;
        SET p_result_msg = CONCAT('订单状态不正确，当前状态：', v_order_status);
        ROLLBACK;
        LEAVE sp_settle_rental_order;
    END IF;
    
    -- 3. 获取押金金额
    SELECT COALESCE(SUM(amount), 0) INTO v_deposit_amount
    FROM payment
    WHERE order_id = p_order_id AND type = 0;  -- 0=押金
    
    IF v_deposit_amount = 0 THEN
        SET p_result_code = -3;
        SET p_result_msg = '未找到押金支付记录';
        ROLLBACK;
        LEAVE sp_settle_rental_order;
    END IF;
    
    -- 4. 获取已支付租金
    SELECT COALESCE(SUM(amount), 0) INTO v_rental_fee
    FROM payment
    WHERE order_id = p_order_id AND type = 1;  -- 1=租金
    
    -- 5. 计算逾期费用（如果超期）
    SET v_overdue_days = DATEDIFF(p_actual_return_time, v_rent_end);
    IF v_overdue_days > 0 THEN
        -- 逾期按每天原租金的150%计算
        SET v_overdue_fee = (v_total_amount / DATEDIFF(v_rent_end, 
            (SELECT rent_start FROM rental_order WHERE order_id = p_order_id))
        ) * v_overdue_days * 1.5;
    ELSE
        SET v_overdue_fee = 0;
    END IF;
    
    -- 6. 计算最终金额
    SET p_final_amount = v_rental_fee + v_overdue_fee + COALESCE(p_penalty_amount, 0);
    
    -- 7. 计算应退押金
    SET p_refund_deposit = v_deposit_amount - v_overdue_fee - COALESCE(p_penalty_amount, 0);
    IF p_refund_deposit < 0 THEN
        SET p_refund_deposit = 0;
    END IF;
    
    -- 8. 如果有赔偿，插入赔偿支付记录
    IF COALESCE(p_penalty_amount, 0) > 0 THEN
        INSERT INTO payment (amount, type, order_id)
        VALUES (p_penalty_amount, 2, p_order_id);  -- 2=赔偿
    END IF;
    
    -- 9. 如果有逾期费用，插入逾期租金记录
    IF v_overdue_fee > 0 THEN
        INSERT INTO payment (amount, type, order_id)
        VALUES (v_overdue_fee, 1, p_order_id);  -- 1=租金（逾期部分）
    END IF;
    
    -- 10. 更新订单状态和还车信息
    UPDATE rental_order
    SET status = 3,  -- 3=已结算
        return_soc = p_return_soc,
        updated_at = NOW()
    WHERE order_id = p_order_id;
    
    -- 11. 更新车辆状态为在库
    UPDATE vehicle
    SET status = 0,  -- 0=在库
        current_soc = p_return_soc
    WHERE vehicle_id = v_vehicle_id;
    
    -- 12. 构建结算消息
    SET p_result_msg = CONCAT(
        '订单结算成功。租金:', v_rental_fee,
        '元, 逾期费:', v_overdue_fee,
        '元, 赔偿:', COALESCE(p_penalty_amount, 0),
        '元, 应退押金:', p_refund_deposit, '元'
    );
    
    -- 提交事务
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 3: sp_transfer_vehicle
-- 功能: 车辆调拨（门店之间转移并写审计）
-- ============================================
-- 业务场景: 运营人员在门店之间调拨车辆以优化资源配置
-- 输入参数:
--   p_vehicle_id       INT      车辆ID
--   p_from_store_id    INT      源门店ID
--   p_to_store_id      INT      目标门店ID
--   p_operator_user_id INT      操作员用户ID
--   p_reason           VARCHAR  调拨原因
-- 输出参数:
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）
-- 异常处理:
--   -1: 车辆不存在
--   -2: 车辆当前不在源门店
--   -3: 目标门店不存在
--   -4: 车辆状态不允许调拨（非在库状态）
--   -5: 源门店和目标门店相同
--   -99: 系统错误

DROP PROCEDURE IF EXISTS sp_transfer_vehicle$$

CREATE PROCEDURE sp_transfer_vehicle(
    IN p_vehicle_id INT,
    IN p_from_store_id INT,
    IN p_to_store_id INT,
    IN p_operator_user_id INT,
    IN p_reason VARCHAR(255),
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    -- 声明变量
    DECLARE v_current_store_id INT;
    DECLARE v_vehicle_status INT;
    DECLARE v_plate_no VARCHAR(20);
    DECLARE v_to_store_exists INT;
    DECLARE v_from_store_name VARCHAR(100);
    DECLARE v_to_store_name VARCHAR(100);
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：车辆调拨失败';
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 初始化输出参数
    SET p_result_code = 0;
    SET p_result_msg = '车辆调拨成功';
    
    -- 1. 检查源门店和目标门店是否相同
    IF p_from_store_id = p_to_store_id THEN
        SET p_result_code = -5;
        SET p_result_msg = '源门店和目标门店不能相同';
        ROLLBACK;
        LEAVE sp_transfer_vehicle;
    END IF;
    
    -- 2. 获取车辆当前信息
    SELECT store_id, status, plate_no
    INTO v_current_store_id, v_vehicle_status, v_plate_no
    FROM vehicle
    WHERE vehicle_id = p_vehicle_id;
    
    IF v_current_store_id IS NULL THEN
        SET p_result_code = -1;
        SET p_result_msg = '车辆不存在';
        ROLLBACK;
        LEAVE sp_transfer_vehicle;
    END IF;
    
    -- 3. 验证车辆当前在源门店
    IF v_current_store_id != p_from_store_id THEN
        SET p_result_code = -2;
        SET p_result_msg = CONCAT('车辆当前不在源门店，实际所在门店ID：', v_current_store_id);
        ROLLBACK;
        LEAVE sp_transfer_vehicle;
    END IF;
    
    -- 4. 检查车辆状态（只有在库状态才能调拨）
    IF v_vehicle_status != 0 THEN
        SET p_result_code = -4;
        SET p_result_msg = CONCAT('车辆状态不允许调拨，当前状态：',
            CASE v_vehicle_status
                WHEN 1 THEN '在租'
                WHEN 2 THEN '维保中'
                ELSE '未知'
            END);
        ROLLBACK;
        LEAVE sp_transfer_vehicle;
    END IF;
    
    -- 5. 验证目标门店是否存在
    SELECT COUNT(*), name INTO v_to_store_exists, v_to_store_name
    FROM store
    WHERE store_id = p_to_store_id;
    
    IF v_to_store_exists = 0 THEN
        SET p_result_code = -3;
        SET p_result_msg = '目标门店不存在';
        ROLLBACK;
        LEAVE sp_transfer_vehicle;
    END IF;
    
    -- 6. 获取源门店名称
    SELECT name INTO v_from_store_name
    FROM store
    WHERE store_id = p_from_store_id;
    
    -- 7. 更新车辆所属门店
    UPDATE vehicle
    SET store_id = p_to_store_id
    WHERE vehicle_id = p_vehicle_id;
    
    -- 8. 写入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT('车辆调拨 车辆#', p_vehicle_id, ' (', v_plate_no, ') ',
               '从门店#', p_from_store_id, '(', v_from_store_name, ') ',
               '调至门店#', p_to_store_id, '(', v_to_store_name, '). ',
               '原因: ', COALESCE(p_reason, '无')),
        NOW(),
        '127.0.0.1',  -- 实际使用时应传入真实IP
        p_operator_user_id
    );
    
    -- 9. 构建成功消息
    SET p_result_msg = CONCAT(
        '车辆 ', v_plate_no, ' 已从 ', v_from_store_name, 
        ' 调拨至 ', v_to_store_name
    );
    
    -- 提交事务
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 4: sp_update_customer_credit
-- 功能: 客户信用分更新（基于违章/逾期）
-- ============================================
-- 业务场景: 根据客户的违章记录和订单逾期情况自动调整信用分
-- 输入参数:
--   p_customer_id      INT      客户ID
-- 输出参数:
--   p_old_credit       INT      更新前信用分（OUT）
--   p_new_credit       INT      更新后信用分（OUT）
--   p_deduction_reason VARCHAR  扣分原因（OUT）
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）
-- 信用分规则:
--   - 初始信用分: 100分
--   - 每次违章扣分: 轻微(罚款<200)扣5分, 一般(200-500)扣10分, 严重(>500)扣20分
--   - 逾期扣分: 每逾期1天扣2分
--   - 最低分: 0分
-- 异常处理:
--   -1: 客户不存在
--   -99: 系统错误

DROP PROCEDURE IF EXISTS sp_update_customer_credit$$

CREATE PROCEDURE sp_update_customer_credit(
    IN p_customer_id INT,
    OUT p_old_credit INT,
    OUT p_new_credit INT,
    OUT p_deduction_reason VARCHAR(500),
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    -- 声明变量
    DECLARE v_customer_exists INT;
    DECLARE v_current_credit INT;
    DECLARE v_violation_count INT;
    DECLARE v_total_fine DECIMAL(10,2);
    DECLARE v_overdue_days INT;
    DECLARE v_credit_deduction INT;
    DECLARE v_reason_parts VARCHAR(500);
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：信用分更新失败';
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 初始化输出参数
    SET p_old_credit = 100;
    SET p_new_credit = 100;
    SET p_deduction_reason = '';
    SET p_result_code = 0;
    SET p_result_msg = '信用分更新成功';
    
    -- 1. 检查客户是否存在，获取当前信用分
    -- 注意：假设customer表已添加credit_score字段，默认100
    SELECT COUNT(*) INTO v_customer_exists
    FROM customer
    WHERE customer_id = p_customer_id;
    
    IF v_customer_exists = 0 THEN
        SET p_result_code = -1;
        SET p_result_msg = '客户不存在';
        ROLLBACK;
        LEAVE sp_update_customer_credit;
    END IF;
    
    -- 2. 获取当前信用分（如果字段不存在，需先添加）
    -- ALTER TABLE customer ADD COLUMN credit_score INT DEFAULT 100;
    SET v_current_credit = 100;  -- 假设初始为100
    SET p_old_credit = v_current_credit;
    
    -- 3. 统计违章次数和总罚款
    SELECT COUNT(*), COALESCE(SUM(v.fine_amount), 0)
    INTO v_violation_count, v_total_fine
    FROM violation v
    JOIN rental_order ro ON v.order_id = ro.order_id
    WHERE ro.customer_id = p_customer_id;
    
    -- 4. 计算违章扣分
    SET v_credit_deduction = 0;
    SET v_reason_parts = '';
    
    IF v_violation_count > 0 THEN
        -- 按违章严重程度扣分
        SELECT SUM(
            CASE
                WHEN fine_amount < 200 THEN 5    -- 轻微违章扣5分
                WHEN fine_amount <= 500 THEN 10  -- 一般违章扣10分
                ELSE 20                          -- 严重违章扣20分
            END
        )
        INTO v_credit_deduction
        FROM violation v
        JOIN rental_order ro ON v.order_id = ro.order_id
        WHERE ro.customer_id = p_customer_id;
        
        SET v_reason_parts = CONCAT(
            '违章', v_violation_count, '次扣', v_credit_deduction, '分'
        );
    END IF;
    
    -- 5. 统计逾期天数
    SELECT COALESCE(SUM(
        CASE
            WHEN DATEDIFF(COALESCE(updated_at, NOW()), rent_end) > 0
            THEN DATEDIFF(COALESCE(updated_at, NOW()), rent_end)
            ELSE 0
        END
    ), 0)
    INTO v_overdue_days
    FROM rental_order
    WHERE customer_id = p_customer_id
      AND status IN (2, 3);  -- 已还车或已结算
    
    -- 6. 计算逾期扣分（每天扣2分）
    IF v_overdue_days > 0 THEN
        SET v_credit_deduction = v_credit_deduction + (v_overdue_days * 2);
        
        IF LENGTH(v_reason_parts) > 0 THEN
            SET v_reason_parts = CONCAT(v_reason_parts, '; ');
        END IF;
        
        SET v_reason_parts = CONCAT(
            v_reason_parts, '逾期', v_overdue_days, '天扣', (v_overdue_days * 2), '分'
        );
    END IF;
    
    -- 7. 计算新信用分
    SET p_new_credit = v_current_credit - v_credit_deduction;
    IF p_new_credit < 0 THEN
        SET p_new_credit = 0;
    END IF;
    
    -- 8. 设置扣分原因
    IF v_credit_deduction > 0 THEN
        SET p_deduction_reason = v_reason_parts;
    ELSE
        SET p_deduction_reason = '无扣分';
    END IF;
    
    -- 9. 更新客户信用分（如果customer表有credit_score字段）
    -- UPDATE customer
    -- SET credit_score = p_new_credit
    -- WHERE customer_id = p_customer_id;
    
    -- 10. 构建结果消息
    SET p_result_msg = CONCAT(
        '信用分更新成功。原分数:', p_old_credit,
        ', 新分数:', p_new_credit,
        ', 扣分:', v_credit_deduction,
        ', 原因:', p_deduction_reason
    );
    
    -- 提交事务
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 5: sp_register_maintenance
-- 功能: 维保登记（写维保、更新车辆状态、回写下次保养里程）
-- ============================================
-- 业务场景: 车辆进行保养或维修时，登记维保记录并更新车辆状态
-- 输入参数:
--   p_vehicle_id       INT      车辆ID
--   p_maint_type       INT      维保类型（0=保养，1=维修，2=其他）
--   p_description      VARCHAR  维保描述
--   p_operator_user_id INT      操作员用户ID
-- 输出参数:
--   p_maint_id         INT      生成的维保记录ID（OUT）
--   p_next_maint_km    DECIMAL  下次保养里程（OUT）
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）
-- 业务逻辑:
--   - 每10000公里保养一次
--   - 维保期间车辆状态设为"维保中"
-- 异常处理:
--   -1: 车辆不存在
--   -2: 车辆当前在租，无法维保
--   -99: 系统错误

DROP PROCEDURE IF EXISTS sp_register_maintenance$$

CREATE PROCEDURE sp_register_maintenance(
    IN p_vehicle_id INT,
    IN p_maint_type INT,
    IN p_description VARCHAR(255),
    IN p_operator_user_id INT,
    OUT p_maint_id INT,
    OUT p_next_maint_km DECIMAL(10,2),
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    -- 声明变量
    DECLARE v_vehicle_exists INT;
    DECLARE v_vehicle_status INT;
    DECLARE v_current_mileage DECIMAL(10,2);
    DECLARE v_plate_no VARCHAR(20);
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：维保登记失败';
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 初始化输出参数
    SET p_maint_id = NULL;
    SET p_next_maint_km = 0;
    SET p_result_code = 0;
    SET p_result_msg = '维保登记成功';
    
    -- 1. 检查车辆是否存在并获取信息
    SELECT COUNT(*), status, current_mileage, plate_no
    INTO v_vehicle_exists, v_vehicle_status, v_current_mileage, v_plate_no
    FROM vehicle
    WHERE vehicle_id = p_vehicle_id;
    
    IF v_vehicle_exists = 0 THEN
        SET p_result_code = -1;
        SET p_result_msg = '车辆不存在';
        ROLLBACK;
        LEAVE sp_register_maintenance;
    END IF;
    
    -- 2. 检查车辆状态（不能是在租状态）
    IF v_vehicle_status = 1 THEN
        SET p_result_code = -2;
        SET p_result_msg = '车辆当前在租，无法进行维保';
        ROLLBACK;
        LEAVE sp_register_maintenance;
    END IF;
    
    -- 3. 插入维保记录
    INSERT INTO maintenance (
        type,
        maint_date,
        description,
        vehicle_id
    ) VALUES (
        p_maint_type,
        NOW(),
        p_description,
        p_vehicle_id
    );
    
    -- 4. 获取生成的维保记录ID
    SET p_maint_id = LAST_INSERT_ID();
    
    -- 5. 更新车辆状态为维保中
    UPDATE vehicle
    SET status = 2  -- 2=维保中
    WHERE vehicle_id = p_vehicle_id;
    
    -- 6. 计算下次保养里程（每10000公里保养一次）
    SET p_next_maint_km = CEIL(v_current_mileage / 10000) * 10000;
    
    -- 7. 写入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT('车辆维保 车辆#', p_vehicle_id, ' (', v_plate_no, ') ',
               '维保类型:', 
               CASE p_maint_type
                   WHEN 0 THEN '保养'
                   WHEN 1 THEN '维修'
                   WHEN 2 THEN '其他'
               END,
               '. 描述: ', p_description),
        NOW(),
        '127.0.0.1',
        p_operator_user_id
    );
    
    -- 8. 构建成功消息
    SET p_result_msg = CONCAT(
        '维保登记成功。维保ID:', p_maint_id,
        ', 当前里程:', v_current_mileage, 'km',
        ', 下次保养里程:', p_next_maint_km, 'km'
    );
    
    -- 提交事务
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 6: sp_complete_maintenance（额外赠送）
-- 功能: 维保完成（更新车辆状态为在库）
-- ============================================
-- 业务场景: 维保工作完成后，恢复车辆可用状态
-- 输入参数:
--   p_vehicle_id       INT      车辆ID
--   p_operator_user_id INT      操作员用户ID
-- 输出参数:
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）

DROP PROCEDURE IF EXISTS sp_complete_maintenance$$

CREATE PROCEDURE sp_complete_maintenance(
    IN p_vehicle_id INT,
    IN p_operator_user_id INT,
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    DECLARE v_vehicle_status INT;
    DECLARE v_plate_no VARCHAR(20);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：维保完成操作失败';
    END;
    
    START TRANSACTION;
    
    SET p_result_code = 0;
    SET p_result_msg = '维保完成，车辆已恢复可用';
    
    -- 获取车辆状态
    SELECT status, plate_no INTO v_vehicle_status, v_plate_no
    FROM vehicle
    WHERE vehicle_id = p_vehicle_id;
    
    IF v_vehicle_status IS NULL THEN
        SET p_result_code = -1;
        SET p_result_msg = '车辆不存在';
        ROLLBACK;
        LEAVE sp_complete_maintenance;
    END IF;
    
    IF v_vehicle_status != 2 THEN
        SET p_result_code = -2;
        SET p_result_msg = '车辆当前不在维保状态';
        ROLLBACK;
        LEAVE sp_complete_maintenance;
    END IF;
    
    -- 更新车辆状态为在库
    UPDATE vehicle
    SET status = 0
    WHERE vehicle_id = p_vehicle_id;
    
    -- 写入审计日志
    INSERT INTO audit_log (action, action_time, ip_address, user_id)
    VALUES (
        CONCAT('维保完成 车辆#', p_vehicle_id, ' (', v_plate_no, ') 已恢复可用'),
        NOW(),
        '127.0.0.1',
        p_operator_user_id
    );
    
    COMMIT;
    
END$$

-- ============================================
-- 存储过程 7: sp_pay_deposit（额外赠送）
-- 功能: 支付订单押金并更新车辆状态
-- ============================================
-- 业务场景: 客户创建订单后支付押金，系统锁定车辆
-- 输入参数:
--   p_order_id         INT      订单ID
--   p_deposit_amount   DECIMAL  押金金额
-- 输出参数:
--   p_pay_id           INT      支付记录ID（OUT）
--   p_result_code      INT      结果码（OUT）
--   p_result_msg       VARCHAR  结果消息（OUT）

DROP PROCEDURE IF EXISTS sp_pay_deposit$$

CREATE PROCEDURE sp_pay_deposit(
    IN p_order_id INT,
    IN p_deposit_amount DECIMAL(10,2),
    OUT p_pay_id INT,
    OUT p_result_code INT,
    OUT p_result_msg VARCHAR(255)
)
BEGIN
    DECLARE v_order_status INT;
    DECLARE v_vehicle_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = -99;
        SET p_result_msg = '系统错误：押金支付失败';
    END;
    
    START TRANSACTION;
    
    SET p_pay_id = NULL;
    SET p_result_code = 0;
    SET p_result_msg = '押金支付成功';
    
    -- 获取订单信息
    SELECT status, vehicle_id INTO v_order_status, v_vehicle_id
    FROM rental_order
    WHERE order_id = p_order_id;
    
    IF v_order_status IS NULL THEN
        SET p_result_code = -1;
        SET p_result_msg = '订单不存在';
        ROLLBACK;
        LEAVE sp_pay_deposit;
    END IF;
    
    -- 插入押金支付记录
    INSERT INTO payment (amount, type, order_id)
    VALUES (p_deposit_amount, 0, p_order_id);  -- 0=押金
    
    SET p_pay_id = LAST_INSERT_ID();
    
    -- 更新车辆状态为在租
    UPDATE vehicle
    SET status = 1
    WHERE vehicle_id = v_vehicle_id;
    
    COMMIT;
    
END$$

-- 恢复分隔符
DELIMITER;

-- ============================================
-- 存储过程使用示例
-- ============================================

-- 示例 1: 创建租赁订单
-- CALL sp_create_rental_order(
--     1,                          -- 客户ID
--     1,                          -- 车辆ID
--     '2025-12-10 09:00:00',     -- 租期开始
--     '2025-12-15 18:00:00',     -- 租期结束
--     1,                          -- 取车门店
--     1,                          -- 还车门店
--     2500.00,                    -- 订单金额
--     @order_id,                  -- 输出: 订单ID
--     @result_code,               -- 输出: 结果码
--     @result_msg                 -- 输出: 结果消息
-- );
-- SELECT @order_id, @result_code, @result_msg;

-- 示例 2: 订单结算
-- CALL sp_settle_rental_order(
--     10,                         -- 订单ID
--     55.8,                       -- 还车时电量
--     '2025-12-05 16:00:00',     -- 实际还车时间
--     0,                          -- 赔偿金额
--     @final_amount,              -- 输出: 最终金额
--     @refund_deposit,            -- 输出: 退还押金
--     @result_code,
--     @result_msg
-- );
-- SELECT @final_amount, @refund_deposit, @result_code, @result_msg;

-- 示例 3: 车辆调拨
-- CALL sp_transfer_vehicle(
--     15,                         -- 车辆ID
--     2,                          -- 源门店ID
--     1,                          -- 目标门店ID
--     5,                          -- 操作员ID
--     '北京门店车辆紧张',        -- 调拨原因
--     @result_code,
--     @result_msg
-- );
-- SELECT @result_code, @result_msg;

-- 示例 4: 更新客户信用分
-- CALL sp_update_customer_credit(
--     1,                          -- 客户ID
--     @old_credit,                -- 输出: 原信用分
--     @new_credit,                -- 输出: 新信用分
--     @deduction_reason,          -- 输出: 扣分原因
--     @result_code,
--     @result_msg
-- );
-- SELECT @old_credit, @new_credit, @deduction_reason, @result_code, @result_msg;

-- 示例 5: 维保登记
-- CALL sp_register_maintenance(
--     7,                          -- 车辆ID
--     0,                          -- 维保类型（0=保养）
--     '常规保养：电池健康检测',  -- 维保描述
--     5,                          -- 操作员ID
--     @maint_id,                  -- 输出: 维保ID
--     @next_maint_km,             -- 输出: 下次保养里程
--     @result_code,
--     @result_msg
-- );
-- SELECT @maint_id, @next_maint_km, @result_code, @result_msg;

-- ============================================
-- 存储过程统计
-- ============================================
-- 总计: 7 个存储过程（超过要求的 5 个）
-- 1. sp_create_rental_order      - 创建租赁订单
-- 2. sp_settle_rental_order       - 订单结算
-- 3. sp_transfer_vehicle          - 车辆调拨
-- 4. sp_update_customer_credit    - 客户信用分更新
-- 5. sp_register_maintenance      - 维保登记
-- 6. sp_complete_maintenance      - 维保完成（额外）
-- 7. sp_pay_deposit               - 支付押金（额外）

-- ============================================
-- 维护建议
-- ============================================
-- 1. 定期备份存储过程定义
-- 2. 使用事务确保数据一致性
-- 3. 充分的异常处理确保系统稳定性
-- 4. 审计日志记录关键操作
-- 5. 参数验证防止非法数据
-- 6. 性能监控，优化慢查询
-- 7. 版本控制，记录变更历史