-- ============================================
-- Tesla 租车系统 - 业务查询脚本
-- 版本: 1.0
-- 日期: 2025-12-08
-- 说明: 课程设计 3.5.2 业务查询（≥20 条，每类 ≥2 条）
-- ============================================

-- 选择数据库
USE tesla_db;

-- ============================================
-- 一、比较条件查询（Comparison Conditions）
-- ============================================

-- --------------------------------------------------------
-- 查询 1.1：在租状态车辆清单
-- --------------------------------------------------------
-- 需求：查询当前正在被租用的所有车辆信息
-- 数据表：vehicle, car_model, store
-- 业务意义：用于掌握车辆租用情况，支持调度决策

SELECT
    v.vehicle_id AS 车辆ID,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    v.current_soc AS 当前电量,
    v.current_mileage AS 当前里程,
    s.name AS 所属门店
FROM
    vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
    JOIN store s ON v.store_id = s.store_id
WHERE
    v.status = 1;
-- 1=在租

-- --------------------------------------------------------
-- 查询 1.2：电量低于 20% 的车辆清单
-- --------------------------------------------------------
-- 需求：查找需要紧急充电的低电量车辆
-- 数据表：vehicle, car_model, store
-- 业务意义：预警低电量车辆，防止客户用车中途没电

SELECT
    v.vehicle_id AS 车辆ID,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    v.current_soc AS 当前电量百分比,
    s.name AS 所属门店,
    CASE v.status
        WHEN 0 THEN '在库'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '维保'
    END AS 状态
FROM
    vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
    JOIN store s ON v.store_id = s.store_id
WHERE
    v.current_soc < 20;

-- --------------------------------------------------------
-- 查询 1.3：高里程车辆清单（里程 > 50000km）
-- --------------------------------------------------------
-- 需求：统计行驶里程超过 5 万公里的车辆
-- 数据表：vehicle, car_model
-- 业务意义：识别需要重点保养或考虑淘汰的高里程车辆

SELECT
    v.vehicle_id AS 车辆ID,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    v.current_mileage AS 累计里程,
    CASE v.status
        WHEN 0 THEN '在库'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '维保'
    END AS 状态
FROM vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
WHERE
    v.current_mileage > 50000
ORDER BY v.current_mileage DESC;

-- ============================================
-- 二、集合比较查询（IN / ALL / ANY）
-- ============================================

-- --------------------------------------------------------
-- 查询 2.1：一线城市门店的所有订单（IN）
-- --------------------------------------------------------
-- 需求：查询取车门店位于北京、上海、广州、深圳的订单
-- 数据表：rental_order, store, customer
-- 业务意义：分析一线城市市场表现，制订区域营销策略

SELECT
    ro.order_id AS 订单ID,
    c.name AS 客户姓名,
    s.name AS 取车门店,
    ro.rent_start AS 取车时间,
    ro.rent_end AS 还车时间,
    ro.total_amount AS 订单金额
FROM
    rental_order ro
    JOIN store s ON ro.pickup_store_id = s.store_id
    JOIN customer c ON ro.customer_id = c.customer_id
WHERE
    s.store_id IN (
        SELECT store_id
        FROM store
        WHERE
            address LIKE '北京%'
            OR address LIKE '上海%'
            OR address LIKE '广州%'
            OR address LIKE '深圳%'
    );

-- --------------------------------------------------------
-- 查询 2.2：租金高于所有经济型车型平均租金的订单（ALL）
-- --------------------------------------------------------
-- 需求：查找租金金额高于 Model 3 全系列订单平均租金的所有订单
-- 数据表：rental_order, vehicle, car_model
-- 业务意义：识别高价值订单，分析高端车型市场需求

SELECT ro.order_id AS 订单ID, ro.total_amount AS 订单金额, cm.name AS 车型名称
FROM
    rental_order ro
    JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
    JOIN car_model cm ON v.model_id = cm.model_id
WHERE
    ro.total_amount > ALL (
        SELECT AVG(ro2.total_amount)
        FROM
            rental_order ro2
            JOIN vehicle v2 ON ro2.vehicle_id = v2.vehicle_id
            JOIN car_model cm2 ON v2.model_id = cm2.model_id
        WHERE
            cm2.name LIKE 'Model 3%'
        GROUP BY
            cm2.model_id
    );

