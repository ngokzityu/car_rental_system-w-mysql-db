-- ============================================
-- Tesla 租车系统 - 视图创建脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.4 视图创建，≥5 个业务视图
-- ============================================

-- ============================================
-- 视图 1: vw_active_orders - 在租订单详情视图
-- ============================================
-- 依赖表: rental_order, vehicle, car_model, customer, store (pickup/return)
-- 用途: 查询当前所有在租订单的完整信息，包含订单、车辆、客户、门店等关联数据
-- 业务场景:
--   - 门店工作人员查看当前在租车辆状态
--   - 客服查询客户当前租车信息
--   - 运营监控实时租赁业务状况
-- Java调用: SELECT * FROM vw_active_orders WHERE customer_id = ?

CREATE OR REPLACE VIEW vw_active_orders AS
SELECT
    -- 订单基本信息
    ro.order_id,
    ro.rent_start,
    ro.rent_end,
    ro.pickup_soc,
    ro.return_soc,
    ro.total_amount,
    ro.status AS order_status,
    CASE ro.status
        WHEN 0 THEN '已支付'
        WHEN 1 THEN '在租中'
        WHEN 2 THEN '已还车'
        WHEN 3 THEN '已结算'
        ELSE '未知'
    END AS order_status_desc,
    DATEDIFF(ro.rent_end, ro.rent_start) AS rental_days,

-- 车辆信息
v.vehicle_id,
v.plate_no,
v.current_soc,
v.current_mileage,
cm.name AS car_model_name,
cm.seat_count,
cm.battery_capacity,

-- 客户信息
c.customer_id,
c.name AS customer_name,
c.phone AS customer_phone,
c.id_card,
c.driver_license,

-- 取车门店信息
ps.store_id AS pickup_store_id,
ps.name AS pickup_store_name,
ps.address AS pickup_store_address,

-- 还车门店信息
rs.store_id AS return_store_id,
rs.name AS return_store_name,
rs.address AS return_store_address,

-- 租期状态判断
CASE
    WHEN NOW() < ro.rent_start THEN '未开始'
    WHEN NOW() BETWEEN ro.rent_start AND ro.rent_end  THEN '租期中'
    WHEN NOW() > ro.rent_end THEN '已超期'
END AS rental_period_status,
DATEDIFF(ro.rent_end, NOW()) AS days_remaining
FROM
    rental_order ro
    INNER JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
    INNER JOIN car_model cm ON v.model_id = cm.model_id
    INNER JOIN customer c ON ro.customer_id = c.customer_id
    INNER JOIN store ps ON ro.pickup_store_id = ps.store_id
    INNER JOIN store rs ON ro.return_store_id = rs.store_id
WHERE
    ro.status IN (0, 1);
-- 只显示已支付和在租中的订单

-- ============================================
-- 视图 2: vw_store_utilization - 门店车辆利用率统计视图
-- ============================================
-- 依赖表: store, vehicle, rental_order
-- 用途: 统计各门店的车辆总数、在租数量、利用率等关键运营指标
-- 业务场景:
--   - 运营部门监控各门店车辆利用率
--   - 管理层决策车辆调配和门店扩张
--   - 生成门店运营报表
-- Java调用: SELECT * FROM vw_store_utilization ORDER BY utilization_rate DESC

CREATE OR REPLACE VIEW vw_store_utilization AS
SELECT
    s.store_id,
    s.name AS store_name,
    s.address AS store_address,

-- 车辆数量统计
COUNT(DISTINCT v.vehicle_id) AS total_vehicles,
SUM(
    CASE
        WHEN v.status = 0 THEN 1
        ELSE 0
    END
) AS available_vehicles,
SUM(
    CASE
        WHEN v.status = 1 THEN 1
        ELSE 0
    END
) AS rented_vehicles,
SUM(
    CASE
        WHEN v.status = 2 THEN 1
        ELSE 0
    END
) AS maintenance_vehicles,

-- 利用率计算
ROUND(
    SUM(
        CASE
            WHEN v.status = 1 THEN 1
            ELSE 0
        END
    ) * 100.0 / NULLIF(
        COUNT(DISTINCT v.vehicle_id),
        0
    ),
    2
) AS utilization_rate,

