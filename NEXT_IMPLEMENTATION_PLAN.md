# Tesla 租车系统 - 租车闭环实施计划 (NEXT_IMPLEMENTATION_PLAN.md)

本计划基于 `circle.md` 的设计方案，旨在实现完整的"预订 -> 取车 -> 还车 -> 结算"业务闭环。

## 1. 数据库变更 (Database Migration)

**目标**：为 `rental_order` 表添加记录实际取还车信息的字段。

**操作步骤**：
1.  找到或创建一个新的 SQL 脚本（或者直接在数据库客户端执行）。
2.  执行以下 SQL 语句：

```sql
ALTER TABLE rental_order
ADD COLUMN actual_pickup_time DATETIME COMMENT '实际取车时间',
ADD COLUMN actual_return_time DATETIME COMMENT '实际还车时间',
ADD COLUMN pickup_mileage INT COMMENT '取车里程',
ADD COLUMN return_mileage INT COMMENT '还车里程',
ADD COLUMN pickup_soc DECIMAL(5,2) COMMENT '取车电量百分比', -- 补充 circle.md 中提到但在 SQL 示例中隐含的字段
ADD COLUMN return_soc DECIMAL(5,2) COMMENT '还车电量百分比'; -- 补充 circle.md 中提到但在 SQL 示例中隐含的字段
```

## 2. 后端开发 (Backend Implementation)

**目标**：更新实体类，并实现取车、申请还车、确认还车的业务逻辑接口。

### 2.1 更新实体类 (`RentalOrder.java`)
**文件**：`src/main/java/com/tesla/rental/entity/RentalOrder.java`
**变更**：
- 添加上述 6 个新字段的 Java 属性。
- 添加对应的 Getter/Setter。

### 2.2 更新控制器 (`RentalOrderController.java`)
**文件**：`src/main/java/com/tesla/rental/controller/RentalOrderController.java`
**新增接口**：

1.  **确认取车 (Confirm Pickup)**
    -   **Method**: `PUT /api/orders/{orderId}/pickup`
    -   **Body**: `{ "actualPickupTime": "...", "pickupMileage": 15000, "pickupSoc": 90.0 }`
    -   **Logic**: 更新订单状态为 `使用中` (IN_USE)，更新取车信息。

2.  **申请还车 (Apply Return)**
    -   **Method**: `PUT /api/orders/{orderId}/apply-return`
    -   **Body**: `{ "returnStoreId": 1 }` (可选)
    -   **Logic**: 更新订单状态为 `待验车` (PENDING_INSPECTION)。

3.  **确认还车 (Confirm Return)**
    -   **Method**: `PUT /api/orders/{orderId}/confirm-return`
    -   **Body**: `{ "actualReturnTime": "...", "returnMileage": 15200, "returnSoc": 80.0 }`
    -   **Logic**: 
        -   更新订单状态为 `已完成` (COMPLETED)，更新还车信息。
        -   **关键联动**：更新 `Vehicle` 表，状态改为 `在库` (0)，更新车辆当前的 `mileage` 和 `soc`。

## 3. 前端开发 (Frontend Development)

### 3.1 用户端 (`customer.html`)
**目标**：让用户能看到"申请还车"按钮。
**变更**：
- 在"我的订单"列表中，针对状态为 `使用中` 的订单，添加"申请还车"按钮。
- 点击按钮调用 `PUT /api/orders/{id}/apply-return`。
- 刷新列表显示状态变为 `待验车`。

### 3.2 员工端 (`index.html`)
**目标**：实现取车确认和还车验车功能。
**变更**：
- **待取车处理**：
    -   查询状态为 `已支付` (PAID) 的订单。
    -   添加"确认取车"操作，弹出模态框输入取车里程、电量等。
    -   调用 `PUT /api/orders/{id}/pickup`。
- **待验车处理**：
    -   查询状态为 `待验车` (PENDING_INSPECTION) 的订单。
    -   添加"验车还车"操作，弹出模态框输入还车里程、电量等。
    -   调用 `PUT /api/orders/{id}/confirm-return`。

## 4. 验证测试 (Verification Plan)

**测试流程**：
1.  **用户下单**：使用 `customer.html` 创建一个新订单。
    -   *预期*：订单状态 `已支付`，车辆状态 `在租`。
2.  **员工取车**：使用 `index.html` 对该订单确认取车。
    -   *预期*：订单状态 `使用中`。
3.  **用户还车**：使用 `customer.html` 申请还车。
    -   *预期*：订单状态 `待验车`。
4.  **员工验车**：使用 `index.html` 确认还车。
    -   *预期*：订单状态 `已完成`，车辆状态变回 `在库`，且车辆里程/电量已更新。

## 5. 执行顺序建议

1.  先执行 SQL 变更。
2.  修改后端 Entity 和 Controller。
3.  重启后端服务。
4.  修改前端 HTML/JS。
5.  进行完整流程测试。
