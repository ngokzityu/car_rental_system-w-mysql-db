# 下一阶段改进计划（tesla-rental）

> 目标：在保持演示效果的前提下，将后端从“CRUD 原型”升级为“可上线演示”的架构，优先解决安全、领域建模和稳定性问题。

## 1. 安全与配置（P0）
- [ ] **密钥与账号外置**：把 `src/main/resources/application.properties` 中的数据库口令、JWT Secret、Moonshot API Key 等敏感信息迁出仓库，改用 `application-example.properties` + 环境变量加载，并按 profile 拆分 dev/prod。
- [ ] **访问控制梳理**：重新审查 `SecurityConfig`，仅对白名单接口开放 `permitAll`，订单/客户/支付接口需要登录态；同时给 `/api/vehicles/generate` 等测试接口添加 `@PreAuthorize("hasRole('ADMIN')")` 与开关。
- [ ] **角色映射修复**：调整 `CustomUserDetailsService` / `SysRole`，避免目前 `"ROLE_" + roleName` 导致权限变成 `ROLE_ROLE_ADMIN`，并限制注册接口只能赋予受控角色。
- [ ] **CORS & 速率限制**：把所有控制器的 `@CrossOrigin("*")` 改成集中配置，按环境/域名控制来源，并在认证/下单接口前接入基础的限流（如 Bucket4j 或 Spring Cloud Gateway 级别）以免被刷。

## 2. 领域模型与架构（P0）
- [ ] **补齐 Service 层**：为车辆、订单、支付、客户等模块建立 `service` 包，Controller 负责 DTO 校验 + 调用 Service，Service 内封装 Repository、事务、日志。
- [ ] **实体关系重建**：给 `Vehicle`, `RentalOrder`, `Payment`, `SysUser` 等实体增加 `@ManyToOne/@OneToMany` 映射、`@Version`、`@CreatedDate/@LastModifiedDate`，并用 `@NotNull/@Column` 约束字段。
- [ ] **DTO & MapStruct**：禁止直接暴露实体，新增请求/响应 DTO 并通过 MapStruct 或手写转换，隐藏内部 ID/敏感字段（如 `passwordHash`）。

## 3. 业务一致性（P1）
- [ ] **订单创建流程**：在 Service 中补齐“校验车辆状态 → 锁定/更新状态 → 生成订单/支付信息 → 写审计日志”的完整流程，必要时引入乐观锁或分布式锁避免并发超卖。
- [ ] **车辆状态机**：抽象出状态流转（在库→在租→维保/已还），统一入口处理取还车、电量、门店变化，并推送给 AI/前端。
- [ ] **支付与押金**：补充支付记录与订单的耦合逻辑（金额校验、退款/补差），并对接第三方支付占位接口或模拟器。
- [ ] **AI 网关健壮性**：为 `AIChatController` 添加超时/重试、降级回答与调用配额统计，防止未配置 Key 时抛 NPE。

## 4. API 质量与异常处理（P1）
- [ ] **全局异常处理**：新增 `@RestControllerAdvice`，对 `ResourceNotFound`, `BusinessException`, `MethodArgumentNotValidException` 等统一返回 `{code,message,traceId}` 结构。
- [ ] **请求校验**：在 DTO/实体上使用 Bean Validation（`@NotBlank`, `@Positive`, 自定义校验器），Controller 参数加 `@Valid`，并用 `ValidationMessages.properties` 做国际化。
- [ ] **分页与过滤**：列表接口改为分页（`Pageable`），同时支持按门店、状态等过滤，避免一次性返回所有数据。

## 5. 观测性与日志（P2）
- [ ] **标准化日志**：统一使用 Slf4j + Logback JSON Pattern，区分 info/debug/error，引入 traceId。将 `AuditLog` 实体真正串起来记录关键操作。
- [ ] **业务指标**：用 Micrometer 把订单数量、车辆利用率、AI 调用耗时等指标暴露给 Actuator / Prometheus，方便日后做看板。

## 6. 测试与交付（P2）
- [ ] **测试体系**：编写 `RentalOrderService`/`VehicleService` 的单元测试（Mockito）与关键流程的 `@SpringBootTest` 集成测试，覆盖乐观锁、异常分支。
- [ ] **数据与迁移**：用 Flyway/Liquibase 管理 schema 及基础数据（角色、枚举），确保多环境一致；提供 SQL/CommandLineRunner 生成演示数据的安全开关。
- [ ] **DevOps**：补充 Docker Compose（App + MySQL）、`Makefile` 或脚本简化启动，后续可加 GitHub Actions 做 CI（编译 + 测试 + 构建镜像）。

> 完成以上事项后，再进入前端性能、本地化等长期优化。该计划可拆为两迭代：第一迭代聚焦 P0 + P1，第二迭代完善 P2。
