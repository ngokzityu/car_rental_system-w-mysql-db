# 前端实施指南 - 租车闭环功能

本文档提供详细的 JavaScript 代码片段，用于在员工端和用户端添加取车、还车功能。

## 一、员工端 (index.html) 更新

### 1. 添加取车确认对话框

在现有 dialog 部分（约第 710 行之后）添加以下 HTML:

```html
<!-- 确认取车对话框 -->
<el-dialog v-model="dialogVisible.pickup" title="确认取车" width="500px">
    <el-form :model="form.pickup" label-position="top">
        <el-form-item label="订单 ID">
            <el-input v-model="form.pickup.orderId" disabled></el-input>
        </el-form-item>
        <el-form-item label="实际取车时间">
            <el-input v-model="form.pickup.actualPickupTime" type="datetime-local"></el-input>
        </el-form-item>
        <el-form-item label="取车里程 (km)">
            <el-input-number v-model="form.pickup.pickupMileage" :min="0" style="width: 100%"></el-input-number>
        </el-form-item>
        <el-form-item label="取车电量 (%)">
            <el-input-number v-model="form.pickup.actualPickupSoc" :min="0" :max="100" :step="0.1" style="width: 100%"></el-input-number>
        </el-form-item>
    </el-form>
    <template #footer>
        <el-button @click="dialogVisible.pickup = false">取消</el-button>
        <el-button type="primary" @click="submitPickup" :loading="submitting.pickup">确认取车</el-button>
    </template>
</el-dialog>

<!-- 确认还车对话框 -->
<el-dialog v-model="dialogVisible.returnConfirm" title="验车还车" width="500px">
    <el-form :model="form.returnConfirm" label-position="top">
        <el-form-item label="订单 ID">
            <el-input v-model="form.returnConfirm.orderId" disabled></el-input>
        </el-form-item>
        <el-form-item label="取车记录">
            <div style="padding: 10px; background: #f5f5f7; border-radius: 8px; font-size: 13px;">
                <p>取车里程: {{ form.returnConfirm.pickupMileage || '-' }} km</p>
                <p>取车电量: {{ form.returnConfirm.pickupSoc || '-' }} %</p>
            </div>
        </el-form-item>
        <el-form-item label="实际还车时间">
            <el-input v-model="form.returnConfirm.actualReturnTime" type="datetime-local"></el-input>
        </el-form-item>
        <el-form-item label="还车里程 (km)">
            <el-input-number v-model="form.returnConfirm.returnMileage" :min="0" style="width: 100%"></el-input-number>
        </el-form-item>
        <el-form-item label="还车电量 (%)">
            <el-input-number v-model="form.returnConfirm.actualReturnSoc" :min="0" :max="100" :step="0.1" style="width: 100%"></el-input-number>
        </el-form-item>
    </el-form>
    <template #footer>
        <el-button @click="dialogVisible.returnConfirm = false">取消</el-button>
        <el-button type="primary" @click="submitReturnConfirm" :loading="submitting.returnConfirm">确认还车</el-button>
    </template>
</el-dialog>
```

### 2. 更新订单列表表格

在订单管理 tab 的表格中（约第 420-441 行），更新操作列:

```html
<el-table-column label="操作" align="center" width="200">
    <template #default="scope">
        <!-- 已支付状态：显示确认取车按钮 -->
        <el-button v-if="scope.row.status === '已支付'" link type="success" size="small"
            @click="openPickupDialog(scope.row)">确认取车</el-button>
        
        <!-- 待验车状态：显示验车还车按钮 -->
        <el-button v-if="scope.row.status === '待验车'" link type="warning" size="small"
            @click="openReturnDialog(scope.row)">验车还车</el-button>
        
        <el-button link type="danger" size="small"
            @click="deleteOrder(scope.row.orderId)">删除</el-button>
    </template>
</el-table-column>
```

### 3. 添加 JavaScript 函数

在 setup() 函数中（约第 720-1200 行）添加以下代码:

#### 3.1 在 `dialogVisible` reactive 对象中添加:
```javascript
const dialogVisible = reactive({
    // ... 现有的对话框状态
    pickup: false,
    returnConfirm: false
});
```

#### 3.2 在 `submitting` reactive 对象中添加:
```javascript
const submitting = reactive({
    // ... 现有的提交状态
    pickup: false,
    returnConfirm: false
});
```