-- --------------------------------------------------------
-- 查询 2.3：违章金额高于任一普通违规的订单（ANY）
-- --------------------------------------------------------
-- 需求：查找违章金额超过任何 200 元以下违章金额的违章记录
-- 数据表：violation, vehicle
-- 业务意义：筛选严重违章行为，加强客户风险管控

SELECT vio.vio_id AS 违章ID, v.plate_no AS 车牌号, vio.fine_amount AS 罚款金额, vio.location AS 违章地点
FROM violation vio
    JOIN vehicle v ON vio.vehicle_id = v.vehicle_id
WHERE
    vio.fine_amount > ANY (
        SELECT fine_amount
        FROM violation
        WHERE
            fine_amount <= 200
    );

-- ============================================
-- 三、范围比较查询（BETWEEN / 日期区间）
-- ============================================

-- --------------------------------------------------------
-- 查询 3.1：本月（2025年12月）租金收入统计
-- --------------------------------------------------------
-- 需求：统计 2025 年 12 月的租金支付总额
-- 数据表：payment, rental_order
-- 业务意义：核算当月营业收入，支持财务报表生成

SELECT SUM(p.amount) AS 本月租金收入, COUNT(DISTINCT p.order_id) AS 涉及订单数, COUNT(*) AS 支付笔数
FROM payment p
    JOIN rental_order ro ON p.order_id = ro.order_id
WHERE
    p.type = 1 -- 1=租金
    AND ro.rent_start BETWEEN '2025-12-01' AND '2025-12-31';

-- --------------------------------------------------------
-- 查询 3.2：近一周内创建的订单
-- --------------------------------------------------------
-- 需求：查询最近 7 天内新建的租赁订单
-- 数据表：rental_order, customer, vehicle
-- 业务意义：跟踪近期业务活跃度，评估市场表现

SELECT
    ro.order_id AS 订单ID,
    c.name AS 客户姓名,
    v.plate_no AS 车牌号,
    ro.rent_start AS 取车时间,
    ro.rent_end AS 预计还车时间,
    ro.total_amount AS 订单金额,
    CASE ro.status
        WHEN 0 THEN '已支付'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '已还'
        WHEN 3 THEN '结算'
    END AS 订单状态
FROM
    rental_order ro
    JOIN customer c ON ro.customer_id = c.customer_id
    JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
WHERE
    ro.rent_start BETWEEN DATE_SUB(CURDATE(), INTERVAL 7 DAY) AND CURDATE();

-- --------------------------------------------------------
-- 查询 3.3：指定金额区间的支付记录
-- --------------------------------------------------------
-- 需求：查询金额在 1000-3000 元之间的支付记录
-- 数据表：payment, rental_order, customer
-- 业务意义：分析中等金额支付分布，优化定价策略

SELECT
    p.pay_id AS 支付ID,
    ro.order_id AS 订单ID,
    c.name AS 客户姓名,
    p.amount AS 支付金额,
    CASE p.type
        WHEN 0 THEN '押金'
        WHEN 1 THEN '租金'
        WHEN 2 THEN '赔偿'
    END AS 支付类型
FROM
    payment p
    JOIN rental_order ro ON p.order_id = ro.order_id
    JOIN customer c ON ro.customer_id = c.customer_id
WHERE
    p.amount BETWEEN 1000 AND 3000
ORDER BY p.amount DESC;

-- ============================================
-- 四、字符串相似比较（LIKE / REGEXP）
-- ============================================

-- --------------------------------------------------------
-- 查询 4.1：车牌模糊搜索（LIKE）
-- --------------------------------------------------------
-- 需求：搜索车牌号包含"A1"的所有车辆
-- 数据表：vehicle, car_model, store
-- 业务意义：支持客户/工作人员通过部分车牌快速查找车辆

SELECT
    v.vehicle_id AS 车辆ID,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    s.name AS 所属门店,
    CASE v.status
        WHEN 0 THEN '在库'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '维保'
    END AS 状态
FROM
    vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
    JOIN store s ON v.store_id = s.store_id
WHERE
    v.plate_no LIKE '%A1%';

-- --------------------------------------------------------
-- 查询 4.2：客户姓名模糊搜索（LIKE）
-- --------------------------------------------------------
-- 需求：搜索姓"张"或名字中含"宇"的客户
-- 数据表：customer
-- 业务意义：支持客服通过客户姓名部分信息快速定位客户

