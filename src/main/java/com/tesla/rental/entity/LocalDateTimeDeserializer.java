package com.tesla.rental.entity;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;

import java.io.IOException;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

/**
 * 自定义反序列化器，可接受 LocalDateTime 的多种常见时间格式。
 * 支持：
 *  - ISO 偏移/带时区字符串（例如 2025-11-26T08:00:00Z 或 2025-11-26T08:00:00+08:00）
 *  - ISO 本地日期时间（例如 2025-11-26T08:00:00，或带毫秒）
 *  - 自定义格式 yyyy-MM-dd HH:mm:ss
 *  - 纪元毫秒值（数字）
 */
public class LocalDateTimeDeserializer extends JsonDeserializer<LocalDateTime> {

    private static final DateTimeFormatter[] FORMATTERS = new DateTimeFormatter[]{
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
            DateTimeFormatter.ISO_LOCAL_DATE_TIME
    };

    @Override
    public LocalDateTime deserialize(JsonParser p, DeserializationContext ctxt) throws IOException {
        String text = p.getText();
        if (text == null || text.isBlank()) return null;

        // 数字形式的纪元毫秒值
        if (text.matches("^-?\\d+$")) {
            try {
                long millis = Long.parseLong(text);
                return Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDateTime();
            } catch (NumberFormatException e) {
                // 继续尝试后续解析
            }
        }

        // 尝试用 OffsetDateTime（带时区的 ISO 格式）解析
        try {
            OffsetDateTime odt = OffsetDateTime.parse(text);
            return odt.toLocalDateTime();
        } catch (DateTimeParseException ignore) {
        }

        // 尝试按 Instant（Z 结尾格式）解析
        try {
            Instant i = Instant.parse(text);
            return LocalDateTime.ofInstant(i, ZoneId.systemDefault());
        } catch (DateTimeParseException ignore) {
        }

        // 回退到预定义的格式化器循环解析
        for (DateTimeFormatter f : FORMATTERS) {
            try {
                return LocalDateTime.parse(text, f);
            } catch (DateTimeParseException ignored) {
            }
        }

        // 仅日期格式（yyyy-MM-dd）默认补零时分秒
        try {
            LocalDate date = LocalDate.parse(text, DateTimeFormatter.ISO_LOCAL_DATE);
            return date.atStartOfDay();
        } catch (DateTimeParseException ignored) {
        }

        // 如果仍无法解析则抛出提示性异常
        throw new IOException("Unrecognized date-time format for value: " + text);
    }
}