#### 3.3 在 `form` reactive 对象中添加:
```javascript
const form = reactive({
    // ... 现有的表单数据
    pickup: {
        orderId: null,
        actualPickupTime: '',
        pickupMileage: 0,
        actualPickupSoc: 100
    },
    returnConfirm: {
        orderId: null,
        pickupMileage: null,  // 只读，显示用
        pickupSoc: null,      // 只读，显示用
        actualReturnTime: '',
        returnMileage: 0,
        actualReturnSoc: 50
    }
});
```

#### 3.4 在订单管理函数部分（约第 947-990 行之后）添加:

```javascript
// 打开取车确认对话框
const openPickupDialog = (order) => {
    form.pickup = {
        orderId: order.orderId,
        actualPickupTime: new Date().toISOString().slice(0, 16),  // 默认当前时间
        pickupMileage: 0,
        actualPickupSoc: 100
    };
    dialogVisible.pickup = true;
};

// 提交取车确认
const submitPickup = async () => {
    if (!form.pickup.actualPickupTime || !form.pickup.pickupMileage) {
        ElementPlus.ElMessage.warning('请填写所有必填字段');
        return;
    }
    
    submitting.pickup = true;
    try {
        const payload = {
            actualPickupTime: form.pickup.actualPickupTime.replace('T', ' ') + ':00',
            pickupMileage: form.pickup.pickupMileage,
            actualPickupSoc: form.pickup.actualPickupSoc
        };
        
        await axios.put(`${baseUrl}/orders/${form.pickup.orderId}/pickup`, payload);
        ElementPlus.ElMessage.success('取车确认成功！');
        dialogVisible.pickup = false;
        refreshOrders();
    } catch (error) {
        ElementPlus.ElMessage.error('取车确认失败: ' + (error.response?.data?.message || error.message));
    } finally {
        submitting.pickup = false;
    }
};

// 打开还车确认对话框
const openReturnDialog = (order) => {
    form.returnConfirm = {
        orderId: order.orderId,
        pickupMileage: order.pickupMileage,  // 显示取车时的里程
        pickupSoc: order.actualPickupSoc,     // 显示取车时的电量
        actualReturnTime: new Date().toISOString().slice(0, 16),
        returnMileage: order.pickupMileage || 0,  // 默认值不小于取车里程
        actualReturnSoc: 50
    };
    dialogVisible.returnConfirm = true;
};

// 提交还车确认
const submitReturnConfirm = async () => {
    if (!form.returnConfirm.actualReturnTime || !form.returnConfirm.returnMileage) {
        ElementPlus.ElMessage.warning('请填写所有必填字段');
        return;
    }
    
    // 验证还车里程
    if (form.returnConfirm.returnMileage < form.returnConfirm.pickupMileage) {
        ElementPlus.ElMessage.warning('还车里程不能小于取车里程');
        return;
    }
    
    submitting.returnConfirm = true;
    try {
        const payload = {
            actualReturnTime: form.returnConfirm.actualReturnTime.replace('T', ' ') + ':00',
            returnMileage: form.returnConfirm.returnMileage,
            actualReturnSoc: form.returnConfirm.actualReturnSoc
        };
        
        await axios.put(`${baseUrl}/orders/${form.returnConfirm.orderId}/confirm-return`, payload);
        ElementPlus.ElMessage.success('还车确认成功！车辆已上架');
        dialogVisible.returnConfirm = false;
        refreshOrders();
        refreshVehicles();  // 车辆状态已更新，刷新车辆列表
    } catch (error) {
        ElementPlus.ElMessage.error('还车确认失败: ' + (error.response?.data?.message || error.message));
    } finally {
        submitting.returnConfirm = false;
    }
};
```

#### 3.5 在 return 对象中暴露新函数（约第 1180-1220 行）:

```javascript
return {
    // ... 现有的返回值
    openPickupDialog,
    submitPickup,
    openReturnDialog,
    submitReturnConfirm
};
```

---

## 二、用户端 (customer.html) 更新

### 说明
customer.html 目前没有"我的订单"功能。如果需要完整实现，需要：
1. 添加"我的订单"页面或弹窗
2. 获取当前用户的订单列表
3. 为"使用中"的订单显示"申请还车"按钮

