#include <Arduino.h>

extern "C" {
  #include "sm_ostbc_core.h"
  #include "sm_ostbc_core_initialize.h"
  #include "tmwtypes.h" 
}

// === CẤU HÌNH ===
#define FPGA_RX_PIN 16 
#define FPGA_TX_PIN 17 
#define BAUDRATE    9600 
#define STACK_SIZE  32768 

// === QUAN TRỌNG: ĐỊNH NGHĨA HỆ SỐ Q22 ===
#define SCALE_Q22 4194304.0 // 2^22

// Struct tham số cho Task
typedef struct {
  int16_t seed;
} TaskParams;

// ============================================================
// HÀM GỬI SỐ THỰC DƯỚI DẠNG FIXED-POINT Q22 (GIỐNG CODE B)
// ============================================================
void send_fixed_point_Q22(double val) {
    // 1. Nhân với 2^22 và làm tròn thành số nguyên 32-bit
    int32_t val_fixed = (int32_t)(val * SCALE_Q22);

    // 2. Tách thành 4 byte
    uint8_t *ptr = (uint8_t*)&val_fixed;

    // 3. Gửi lần lượt (Little Endian: LSB trước)
    Serial2.write(ptr[0]); 
    Serial2.write(ptr[1]);
    Serial2.write(ptr[2]);
    Serial2.write(ptr[3]);

    // [DEBUG] In Hex ra để so sánh
    Serial.printf("[%02X %02X %02X %02X] ", ptr[0], ptr[1], ptr[2], ptr[3]);
}

// ============================================================
// TASK TÍNH TOÁN & GỬI DỮ LIỆU
// ============================================================
void heavy_calculation_task(void *pvParameters) {
  TaskParams *params = (TaskParams *)pvParameters;
  int16_t current_seed = params->seed;
  free(params); 

  Serial.println("\n--- Task Bắt đầu ---");

  double snr = 15.0;
  creal_T H_out[16]; 
  creal_T Y_out[8];  
  double num_errors = 0; 

  // 1. TÍNH TOÁN (Dùng MATLAB Core)
  unsigned long start_time = micros();
  sm_ostbc_core(snr, (double)current_seed, &num_errors, H_out, Y_out);
  unsigned long duration = micros() - start_time;
  Serial.print("Tính xong trong: "); Serial.print(duration); Serial.println(" us");

  // 2. GỬI DỮ LIỆU SANG FPGA (DÙNG HÀM Q22 MỚI)
  Serial.println("\n>>> Bắt đầu gửi H (Format Q22):");
  for (int i = 0; i < 16; i++) {
    Serial.printf("\nH[%02d]: ", i);
    // Lưu ý: MATLAB Core dùng double, ta truyền vào hàm convert
    send_fixed_point_Q22(H_out[i].re); 
    send_fixed_point_Q22(H_out[i].im); 
  }

  Serial.println("\n\n>>> Bắt đầu gửi Y (Format Q22):");
  for (int i = 0; i < 8; i++) {
    Serial.printf("\nY[%02d]: ", i);
    
    // Lưu ý: Code B của bạn gửi Y dương (negate_imag = false)
    // Code MATLAB này cũng tạo ra Y dương, nên gửi trực tiếp.
    send_fixed_point_Q22(Y_out[i].re);
    send_fixed_point_Q22(Y_out[i].im);
  }
  
  Serial.println("\n\n>>> Đã gửi xong. Đang chờ phản hồi...");

  // 3. CHỜ NHẬN 16-BIT TỪ FPGA
  while(Serial2.available()) Serial2.read(); // Xóa buffer
  unsigned long wait_start = millis();
  bool received = false;
  
  while(millis() - wait_start < 5000) { 
    if (Serial2.available() >= 2) {
      uint8_t rx_high = Serial2.read(); 
      uint8_t rx_low  = Serial2.read(); 
      uint16_t result_16bit = (rx_high << 8) | rx_low;

      Serial.println("\n=== KẾT QUẢ TỪ FPGA ===");
      Serial.printf("Hex: 0x%04X | Dec: %d\n", result_16bit, result_16bit);
      
      uint16_t clean_result = result_16bit & 0x0FFF; 
      if(clean_result == current_seed) Serial.println("✅ MATCH!");
      else Serial.println("❌ MISMATCH!");
      
      received = true;
      break; 
    }
    vTaskDelay(10 / portTICK_PERIOD_MS);
  }

  if (!received) Serial.println("⚠️ TIMEOUT: Không thấy FPGA trả lời.");
  Serial.println("----------------------------------------");
  vTaskDelete(NULL);
}

// ============================================================
// SETUP & LOOP (GIỮ NGUYÊN)
// ============================================================
void setup() {
  Serial.begin(9600); 
  Serial2.begin(BAUDRATE, SERIAL_8N1, FPGA_RX_PIN, FPGA_TX_PIN);
  sm_ostbc_core_initialize();
  
  Serial.println("\n--- ESP32 OSTBC (MATLAB Core + Q22 Fix) ---");
  Serial.println("Gửi 2 byte seed để bắt đầu...");

  while (Serial.available() < 2) delay(100); 

  uint8_t high_byte = Serial.read();
  uint8_t low_byte = Serial.read();
  while(Serial.available()) Serial.read();
  
  int16_t seed_input = ((high_byte & 0x0F) << 8) | low_byte;
  Serial.print("Received Seed: "); Serial.println(seed_input);

  TaskParams *params = (TaskParams *)malloc(sizeof(TaskParams));
  params->seed = seed_input;

  xTaskCreate(heavy_calculation_task, "OSTBC_Task", STACK_SIZE, (void *)params, 1, NULL);
}

void loop() { delay(1000); }
