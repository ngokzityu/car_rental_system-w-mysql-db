package com.tesla.rental.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tesla.rental.payload.ChatRequest;
import com.tesla.rental.payload.ChatResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AIChatController {

    @Value("${moonshot.api.key}")
    private String apiKey;

    @Value("${moonshot.api.url}")
    private String apiUrl;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private final com.tesla.rental.repository.VehicleRepository vehicleRepository;
    private final com.tesla.rental.repository.StoreRepository storeRepository;

    public AIChatController(com.tesla.rental.repository.VehicleRepository vehicleRepository,
                            com.tesla.rental.repository.StoreRepository storeRepository) {
        this.vehicleRepository = vehicleRepository;
        this.storeRepository = storeRepository;
    }

    @PostMapping("/chat")
    public ChatResponse chat(@RequestBody ChatRequest request) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            // Fallback if API key is missing
            return new ChatResponse("请先在后台配置 DeepSeek API Key。", new ArrayList<>());
        }

        try {
            // 0. 获取数据库中的车辆和门店信息构建上下文
            List<com.tesla.rental.entity.Store> stores = storeRepository.findAll();
            Map<Long, String> storeMap = stores.stream()
                    .collect(java.util.stream.Collectors.toMap(com.tesla.rental.entity.Store::getStoreId, com.tesla.rental.entity.Store::getName));

            List<com.tesla.rental.entity.Vehicle> vehicles = vehicleRepository.findAll();
            StringBuilder inventoryBuilder = new StringBuilder();
            inventoryBuilder.append("当前可用门店列表：\n");
            for (com.tesla.rental.entity.Store s : stores) {
                inventoryBuilder.append(String.format("- 门店ID: %d, 名称: %s, 地址: %s\n", s.getStoreId(), s.getName(), s.getAddress()));
            }
            inventoryBuilder.append("\n当前所有车辆详细列表：\n");
            for (com.tesla.rental.entity.Vehicle v : vehicles) {
                String storeName = storeMap.getOrDefault(v.getStoreId(), "未知门店");
                String modelName = v.getCarModel() != null ? v.getCarModel().getName() : "未知车型";
                String statusLabel = v.getStatus() != null ? v.getStatus().getLabel() : "未知";
                inventoryBuilder.append(String.format("- 车牌: %s, 车型: %s, 门店: %s, 状态: %s, 电量: %.1f%%, 里程: %.1fkm\n",
                        v.getPlateNo(), modelName, storeName, statusLabel, v.getCurrentSoc(), v.getCurrentMileage()));
            }

            String inventoryContext = inventoryBuilder.toString();

            // 1. 构建 System Prompt
            String systemPrompt = """
                你是一个专业的 Tesla 租车顾问。你拥有系统实时的车辆和门店库存数据权限。
                
                【实时系统数据】
                %s
                
                请根据上述【实时系统数据】和用户的需求来回答问题。
                如果用户询问"有没有上海牌照的车"、"Model 3在哪些店有"等问题，请直接检索上述数据并准确回答。
                如果用户询问推荐车型，请结合库存情况（例如某款车是否在租、电量是否充足）进行推荐。
                
                请务必**只**返回一个合法的 JSON 对象，不要包含任何 Markdown 格式（如 ```json ... ```）或额外的解释性文字。
                JSON 格式严格如下：
                {
                  "reply": "这里写给用户的自然语言回复，语气亲切专业。如果引用了具体车辆信息，请包含车牌号或门店名。",
                  "recommendedModels": ["Model 3", "Model Y"] 
                }
                如果用户只是闲聊或没有明确购车/租车意向，recommendedModels 返回空数组 []。
                切记：直接返回 JSON 字符串，不要加任何前缀或后缀。
                """.formatted(inventoryContext);

            // 2. 构建 OpenAI 格式的请求体
            Map<String, Object> apiRequestBody = new HashMap<>();
            apiRequestBody.put("model", "deepseek-chat");
            apiRequestBody.put("temperature", 0.3);

            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "system", "content", systemPrompt));
            messages.add(Map.of("role", "user", "content", request.getMessage()));
            apiRequestBody.put("messages", messages);

            // 3. 设置 Header
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(apiRequestBody, headers);

            // 4. 发送请求
            ResponseEntity<JsonNode> response = restTemplate.postForEntity(apiUrl, entity, JsonNode.class);

            // 5. 解析响应
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                JsonNode root = response.getBody();
                JsonNode choices = root.path("choices");
                if (choices.isArray() && choices.size() > 0) {
                    String content = choices.get(0).path("message").path("content").asText();
                    
                    // 尝试提取 JSON 部分 (找到第一个 '{' 和最后一个 '}')
                    int jsonStartIndex = content.indexOf("{");
                    int jsonEndIndex = content.lastIndexOf("}");

                    if (jsonStartIndex != -1 && jsonEndIndex != -1 && jsonEndIndex > jsonStartIndex) {
                        String jsonContent = content.substring(jsonStartIndex, jsonEndIndex + 1);
                        try {
                            return objectMapper.readValue(jsonContent, ChatResponse.class);
                        } catch (Exception e) {
                            // 如果解析失败，记录日志或忽略，继续向下执行使用原始内容
                            System.err.println("JSON parsing failed: " + e.getMessage());
                        }
                    }

                    // 如果没有找到 JSON 结构或解析失败，尝试作为普通文本处理
                    // 清理 Markdown 标记以防万一
                    String cleanContent = content;
                    if (cleanContent.startsWith("```json")) {
                        cleanContent = cleanContent.substring(7);
                    }
                    if (cleanContent.startsWith("```")) {
                        cleanContent = cleanContent.substring(3);
                    }
                    if (cleanContent.endsWith("```")) {
                        cleanContent = cleanContent.substring(0, cleanContent.length() - 3);
                    }
                    
                    return new ChatResponse(cleanContent.trim(), new ArrayList<>());
                }
            }

            return new ChatResponse("抱歉，AI 暂时无法响应，请稍后再试。", new ArrayList<>());

        } catch (Exception e) {
            e.printStackTrace();
            return new ChatResponse("系统发生错误：" + e.getMessage(), new ArrayList<>());
        }
    }
}