### 简化方案：添加申请还车 JavaScript 函数

在 customer.html 的 JavaScript 部分添加以下函数:

```javascript
// 申请还车
async function applyReturn(orderId) {
    if (!confirm('确认申请还车吗？请确保已将车辆开回门店。')) {
        return;
    }
    
    try {
        await fetch(`http://localhost:8080/api/orders/${orderId}/apply-return`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' }
        });
        
        alert('还车申请已提交！请前往门店进行验车。');
        // 刷新订单列表（如果有的话）
        // fetchMyOrders();
    } catch (error) {
        alert('申请失败: ' + error.message);
    }
}
```

### 如需完整实现"我的订单"功能

需要添加:
1. 订单查询接口（按客户ID或手机号）
2. 订单列表 UI 组件
3. 状态标签显示（已支付、使用中、待验车、已完成）
4. 根据订单状态显示不同操作按钮

---

## 三、测试步骤

### 1. 重启后端服务
由于修改了 Java 代码，需要重启 Spring Boot 应用:
```bash
# 停止现有服务 (Ctrl+C)
# 重新启动
./mvnw spring-boot:run
```

### 2. 测试流程

**Step 1: 创建订单**
- 打开 `http://localhost:8080/index.html`
- 进入"订单管理" Tab
- 点击"新建订单"，填写订单信息
- 确保订单状态为"已支付"

**Step 2: 确认取车**
- 在订单列表中找到状态为"已支付"的订单
- 点击"确认取车" 按钮
- 填写取车信息（时间、里程、电量）
- 提交后订单状态变为"使用中"

**Step 3: 申请还车**
- （在用户端）调用 `applyReturn(订单ID)` 函数
- 或直接在浏览器控制台测试:
  ```javascript
  fetch('http://localhost:8080/api/orders/1/apply-return', {method: 'PUT'})
    .then(r => r.json())
    .then(console.log);
  ```
- 订单状态变为"待验车"

**Step 4: 验车还车**
- 在订单列表中找到状态为"待验车"的订单
- 点击"验车还车"按钮
- 填写还车信息（时间、里程、电量）
- 提交后订单状态变为"已完成"，车辆状态变回"在库"

### 3. 数据库验证

在每个步骤后，可以通过数据库查询验证状态变化:

```sql
-- 查看订单状态
SELECT order_id, status, actual_pickup_time, actual_return_time 
FROM rental_order 
WHERE order_id = 1;

-- 查看车辆状态
SELECT vehicle_id, status, current_mileage, current_soc 
FROM vehicle 
WHERE vehicle_id = (SELECT vehicle_id FROM rental_order WHERE order_id = 1);
```

---

## 四、常见问题

### Q1: 提交时提示"订单状态不正确"
**A:** 确保按照正确的流程: 已支付 → 使用中 → 待验车 → 已完成

### Q2: 还车时提示"还车里程不能小于取车里程"
**A:** 检查填写的还车里程是否大于等于取车时记录的里程

### Q3: 车辆状态没有更新
**A:** 只有确认还车时才会更新车辆状态为"在库"，其他步骤不会改变车辆状态

### Q4: 时间格式不正确
**A:** 确保时间格式为 `yyyy-MM-dd HH:mm:ss`，例如 `2025-12-09 20:30:00`

---

## 五、代码集成检查清单

- [ ] index.html 添加了取车确认对话框 HTML
- [ ] index.html 添加了还车确认对话框 HTML  
- [ ] index.html 更新了订单列表的操作列
- [ ] index.html 的 JavaScript 中添加了 dialogVisible.pickup 和 returnConfirm
- [ ] index.html 的 JavaScript 中添加了 submitting.pickup 和 returnConfirm
- [ ] index.html 的 JavaScript 中添加了 form.pickup 和 returnConfirm
- [ ] index.html 添加了 openPickupDialog 函数
- [ ] index.html 添加了 submitPickup 函数
- [ ] index.html 添加了 openReturnDialog 函数
- [ ] index.html 添加了 submitReturnConfirm 函数
- [ ] index.html 在 return 对象中暴露了新函数
- [ ] customer.html 添加了 applyReturn 函数（可选）
- [ ] 后端服务已重启
- [ ] 测试了完整流程

完成以上检查后，租车闭环功能即可正常使用！
