# 下一步改进计划 (Next Steps)

这份清单基于对 `tesla-rental` 项目的深度分析，旨在将其从“课程设计”水平提升至接近“企业级应用”标准。

## 1. 核心架构重构 (优先级：最高)
> **目标**：实现标准的 MVC 分层架构，解耦业务逻辑与接口层。

- [ ] **引入 Service 层**
    - 创建 `com.tesla.rental.service` 包。
    - 将 `RentalOrderController` 中的业务逻辑（如：下单时检查车辆状态、更新车辆状态、计算金额）迁移至 `RentalOrderService` 类。
    - 将 `VehicleController` 等其他控制器的逻辑也下沉至对应的 Service。
- [ ] **事务管理**
    - 在 Service 方法上添加 `@Transactional` 注解。
    - 确保“创建订单”和“扣减库存/修改车辆状态”是一个原子操作，要么都成功，要么都回滚。

## 2. 健壮性与规范 (优先级：高)
> **目标**：处理异常情况，防止系统在错误输入下崩溃，提供友好的错误提示。

- [ ] **全局异常处理**
    - 创建 `exception/GlobalExceptionHandler.java`。
    - 使用 `@RestControllerAdvice` 统一捕获异常（如 `ResourceNotFoundException`, `IllegalArgumentException`）。
    - 返回统一的 JSON 格式（例如：`{ "code": 500, "message": "车辆已被租用", "data": null }`）。
- [ ] **参数校验**
    - 在 DTO/Entity 中添加校验注解（如 `@NotNull`, `@Min(0)`, `@NotBlank`）。
    - 在 Controller 方法参数前添加 `@Valid`。

## 3. 业务逻辑深挖 (优先级：中)
> **目标**：解决多用户并发场景下的实际问题。

- [ ] **并发控制 (防止超卖)**
    - 在 `Vehicle` 实体中增加 `@Version private Integer version;` 字段（乐观锁）。
    - 防止两个用户在同一毫秒租同一辆车。
- [ ] **日志记录**
    - 使用 Slf4j (`log.info`, `log.error`) 替换 `System.out.println`。
    - 记录关键操作：用户登录、下单成功、支付回调等。

## 4. 测试与质量 (优先级：中)
> **目标**：确保代码修改后功能依然正常。

- [ ] **单元测试**
    - 为 `RentalOrderService` 编写 JUnit 测试用例。
    - 覆盖“正常下单”和“车辆不可用导致下单失败”两种场景。

## 5. 前端优化 (优先级：低 - 可选)
> **目标**：提升页面加载速度和代码可维护性。

- [ ] **资源本地化**
    - 将 `unpkg.com` 的 CDN 链接（Vue, Element Plus）下载到本地 `static/js` 和 `static/css` 目录，防止断网无法演示。
