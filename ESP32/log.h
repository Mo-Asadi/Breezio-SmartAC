#define LOG_INFO(x)    Serial.println(String("[INFO] ") + x)
#define LOG_WARN(x)    Serial.println(String("[WARN] ") + x)
#define LOG_ERROR(x)   Serial.println(String("[ERROR] ") + x)
#define LOGF(fmt, ...) do { char buf[128]; snprintf(buf, sizeof(buf), fmt, ##__VA_ARGS__); Serial.println(buf); } while(0)