SELECT
    customer_id AS 客户ID,
    name AS 姓名,
    phone AS 电话,
    id_card AS 身份证号
FROM customer
WHERE
    name LIKE '张%'
    OR name LIKE '%宇%';

-- --------------------------------------------------------
-- 查询 4.3：门店地址正则匹配（REGEXP）
-- --------------------------------------------------------
-- 需求：搜索地址中包含"中心"或"广场"的门店
-- 数据表：store
-- 业务意义：按门店类型进行分类统计，优化选址策略

SELECT
    store_id AS 门店ID,
    name AS 门店名称,
    address AS 地址
FROM store
WHERE
    address REGEXP '(中心|广场)';

-- --------------------------------------------------------
-- 查询 4.4：Model S/X 高端车型筛选（REGEXP）
-- --------------------------------------------------------
-- 需求：查询 Model S 或 Model X 系列车型信息
-- 数据表：car_model, brand
-- 业务意义：统计高端车型配置，支持产品组合分析

SELECT
    cm.model_id AS 车型ID,
    cm.name AS 车型名称,
    cm.seat_count AS 座位数,
    cm.battery_capacity AS 电池容量,
    b.name AS 品牌
FROM car_model cm
    JOIN brand b ON cm.brand_id = b.brand_id
WHERE
    cm.name REGEXP 'Model [SX]';

-- ============================================
-- 五、多表连接查询（Multi-table JOIN）
-- ============================================

-- --------------------------------------------------------
-- 查询 5.1：订单完整信息查询（五表关联）
-- --------------------------------------------------------
-- 需求：查询订单的客户、车辆、门店、支付等完整信息
-- 数据表：rental_order, customer, vehicle, store, payment
-- 业务意义：提供订单全景视图，支持客户服务和售后处理

SELECT
    ro.order_id AS 订单ID,
    c.name AS 客户姓名,
    c.phone AS 客户电话,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    ps.name AS 取车门店,
    rs.name AS 还车门店,
    ro.rent_start AS 取车时间,
    ro.rent_end AS 还车时间,
    ro.total_amount AS 订单金额,
    COALESCE(SUM(p.amount), 0) AS 已付金额,
    CASE ro.status
        WHEN 0 THEN '已支付'
        WHEN 1 THEN '在租'
        WHEN 2 THEN '已还'
        WHEN 3 THEN '结算'
    END AS 订单状态
FROM
    rental_order ro
    JOIN customer c ON ro.customer_id = c.customer_id
    JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
    JOIN car_model cm ON v.model_id = cm.model_id
    JOIN store ps ON ro.pickup_store_id = ps.store_id
    JOIN store rs ON ro.return_store_id = rs.store_id
    LEFT JOIN payment p ON ro.order_id = p.order_id
GROUP BY
    ro.order_id,
    c.name,
    c.phone,
    v.plate_no,
    cm.name,
    ps.name,
    rs.name,
    ro.rent_start,
    ro.rent_end,
    ro.total_amount,
    ro.status
ORDER BY ro.order_id;

-- --------------------------------------------------------
-- 查询 5.2：门店运营数据汇总
-- --------------------------------------------------------
-- 需求：按门店统计订单数、总收入、车辆数等核心指标
-- 数据表：store, rental_order, vehicle, payment
-- 业务意义：评估各门店运营绩效，指导资源分配

SELECT
    s.store_id AS 门店ID,
    s.name AS 门店名称,
    COUNT(DISTINCT v.vehicle_id) AS 在库车辆数,
    COUNT(DISTINCT ro.order_id) AS 订单总数,
    COALESCE(SUM(ro.total_amount), 0) AS 总营收
FROM
    store s
    LEFT JOIN vehicle v ON s.store_id = v.store_id
    LEFT JOIN rental_order ro ON s.store_id = ro.pickup_store_id
GROUP BY
    s.store_id,
    s.name
ORDER BY 总营收 DESC;

-- --------------------------------------------------------
-- 查询 5.3：客户租赁历史与违章关联
-- --------------------------------------------------------
-- 需求：查询客户的租赁历史及关联违章记录
-- 数据表：customer, rental_order, vehicle, violation
-- 业务意义：评估客户信用风险，支持客户分级管理

