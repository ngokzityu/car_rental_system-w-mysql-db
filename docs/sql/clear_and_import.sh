#!/bin/bash

# Tesla租车系统 - 清空数据并重新导入脚本
# 使用方法: bash clear_and_import.sh

echo "🗑️  正在清空现有数据..."

mysql -u root -p20041106 tesla_db << EOF
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_log;
TRUNCATE TABLE violation;
TRUNCATE TABLE payment;
TRUNCATE TABLE maintenance;
TRUNCATE TABLE rental_order;
TRUNCATE TABLE sys_user_role;
TRUNCATE TABLE vehicle;
TRUNCATE TABLE sys_user;
TRUNCATE TABLE customer;
TRUNCATE TABLE sys_role;
TRUNCATE TABLE store;
TRUNCATE TABLE car_model;
TRUNCATE TABLE brand;
SET FOREIGN_KEY_CHECKS = 1;
EOF

echo "✅ 数据清空完成！"
echo ""
echo "📥 正在导入新数据..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mysql -u root -p20041106 tesla_db < "$SCRIPT_DIR/3.5.1_data_init.sql"

echo "✅ 数据导入完成！"
echo ""
echo "📊 验证数据..."

mysql -u root -p20041106 tesla_db << EOF
SELECT 'brand' AS 表名, COUNT(*) AS 记录数 FROM brand
UNION ALL SELECT 'car_model', COUNT(*) FROM car_model
UNION ALL SELECT 'store', COUNT(*) FROM store
UNION ALL SELECT 'vehicle', COUNT(*) FROM vehicle
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'rental_order', COUNT(*) FROM rental_order
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'maintenance', COUNT(*) FROM maintenance
UNION ALL SELECT 'violation', COUNT(*) FROM violation
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log;
EOF

echo ""
echo "🎉 所有操作完成！"
