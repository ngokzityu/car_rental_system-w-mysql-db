# AI 选车助手功能实现计划

本通过将在用户端网页 (`customer.html`) 集成一个智能对话助手，根据用户的自然语言描述（如"我想带全家去旅游"或"想要一辆加速快的车"）自动推荐并筛选匹配的 Tesla 车型。

## 1. 后端开发 (Spring Boot)

- [ ] **定义数据交互模型 (DTO)**
    - 创建 `com.tesla.rental.payload.ChatRequest`: 用于接收前端发送的用户文本。
    - 创建 `com.tesla.rental.payload.ChatResponse`: 用于返回 AI 的文本回复以及推荐的车型列表 (`List<String>`)。

- [ ] **创建 AI 控制器 (Controller
)**
    - 创建 `com.tesla.rental.controller.AIChatController`。
    - 实现 endpoint: `POST /api/ai/chat`。
    - **业务逻辑实现**:
        - 解析用户输入的关键词（规则引擎方式）。
        - 示例规则：
            - 包含 "家庭", "孩子", "空间" -> 推荐 Model X, Model Y。
            - 包含 "速度", "快", "性能" -> 推荐 Model S, Model 3 Performance。
            - 包含 "便宜", "性价比" -> 推荐 Model 3。
            - 包含 "越野", "大" -> 推荐 Cybertruck。
        - 构造友好的回复文本，并将匹配到的车型名称放入 `recommendedModels` 字段返回。

## 2. 前端开发 (customer.html)

- [ ] **UI 界面组件**
    - **悬浮按钮**: 在页面右下角添加一个圆形悬浮按钮，点击可展开聊天窗口。
    - **聊天窗口**:
        - 顶部：标题栏 ("Tesla 智能助手") 和关闭按钮。
        - 中间：消息滚动区域，区分显示用户消息（右侧气泡）和 AI 消息（左侧气泡）。
        - 底部：输入框和发送按钮。

- [ ] **CSS 样式设计**
    - 保持与现有页面一致的 "Apple Style" 设计语言（磨砂玻璃效果、圆角、阴影、极简配色）。
    - 适配移动端和桌面端显示。

- [ ] **Vue.js 交互逻辑**
    - `chatMessages`: 响应式数组，存储对话历史。
    - `handleSend()`: 调用后端 API，发送用户输入，接收响应。
    - **核心联动功能**:
        - 当后端返回 `recommendedModels` 不为空时，前端自动触发首页的车辆筛选逻辑。
        - 将页面滚动至车辆列表区域。
        - 弹出提示消息："已为您筛选出 [车型名称]..."。

## 3. 验证与测试

- [ ] **API 测试**: 使用 Postman 或 curl 测试后端接口对不同关键词的响应。
- [ ] **UI 测试**: 检查聊天窗口的打开/关闭动画，消息滚动的流畅性。
- [ ] **功能测试**: 模拟用户输入 "推荐一辆适合家用的车"，确认页面是否自动过滤只显示 Model X/Y。