SELECT
    c.customer_id AS 客户ID,
    c.name AS 客户姓名,
    COUNT(DISTINCT ro.order_id) AS 订单数,
    SUM(ro.total_amount) AS 累计消费,
    COUNT(DISTINCT vio.vio_id) AS 违章次数,
    COALESCE(SUM(vio.fine_amount), 0) AS 违章罚款总额
FROM
    customer c
    LEFT JOIN rental_order ro ON c.customer_id = ro.customer_id
    LEFT JOIN violation vio ON ro.order_id = vio.order_id
GROUP BY
    c.customer_id,
    c.name
ORDER BY 累计消费 DESC;

-- ============================================
-- 六、嵌套查询 / 子查询（Subquery）
-- ============================================

-- --------------------------------------------------------
-- 查询 6.1：高价值客户筛选（累计消费前 20%）
-- --------------------------------------------------------
-- 需求：筛选累计消费金额高于平均值 1.5 倍的客户
-- 数据表：customer, rental_order
-- 业务意义：识别 VIP 客户，制订精准营销方案

SELECT c.customer_id AS 客户ID, c.name AS 客户姓名, c.phone AS 电话, customer_stats.total_amount AS 累计消费
FROM customer c
    JOIN (
        SELECT customer_id, SUM(total_amount) AS total_amount
        FROM rental_order
        GROUP BY
            customer_id
    ) customer_stats ON c.customer_id = customer_stats.customer_id
WHERE
    customer_stats.total_amount > (
        SELECT AVG(total_amount) * 1.5
        FROM rental_order
    )
ORDER BY customer_stats.total_amount DESC;

-- --------------------------------------------------------
-- 查询 6.2：最近未租赁车辆列表（超过 30 天未出租）
-- --------------------------------------------------------
-- 需求：查找最近 30 天没有任何租赁记录的可用车辆
-- 数据表：vehicle, rental_order, car_model, store
-- 业务意义：识别闲置资产，优化车辆调度策略

SELECT
    v.vehicle_id AS 车辆ID,
    v.plate_no AS 车牌号,
    cm.name AS 车型,
    s.name AS 所属门店,
    v.current_soc AS 当前电量
FROM
    vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
    JOIN store s ON v.store_id = s.store_id
WHERE
    v.status = 0 -- 在库
    AND v.vehicle_id NOT IN(
        SELECT DISTINCT
            vehicle_id
        FROM rental_order
        WHERE
            rent_start >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    );

-- --------------------------------------------------------
-- 查询 6.3：每门店最热门车型
-- --------------------------------------------------------
-- 需求：统计各门店被租次数最多的车型
-- 数据表：store, rental_order, vehicle, car_model
-- 业务意义：了解区域市场偏好，指导车型配置优化

