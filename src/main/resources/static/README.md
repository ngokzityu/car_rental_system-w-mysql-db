# 🚗 Tesla Rental Platform (特斯拉租赁管理系统)

> 一个基于 Spring Boot 3.x 的全栈车辆租赁管理平台演示项目。
> 集成 JWT 认证、Apple 风格仪表盘、全业务流程覆盖，开箱即用。

本项目模拟了特斯拉租赁门店的完整业务闭环，包含车辆管理、客户信用、租赁订单、支付流水、违章处理及维保记录等核心模块。
项目采用**前后端不分离**架构，前端页面直接集成在 Spring Boot 中（`src/main/resources/static`），无需单独部署前端服务，非常适合作为**毕业设计**、**课程作业**或**快速原型开发**的基础。

---

## ✨ 核心功能

*   **全栈业务管理**：覆盖品牌、车型、门店、车辆、客户、订单、违章、维保、支付等全生命周期管理。
*   **现代化仪表盘**：内置 Apple 风格的管理后台（基于 Vue 3 + Element Plus CDN），界面美观，交互流畅。
*   **安全认证体系**：内置标准的 JWT (JSON Web Token) 认证机制，支持用户注册、登录及多角色权限控制（管理员/员工）。
*   **一键数据模拟**：提供 `POST /api/vehicles/generate` 接口，快速生成测试车辆数据，方便演示与测试。
*   **极简部署**：无需 Node.js 环境，无需 npm install，直接运行 Java 应用即可访问完整系统。

## 🧩 数据模型 (与 ER 图一致)

各表及关键字段与 ER 图保持一致，状态/类型使用枚举映射为整型存储，接口仍返回中文标签：

*   `vehicle.status`：0=在库，1=在租，2=维保 (`VehicleStatus`)
*   `rental_order.status`：0=已支付，1=在租，2=已还，3=结算 (`RentalOrderStatus`)
*   `payment.type`：0=押金，1=租金，2=赔偿 (`PaymentType`)
*   `maintenance.type`：0=保养，1=维修，2=其他 (`MaintenanceType`)
*   `current_soc`/`return_soc` 等电量字段使用 `Double`，`maint_date` 支持日期或日期时间输入

## 🛠 技术栈

*   **后端**: Spring Boot 3.5.8 (Web, Data JPA, Security, Actuator)
*   **数据库**: MySQL 8.x (JPA `ddl-auto=update` 自动建表)
*   **身份认证**: JJWT 0.11.5
*   **前端**: Vue.js 3 + Element Plus (CDN 引入, 无需构建)
*   **开发环境**: JDK 17, Maven 3.9+

## 📂 项目结构

```text
tesla-rental/
├── src/main/java/com/tesla/rental
│   ├── controller/   # API 控制器 (RESTful Endpoints)
│   ├── entity/       # 数据库实体 (JPA Entities)
│   ├── repository/   # 数据访问层 (Spring Data JPA)
│   ├── security/     # JWT 与 Security 配置
│   └── config/       # 全局配置 (Jackson等)
├── src/main/resources
│   ├── application.properties  # 核心配置
│   └── static/                 # 前端资源
│       ├── index.html          # 管理后台仪表盘 (Vue App)
│       ├── customer.html       # 客户页面 (示例)
│       └── images/             # 车辆图片资源
└── pom.xml           # Maven 依赖管理
```

## 🚀 快速开始

只需简单的几步配置，即可在本地运行本项目。

### 1. 环境准备
*   **JDK 17+**
*   **MySQL 8.x**

### 2. 数据库初始化
1.  创建一个空的 MySQL 数据库：
    ```sql
    CREATE DATABASE IF NOT EXISTS tesla_db DEFAULT CHARACTER SET utf8mb4;
    ```
2.  (重要) 预置角色数据：
    ```sql
    USE tesla_db;
    INSERT INTO sys_role (role_name) VALUES ('ROLE_ADMIN'), ('ROLE_STAFF')
    ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);
    ```

### 3. 修改配置
打开 `src/main/resources/application.properties`，修改数据库连接信息：
```properties
spring.datasource.url=jdbc:mysql://localhost:3306/tesla_db?useSSL=false&serverTimezone=Asia/Shanghai&characterEncoding=utf-8
spring.datasource.username=root
spring.datasource.password=你的数据库密码
```

### 4. 启动项目
在项目根目录下运行：
```bash
# Linux/macOS
./mvnw spring-boot:run

# Windows
.\mvnw.cmd spring-boot:run
```
或者打包后运行 jar：
```bash
./mvnw clean package -DskipTests
java -jar target/rental-0.0.1-SNAPSHOT.jar
```

启动成功后，访问：[http://localhost:8080](http://localhost:8080)

> **注意**：首次访问首页时，如果后端没有数据，可以在页面上点击“生成10辆随机车”按钮快速初始化数据。

## 🧪 测试与验证

### 创建管理员账号
由于系统初始无用户，需先调用 API 注册 (建议使用 Postman 或 curl)：
```bash
curl -X POST http://localhost:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d 
'{ 
        "username": "admin",
        "password": "Admin123!",
        "storeId": 1,
        "role": ["ROLE_ADMIN"]
      }'
```

### 获取 Token (登录)
```bash
curl -X POST http://localhost:8080/api/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}'
```
返回的 `accessToken` 即为 JWT。
*注意：目前的 index.html 前端主要用于展示业务功能，并未强制集成登录跳转（为了演示方便），后端 API 大部分默认放行或需在 Header 中手动携带 Token 测试（具体视 SecurityConfig 配置而定）。*

## 📚 API 概览

| 模块 | 资源路径 | 描述 |
| :--- | :--- | :--- |
| **认证** | `/api/auth/**` | 登录、注册 |
| **车辆** | `/api/vehicles` | 车辆 CRUD、状态管理 |
| **车型** | `/api/models` | 特斯拉车型 (Model 3, Model Y 等) |
| **门店** | `/api/stores` | 租赁点管理 |
| **订单** | `/api/orders` | 租赁订单创建与查询 |
| **客户** | `/api/customers` | 客户信息与信用分 |
| **支付** | `/api/payments` | 支付记录流水 |
| **违章** | `/api/violations` | 违章记录登记 |
| **维保** | `/api/maintenance` | 车辆维保记录 |

> 完整接口定义请参考 `controller` 包下的源码。

## ❓ 常见问题 (FAQ)

*   **Q: 端口 8080 被占用怎么办？**
    *   A: 在 `application.properties` 中添加 `server.port=9090` (或任意空闲端口)。
*   **Q: 数据库报错或连不上？**
    *   A: 请检查 MySQL 服务是否启动，账号密码是否正确，以及数据库 `tesla_db` 是否已创建。
*   **Q: 前端页面加载慢？**
    *   A: 前端使用了 unpkg.com 的 CDN 加载 Vue 和 Element Plus，网络不佳时可能会稍慢，建议保持网络畅通。
*   **Q: 如何重置系统？**
    *   A: 设置 `spring.jpa.hibernate.ddl-auto=create` 重启一次即可清空并重建表结构 (生产环境慎用)。

---
**Enjoy!** 🚗⚡️