-- 租车闭环功能 - 数据库变更脚本
-- 为 rental_order 表添加实际取还车信息字段
-- 创建时间: 2025-12-09

ALTER TABLE rental_order
ADD COLUMN actual_pickup_time DATETIME COMMENT '实际取车时间',
ADD COLUMN actual_return_time DATETIME COMMENT '实际还车时间',
ADD COLUMN pickup_mileage INT COMMENT '取车里程',
ADD COLUMN return_mileage INT COMMENT '还车里程',
ADD COLUMN actual_pickup_soc DECIMAL(5, 2) COMMENT '实际取车电量百分比',
ADD COLUMN actual_return_soc DECIMAL(5, 2) COMMENT '实际还车电量百分比';