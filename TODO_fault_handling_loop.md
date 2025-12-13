# TODO - 车辆故障处理闭环接入

目标：在现有“预订-取车-还车”闭环中补充“车辆故障处理”流程，支持客户报障、员工处理（现场修复或更换车辆）、联动订单与车辆状态。

## 数据/模型
- [ ] 新增 `fault_ticket` 表（或 Flyway 脚本）：`ticket_id` PK、`order_id`、`vehicle_id`、`customer_id`、`status`(PENDING/RESOLVED)、`resolution_type`(ON_SITE_REPAIR/VEHICLE_SWAP)、`description`、`reported_time`、`handled_by`、`resolved_time`、`new_vehicle_id`(换车时记录)、`remark`。加索引：`order_id`、`vehicle_id`、`status`。
- [ ] 创建 JPA 实体/枚举：`FaultTicket`、`FaultStatus`、`FaultResolutionType`，仓库 `FaultTicketRepository`。保持 `VehicleStatus.MAINTENANCE` 作为“维修中”状态复用。
- [ ] （可选）现场维修/换车时自动写一条 `maintenance` 记录（type=维修），便于维保历史统计。

## 后端接口/业务
- [ ] 新增 `FaultTicketController`：
  - `POST /api/faults` 客户报障：校验订单状态应为在租/待验车，默认 `status=PENDING`，关联订单/车辆/客户。
  - `GET /api/faults`、`GET /api/faults/{id}`：员工查看待处理与历史工单。
  - `PUT /api/faults/{id}/resolve`：参数包含 `resolutionType`、`handledBy`、`remark`、`newVehicleId`（换车场景），根据方案执行：
    - 方案A（ON_SITE_REPAIR）：更新工单状态为 RESOLVED、记录处理人/时间/备注；可追加一条 `maintenance` 记录；车辆仍保持 `RENTED`。
    - 方案B（VEHICLE_SWAP）：校验新车辆状态必须 `IN_STOCK`，更新原订单的 `vehicle_id`→新车；将新车状态置 `RENTED`，故障车状态置 `MAINTENANCE`；工单状态标记 RESOLVED 并记录 `newVehicleId`。
- [ ] 补充异常提示与状态校验：工单必须属于对应订单/车辆；订单已完成的工单不可再处理。
- [ ] Security 放行 `/api/faults/**`（与现有 Demo 一致）或按角色加权限注解。

## 前端（静态页）
- [ ] `customer.html`：“我的订单”里在 `使用中/待验车` 状态添加“报故障”按钮和弹窗（描述、上传图片占位）。提交调用 `POST /api/faults`，并在订单详情展示工单状态。
- [ ] `index.html` 新增“故障工单”Tab：列表展示工单信息、状态、关联订单/车牌；操作按钮支持“现场修复”“更换车辆”。换车弹窗需要选择库存车辆（下拉可复用 `/api/vehicles` 过滤 `status=在库`）。
- [ ] 处理完成后刷新订单与车辆列表，前端提示文案与状态标签补充“待解决/已解决”。

## 文档/验证
- [ ] README / report_info.md 补充接口说明与状态流转描述；ER/表字段更新一处引用。
- [ ] 验收用例：① 报障→现场修复：工单 RESOLVED，车辆仍在租；② 报障→换车：原车状态=维保、新车状态=在租、订单 vehicleId 已切换；③ 报错路径：订单非在租状态禁止报障或处理。