SELECT s.name AS 门店名称, cm.name AS 热门车型, order_count.cnt AS 租用次数
FROM
    store s
    JOIN (
        SELECT ro.pickup_store_id, v.model_id, COUNT(*) AS cnt, ROW_NUMBER() OVER (
                PARTITION BY
                    ro.pickup_store_id
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM rental_order ro
            JOIN vehicle v ON ro.vehicle_id = v.vehicle_id
        GROUP BY
            ro.pickup_store_id,
            v.model_id
    ) order_count ON s.store_id = order_count.pickup_store_id
    AND order_count.rn = 1
    JOIN car_model cm ON order_count.model_id = cm.model_id
ORDER BY s.store_id;

-- ============================================
-- 七、EXISTS 查询
-- ============================================

-- --------------------------------------------------------
-- 查询 7.1：检查客户是否有未结算违章
-- --------------------------------------------------------
-- 需求：筛选存在违章记录的客户（租用期间产生过违章）
-- 数据表：customer, rental_order, violation
-- 业务意义：还车时提醒客户处理违章，避免押金纠纷

SELECT c.customer_id AS 客户ID, c.name AS 客户姓名, c.phone AS 联系电话
FROM customer c
WHERE
    EXISTS (
        SELECT 1
        FROM
            rental_order ro
            JOIN violation vio ON ro.order_id = vio.order_id
        WHERE
            ro.customer_id = c.customer_id
    );

-- --------------------------------------------------------
-- 查询 7.2：检查车辆是否有维保记录
-- --------------------------------------------------------
-- 需求：筛选有历史维保记录的车辆
-- 数据表：vehicle, maintenance, car_model
-- 业务意义：掌握车辆维保历史，预判车况及保养周期

SELECT v.vehicle_id AS 车辆ID, v.plate_no AS 车牌号, cm.name AS 车型
FROM vehicle v
    JOIN car_model cm ON v.model_id = cm.model_id
WHERE
    EXISTS (
        SELECT 1
        FROM maintenance m
        WHERE
            m.vehicle_id = v.vehicle_id
    );

-- --------------------------------------------------------
-- 查询 7.3：无订单记录的新客户
-- --------------------------------------------------------
-- 需求：筛选尚未产生任何租赁订单的注册客户
-- 数据表：customer, rental_order
-- 业务意义：追踪潜在客户，进行激活营销

SELECT c.customer_id AS 客户ID, c.name AS 客户姓名, c.phone AS 联系电话
FROM customer c
WHERE
    NOT EXISTS (
        SELECT 1
        FROM rental_order ro
        WHERE
            ro.customer_id = c.customer_id
    );

-- ============================================
-- 八、聚合与分组查询（补充高级查询）
-- ============================================

-- --------------------------------------------------------
-- 查询 8.1：月度营收趋势分析
-- --------------------------------------------------------
-- 需求：按月份统计租金收入和订单数量
-- 数据表：rental_order, payment
-- 业务意义：分析营收趋势，预测季节性波动

SELECT DATE_FORMAT(ro.rent_start, '%Y-%m') AS 月份, COUNT(DISTINCT ro.order_id) AS 订单数, SUM(ro.total_amount) AS 订单总金额, COALESCE(
        SUM(
            CASE
                WHEN p.type = 1 THEN p.amount
                ELSE 0
            END
        ), 0
    ) AS 实收租金
FROM rental_order ro
    LEFT JOIN payment p ON ro.order_id = p.order_id
GROUP BY
    DATE_FORMAT(ro.rent_start, '%Y-%m')
ORDER BY 月份;

-- --------------------------------------------------------
-- 查询 8.2：车型使用效率分析
-- --------------------------------------------------------
-- 需求：按车型统计被租次数、平均租金、总收入
-- 数据表：car_model, vehicle, rental_order
-- 业务意义：评估各车型市场受欢迎程度和盈利能力

SELECT
    cm.name AS 车型,
    COUNT(DISTINCT v.vehicle_id) AS 车辆数,
    COUNT(ro.order_id) AS 被租次数,
    ROUND(AVG(ro.total_amount), 2) AS 平均订单金额,
    SUM(ro.total_amount) AS 总收入
FROM
    car_model cm
    LEFT JOIN vehicle v ON cm.model_id = v.model_id
    LEFT JOIN rental_order ro ON v.vehicle_id = ro.vehicle_id
GROUP BY
    cm.model_id,
    cm.name
ORDER BY 总收入 DESC;

-- --------------------------------------------------------
-- 查询 8.3：用户操作审计统计
-- --------------------------------------------------------
-- 需求：按用户统计操作日志数量及常见操作类型
-- 数据表：audit_log, sys_user
-- 业务意义：监控用户行为，发现异常操作模式

SELECT u.username AS 用户名, COUNT(*) AS 操作次数, GROUP_CONCAT(
        DISTINCT SUBSTRING_INDEX(al.action, ' ', 1) SEPARATOR ', '
    ) AS 操作类型
FROM audit_log al
    JOIN sys_user u ON al.user_id = u.user_id
GROUP BY
    u.user_id,
    u.username
ORDER BY 操作次数 DESC;

-- ============================================
-- 查询脚本统计
-- ============================================
-- 总查询数：21 条
--
-- 类型分布：
--   1. 比较条件查询    ：3 条（1.1, 1.2, 1.3）
--   2. 集合比较查询    ：3 条（2.1, 2.2, 2.3）
--   3. 范围比较查询    ：3 条（3.1, 3.2, 3.3）
--   4. 字符串相似查询  ：4 条（4.1, 4.2, 4.3, 4.4）
--   5. 多表连接查询    ：3 条（5.1, 5.2, 5.3）
--   6. 嵌套/子查询     ：3 条（6.1, 6.2, 6.3）
--   7. EXISTS 查询     ：3 条（7.1, 7.2, 7.3）
--   8. 聚合分组查询    ：3 条（8.1, 8.2, 8.3）*补充
-- ============================================