-- 电量状态统计
ROUND(AVG(v.current_soc), 2) AS avg_battery_soc,
SUM(
    CASE
        WHEN v.current_soc < 20 THEN 1
        ELSE 0
    END
) AS low_battery_count,
SUM(
    CASE
        WHEN v.current_soc >= 80 THEN 1
        ELSE 0
    END
) AS full_battery_count,

-- 里程统计
ROUND(AVG(v.current_mileage), 2) AS avg_mileage,
MAX(v.current_mileage) AS max_mileage,

-- 订单统计（当前在租）
COUNT(
    DISTINCT CASE
        WHEN ro.status = 1 THEN ro.order_id
    END
) AS active_rental_count
FROM
    store s
    LEFT JOIN vehicle v ON s.store_id = v.store_id
    LEFT JOIN rental_order ro ON v.vehicle_id = ro.vehicle_id
    AND ro.status = 1
GROUP BY
    s.store_id,
    s.name,
    s.address;

-- ============================================
-- 视图 3: vw_customer_value - 客户价值统计视图
-- ============================================
-- 依赖表: customer, rental_order, payment, violation
-- 用途: 统计客户的订单数、累计消费、违章次数等价值指标
-- 业务场景:
--   - CRM系统识别高价值客户
--   - 营销部门制定差异化服务策略
--   - 信用评估和风控分析
-- Java调用: SELECT * FROM vw_customer_value WHERE total_spending > 10000 ORDER BY total_spending DESC

CREATE OR REPLACE VIEW vw_customer_value AS
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.phone AS customer_phone,
    c.id_card,
    c.driver_license,

-- 订单统计
COUNT(DISTINCT ro.order_id) AS total_orders,
SUM(
    CASE
        WHEN ro.status = 0 THEN 1
        ELSE 0
    END
) AS pending_orders,
SUM(
    CASE
        WHEN ro.status = 1 THEN 1
        ELSE 0
    END
) AS active_orders,
SUM(
    CASE
        WHEN ro.status = 3 THEN 1
        ELSE 0
    END
) AS completed_orders,

-- 租期统计
SUM(
    DATEDIFF(ro.rent_end, ro.rent_start)
) AS total_rental_days,
ROUND(
    AVG(
        DATEDIFF(ro.rent_end, ro.rent_start)
    ),
    2
) AS avg_rental_days,

-- 消费金额统计
SUM(ro.total_amount) AS total_order_amount,
COALESCE(SUM(p.amount), 0) AS total_paid_amount,
COALESCE(
    SUM(
        CASE
            WHEN p.type = 0 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS total_deposit,
COALESCE(
    SUM(
        CASE
            WHEN p.type = 1 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS total_rental_fee,
COALESCE(
    SUM(
        CASE
            WHEN p.type = 2 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS total_penalty,

-- 违章统计
COUNT(DISTINCT v.vio_id) AS violation_count,
COALESCE(SUM(v.fine_amount), 0) AS total_fine_amount,

-- 客户价值评级（基于消费金额）
CASE
    WHEN SUM(ro.total_amount) >= 20000 THEN 'VIP'
    WHEN SUM(ro.total_amount) >= 10000 THEN '高价值'
    WHEN SUM(ro.total_amount) >= 5000 THEN '中价值'
    WHEN SUM(ro.total_amount) > 0 THEN '普通'
    ELSE '新客户'
END AS customer_level,

-- 风险评估（基于违章）
CASE
    WHEN COUNT(DISTINCT v.vio_id) = 0 THEN '优秀'
    WHEN COUNT(DISTINCT v.vio_id) <= 2 THEN '良好'
    WHEN COUNT(DISTINCT v.vio_id) <= 5 THEN '一般'
    ELSE '风险'
END AS risk_level,

-- 最近订单时间
MAX(ro.rent_start) AS last_rental_date,
DATEDIFF(NOW(), MAX(ro.rent_start)) AS days_since_last_rental
FROM
    customer c
    LEFT JOIN rental_order ro ON c.customer_id = ro.customer_id
    LEFT JOIN payment p ON ro.order_id = p.order_id
    LEFT JOIN violation v ON ro.order_id = v.order_id
GROUP BY
    c.customer_id,
    c.name,
    c.phone,
    c.id_card,
    c.driver_license;

-- ============================================
-- 视图 4: vw_payment_summary - 订单支付汇总视图
-- ============================================
-- 依赖表: rental_order, payment, customer, vehicle
-- 用途: 汇总每个订单的支付明细，包括押金、租金、赔偿等
-- 业务场景:
--   - 财务对账和结算
--   - 订单支付状态查询
--   - 欠款和退款管理
-- Java调用: SELECT * FROM vw_payment_summary WHERE order_id = ?

CREATE OR REPLACE VIEW vw_payment_summary AS
SELECT
    ro.order_id,
    ro.rent_start,
    ro.rent_end,
    ro.total_amount AS order_total_amount,
    ro.status AS order_status,
    CASE ro.status
        WHEN 0 THEN '已支付'
        WHEN 1 THEN '在租中'
        WHEN 2 THEN '已还车'
        WHEN 3 THEN '已结算'
        ELSE '未知'
    END AS order_status_desc,

-- 客户信息
c.customer_id,
c.name AS customer_name,
c.phone AS customer_phone,

-- 车辆信息
v.vehicle_id, v.plate_no,

-- 支付统计
COUNT(p.pay_id) AS payment_count,
COALESCE(SUM(p.amount), 0) AS total_paid,

-- 分类统计
COALESCE(
    SUM(
        CASE
            WHEN p.type = 0 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS deposit_amount,
COALESCE(
    SUM(
        CASE
            WHEN p.type = 1 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS rental_fee_amount,
COALESCE(
    SUM(
        CASE
            WHEN p.type = 2 THEN p.amount
            ELSE 0
        END
    ),
    0
) AS penalty_amount,

-- 支付状态判断
CASE
    WHEN COALESCE(SUM(p.amount), 0) = 0 THEN '未支付'
    WHEN COALESCE(SUM(p.amount), 0) < ro.total_amount THEN '部分支付'
    WHEN COALESCE(SUM(p.amount), 0) >= ro.total_amount THEN '已付清'
    ELSE '未知'
END AS payment_status,

-- 欠款金额
ro.total_amount - COALESCE(SUM(p.amount), 0) AS outstanding_amount,

-- 应退押金（订单完成且无赔偿）
CASE
    WHEN ro.status = 3
    AND COALESCE(
        SUM(
            CASE
                WHEN p.type = 2 THEN p.amount
            END
        ),
        0
    ) = 0 THEN COALESCE(
        SUM(
            CASE
                WHEN p.type = 0 THEN p.amount
            END
        ),
        0
    )
    ELSE 0
END AS refundable_deposit
FROM
    rental_order ro
    INNER JOIN customer c ON ro.customer_id = c.customer_id
    INNER JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
    LEFT JOIN payment p ON ro.order_id = p.order_id
GROUP BY
    ro.order_id,
    ro.rent_start,
    ro.rent_end,
    ro.total_amount,
    ro.status,
    c.customer_id,
    c.name,
    c.phone,
    v.vehicle_id,
    v.plate_no;

-- ============================================
-- 视图 5: vw_maintenance_pending - 待处理维保提醒视图
-- ============================================
-- 依赖表: vehicle, car_model, store, maintenance
-- 用途: 显示需要维保的车辆清单和下次保养里程提醒
-- 业务场景:
--   - 门店制定维保计划
--   - 车辆健康状态监控
--   - 预防性维护管理
-- Java调用: SELECT * FROM vw_maintenance_pending WHERE days_since_last_maint > 90

CREATE OR REPLACE VIEW vw_maintenance_pending AS
SELECT
    v.vehicle_id,
    v.plate_no,
    v.current_soc,
    v.current_mileage,
    v.status AS vehicle_status,
    CASE v.status
        WHEN 0 THEN '在库'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '维保中'
        ELSE '未知'
    END AS vehicle_status_desc,

-- 车型信息
cm.name AS car_model_name, cm.battery_capacity,

-- 门店信息
s.store_id, s.name AS store_name, s.address AS store_address,

-- 最近维保信息
MAX(m.maint_date) AS last_maint_date,
DATEDIFF(NOW(), MAX(m.maint_date)) AS days_since_last_maint,

-- 维保次数统计
COUNT(m.maint_id) AS total_maint_count,
SUM(
    CASE
        WHEN m.type = 0 THEN 1
        ELSE 0
    END
) AS maintenance_count,
SUM(
    CASE
        WHEN m.type = 1 THEN 1
        ELSE 0
    END
) AS repair_count,
SUM(
    CASE
        WHEN m.type = 2 THEN 1
        ELSE 0
    END
) AS other_count,

-- 下次保养里程提醒（每10000km保养一次）
CEIL(v.current_mileage / 10000) * 10000 AS next_maint_mileage,
CEIL(v.current_mileage / 10000) * 10000 - v.current_mileage AS mileage_to_next_maint,

-- 维保优先级
CASE
    WHEN v.status = 2 THEN '维保中'
    WHEN v.current_mileage >= 80000 THEN '高优先级'
    WHEN v.current_mileage >= 50000
    OR DATEDIFF(NOW(), MAX(m.maint_date)) > 180 THEN '中优先级'
    WHEN v.current_mileage >= 20000
    OR DATEDIFF(NOW(), MAX(m.maint_date)) > 90 THEN '低优先级'
    ELSE '无需维保'
END AS maint_priority,

-- 维保建议
CASE
    WHEN v.status = 2 THEN '车辆维保中，请等待完成'
    WHEN v.current_mileage >= 80000 THEN '里程已超8万公里，建议尽快进行全面检测'
    WHEN v.current_mileage >= 50000 THEN '里程已超5万公里，建议安排常规保养'
    WHEN DATEDIFF(NOW(), MAX(m.maint_date)) > 180 THEN '距上次保养已超6个月，建议检查'
    WHEN CEIL(v.current_mileage / 10000) * 10000 - v.current_mileage < 500 THEN '即将到达保养里程'
    ELSE '车况良好'
END AS maint_suggestion
FROM
    vehicle v
    INNER JOIN car_model cm ON v.model_id = cm.model_id
    INNER JOIN store s ON v.store_id = s.store_id
    LEFT JOIN maintenance m ON v.vehicle_id = m.vehicle_id
GROUP BY
    v.vehicle_id,
    v.plate_no,
    v.current_soc,
    v.current_mileage,
    v.status,
    cm.name,
    cm.battery_capacity,
    s.store_id,
    s.name,
    s.address;

-- ============================================
-- 视图 6: vw_vehicle_details - 车辆详细信息视图（额外赠送）
-- ============================================
-- 依赖表: vehicle, car_model, brand, store
-- 用途: 提供车辆的完整详细信息，包括品牌、车型、所属门店等
-- 业务场景:
--   - 车辆档案查询
--   - 车辆库存管理
--   - 预订系统车辆展示
-- Java调用: SELECT * FROM vw_vehicle_details WHERE status = 0 AND store_id = ?

CREATE OR REPLACE VIEW vw_vehicle_details AS
SELECT
    v.vehicle_id,
    v.plate_no,
    v.current_soc,
    v.current_mileage,
    v.status,
    CASE v.status
        WHEN 0 THEN '在库可租'
        WHEN 1 THEN '租赁中'
        WHEN 2 THEN '维保中'
        ELSE '未知'
    END AS status_desc,

-- 车型信息
cm.model_id,
cm.name AS model_name,
cm.seat_count,
cm.battery_capacity,

-- 品牌信息
b.brand_id, b.name AS brand_name,

-- 门店信息
s.store_id, s.name AS store_name, s.address AS store_address,

-- 电量状态
CASE
    WHEN v.current_soc >= 80 THEN '电量充足'
    WHEN v.current_soc >= 50 THEN '电量正常'
    WHEN v.current_soc >= 20 THEN '电量偏低'
    ELSE '需要充电'
END AS battery_status,

-- 续航估算（简化计算：电池容量 * SOC% * 5，假设每kWh约5km）
ROUND(
    cm.battery_capacity * v.current_soc / 100 * 5,
    2
) AS estimated_range_km,

-- 车辆状态综合评估
CASE
    WHEN v.status != 0 THEN '不可租'
    WHEN v.current_soc < 20 THEN '电量不足'
    WHEN v.current_mileage > 80000 THEN '高里程待检'
    ELSE '可租用'
END AS rental_availability
FROM
    vehicle v
    INNER JOIN car_model cm ON v.model_id = cm.model_id
    INNER JOIN brand b ON cm.brand_id = b.brand_id
    INNER JOIN store s ON v.store_id = s.store_id;

-- ============================================
-- 视图 7: vw_violation_summary - 违章汇总统计视图（额外赠送）
-- ============================================
-- 依赖表: violation, vehicle, rental_order, customer
-- 用途: 统计违章记录，关联车辆、订单、客户信息
-- 业务场景:
--   - 违章处理和罚款催收
--   - 客户信用评估
--   - 违章高发区域分析
-- Java调用: SELECT * FROM vw_violation_summary WHERE fine_amount > 500

CREATE OR REPLACE VIEW vw_violation_summary AS
SELECT vio.vio_id, vio.fine_amount, vio.location, vio.violation_date,

-- 车辆信息
v.vehicle_id, v.plate_no,

-- 订单信息
ro.order_id, ro.rent_start, ro.rent_end,

-- 客户信息
c.customer_id,
c.name AS customer_name,
c.phone AS customer_phone,

-- 违章严重程度
CASE
    WHEN vio.fine_amount >= 2000 THEN '严重违章'
    WHEN vio.fine_amount >= 500 THEN '较重违章'
    WHEN vio.fine_amount >= 200 THEN '一般违章'
    ELSE '轻微违章'
END AS violation_severity,

-- 违章地区（从location提取城市）
SUBSTRING_INDEX(vio.location, '市', 1) AS violation_city,

-- 是否已处理（假设payment中有对应赔偿记录）
CASE
    WHEN EXISTS (
        SELECT 1
        FROM payment p
        WHERE
            p.order_id = vio.order_id
            AND p.type = 2
    ) THEN '已处理'
    ELSE '待处理'
END AS handling_status
FROM
    violation vio
    INNER JOIN vehicle v ON vio.vehicle_id = v.vehicle_id
    INNER JOIN rental_order ro ON vio.order_id = ro.order_id
    INNER JOIN customer c ON ro.customer_id = c.customer_id;

-- ============================================
-- 视图使用示例和说明
-- ============================================

-- 示例 1: 查询所有在租订单
-- SELECT * FROM vw_active_orders;

-- 示例 2: 查询利用率最高的门店
-- SELECT * FROM vw_store_utilization ORDER BY utilization_rate DESC LIMIT 5;

-- 示例 3: 查询VIP客户
-- SELECT * FROM vw_customer_value WHERE customer_level = 'VIP';

-- 示例 4: 查询某订单的支付详情
-- SELECT * FROM vw_payment_summary WHERE order_id = 10;

-- 示例 5: 查询需要维保的车辆
-- SELECT * FROM vw_maintenance_pending WHERE maint_priority IN ('高优先级', '中优先级');

-- 示例 6: 查询某门店的可租车辆
-- SELECT * FROM vw_vehicle_details WHERE store_id = 1 AND rental_availability = '可租用';

-- 示例 7: 查询未处理的违章
-- SELECT * FROM vw_violation_summary WHERE handling_status = '待处理';

-- ============================================
-- 维护说明
-- ============================================
-- 1. 视图基于当前表结构创建，若表结构变更需同步更新视图
-- 2. 视图中涉及聚合计算，查询大量数据时注意性能
-- 3. 建议为视图依赖的字段创建索引（参考 3.5.5_indexes.sql）
-- 4. 视图不存储数据，每次查询都会重新计算
-- 5. 可根据业务需要创建物化视图以提升查询性能