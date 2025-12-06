/*
#include <Arduino.h> 
#include <math.h>    
#include <stdlib.h>  

// =================== CẤU HÌNH ===================
#define RX_PIN 16 
#define TX_PIN 17 
#define BAUD_RATE 9600 // Baudrate theo yêu cầu

#define nT 4 
#define nR 4 
#define T 2  
#define SM 16 

// Fixed Point Q22 (Khớp với FPGA)
#define Q 22
#define SCALE_FACTOR (1 << Q) 

typedef struct {
    float re;
    float im;
} complex_t;

// =================================================================
// HELPER FUNCTIONS
// =================================================================
float randn() {
    float u1 = (float)rand() / RAND_MAX;
    float u2 = (float)rand() / RAND_MAX;
    return sqrtf(-2.0f * logf(u1)) * cosf(2 * M_PI * u2);
}

void WriteComChar(uint8_t b) {
    Serial2.write(b);
}

// Hàm gửi 1 số 32-bit và in ra debug HEX
void send_fixed32_debug(float val, const char* type) {
    // 1. Chuyển đổi sang Fixed Point
    int32_t fixed_val = (int32_t)(val * (float)SCALE_FACTOR);
    
    // 2. Tách byte
    union { int32_t i; uint8_t b[4]; } conv;
    conv.i = fixed_val;

    // 3. In ra màn hình để kiểm tra (Giống code cũ của bạn)
    // In giá trị thực và 4 byte HEX sẽ gửi đi
    Serial.printf("    %s: %7.4f -> HEX GUI: %02X %02X %02X %02X\n", 
                  type, val, conv.b[0], conv.b[1], conv.b[2], conv.b[3]);

    // 4. Gửi LSB First xuống FPGA
    WriteComChar(conv.b[0]); 
    WriteComChar(conv.b[1]);
    WriteComChar(conv.b[2]); 
    WriteComChar(conv.b[3]);
}

// =================================================================
// GỬI DỮ LIỆU: HEADER -> Y -> H (CÓ LOG DEBUG)
// =================================================================
void send_batch_Y_then_H(complex_t **Y, complex_t **H) {
    Serial.println("\n🚀 BAT DAU GUI DU LIEU (Y -> H)...");
    
    // 1. Gửi Header DUY NHẤT: 0xCC
    Serial.println("-> Gui Header: 0xCC");
    WriteComChar(0xCC);
    delay(50); // Delay để FPGA chuyển trạng thái

    // 2. Gửi toàn bộ Y (8 phần tử)
    Serial.println("\n--- DANG GUI MA TRAN Y (8 phan tu) ---");
    for(int r=0; r<nR; r++) {
        for(int s=0; s<T; s++) {
            Serial.printf("  Y[%d][%d]:\n", r, s);
            send_fixed32_debug(Y[r][s].re, "Re");
            send_fixed32_debug(Y[r][s].im, "Im");
            delayMicroseconds(200); // Delay an toàn cho Baud 9600
        }
    }
    Serial.println("-> Xong Y.");

    // 3. Gửi toàn bộ H (16 phần tử)
    Serial.println("\n--- DANG GUI MA TRAN H (16 phan tu) ---");
    for (int r = 0; r < nR; r++) {
        for (int c = 0; c < nT; c++) {
            Serial.printf("  H[%d][%d]:\n", r, c);
            send_fixed32_debug(H[r][c].re, "Re");
            send_fixed32_debug(H[r][c].im, "Im");
            delayMicroseconds(200);
        }
    }
    Serial.println("-> Xong H.");
    Serial.println("\n✅ GUI HOAN TAT. CHO KET QUA TU FPGA...");
}

// =================================================================
// NHẬN KẾT QUẢ 12-BIT
// =================================================================
void wait_for_result() {
    Serial.println("\n⏳ DANG DOI KET QUẢ TÍNH TOÁN...");
    
    uint8_t rx_buf[2];
    int count = 0;
    unsigned long start_time = millis();

    // Chờ tối đa 10 giây (tăng lên chút vì in ra màn hình làm chậm quá trình)
    while (count < 2 && (millis() - start_time < 10000)) {
        if (Serial2.available()) {
            rx_buf[count++] = Serial2.read();
        }
    }

    if (count < 2) {
        Serial.println("❌ LOI: Timeout! FPGA khong phan hoi.");
        return;
    }

    uint8_t byte_high = rx_buf[0];
    uint8_t byte_low  = rx_buf[1];
    
    // Ghép 2 byte thành 12 bit
    uint16_t result_12bit = ((uint16_t)(byte_high & 0x0F) << 8) | byte_low;
    
    // Tách các trường b2, b1
    uint8_t b2_out = (result_12bit >> 8) & 0x0F;
    uint8_t b1_out = result_12bit & 0xFF;

    Serial.println("\n========================================");
    Serial.printf("🎉 KET QUA NHAN DUOC (Raw Bytes: %02X %02X)\n", byte_high, byte_low);
    Serial.printf("   🔹 12-bit Value: 0x%03X (Dec: %d)\n", result_12bit, result_12bit);
    Serial.println("   -------------------------------------");
    Serial.printf("   🔸 b2_out (4-bit): %d\n", b2_out);
    Serial.printf("   🔸 b1_out (8-bit): %d\n", b1_out);
    Serial.println("========================================\n");
}

// =================================================================
// MAIN SETUP
// =================================================================
void setup() {
    Serial.begin(9600); // Debug
    Serial2.begin(BAUD_RATE, SERIAL_8N1, RX_PIN, TX_PIN); // FPGA
    
    Serial.println("\n\n=== HE THONG KHOI DONG (DEBUG MODE) ===");
    randomSeed(analogRead(0));

    // Cấp phát
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    for (int i=0; i<nR; i++) { 
        H[i] = (complex_t*)malloc(nT*sizeof(complex_t)); 
        Y[i] = (complex_t*)malloc(T*sizeof(complex_t)); 
    }

    // Tạo dữ liệu (Giá trị nhỏ 0.5 để tránh tràn số Fixed Point)
    for (int r=0; r<nR; r++) {
        for (int c=0; c<nT; c++) {
            H[r][c].re = randn() * 0.5; 
            H[r][c].im = randn() * 0.5;
        }
    }
    // Tạo Y giả lập
    for(int r=0; r<nR; r++) for(int s=0; s<T; s++) { 
        Y[r][s].re = 0.1; 
        Y[r][s].im = 0.2; 
    }

    // Gửi và chờ kết quả
    send_batch_Y_then_H(Y, H);
    wait_for_result();
    
    Serial.println("=== HOAN TAT ===");
}

void loop() { delay(1000); }

*/
#include <Arduino.h> 
#include <math.h>     
#include <stdlib.h>  

// =================== CẤU HÌNH UART ===================
// Lưu ý: Đấu chéo dây. TX của ESP nối RX của FPGA.
#define RX_PIN 16 
#define TX_PIN 17 
#define BAUD_RATE 9600

// =================== THAM SỐ HỆ THỐNG ===================
#define nT 4 // Tx antennas
#define nR 4 // Rx antennas
#define T 2  // Symbol periods
#define SM 16 // 16-QAM

typedef struct {
    float re;
    float im;
} complex_t;

// Helper Math
// Hàm này tạo số ngẫu nhiên theo phân phối chuẩn (Gaussian)
// Nhưng kết quả sẽ phụ thuộc vào randomSeed()
float randn() {
    float u1 = (float)rand() / RAND_MAX;
    float u2 = (float)rand() / RAND_MAX;
    // Tránh log(0)
    if (u1 < 1e-6) u1 = 1e-6;
    return sqrtf(-2.0f * logf(u1)) * cosf(2 * M_PI * u2);
}

// =================================================================
// HÀM GỬI UART (GỬI LSB TRƯỚC)
// =================================================================
void WriteComChar(uint8_t b) {
    Serial2.write(b);
}

void send_matrix(complex_t **M, int rows, int cols, const char *label, uint8_t header_cmd) {
    Serial.printf("\n--- Gui %s (%dx%d) [Header: 0x%02X] ---\n", label, rows, cols, header_cmd);
    
    // 1. Gửi Header Byte để kích hoạt FPGA
    WriteComChar(header_cmd);
    delay(20); // Đợi FPGA chuyển trạng thái từ IDLE -> RECV

    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            
            union { float f; uint8_t b[4]; } conv;

            // --- Gửi RE (LSB First) ---
            conv.f = M[r][c].re;
            // In ra debug để đối chiếu
            Serial.printf("  DATA[%d][%d] RE: %7.4f -> HEX GUI: %02X %02X %02X %02X", 
                          r, c, conv.f, conv.b[0], conv.b[1], conv.b[2], conv.b[3]);
            
            WriteComChar(conv.b[0]); WriteComChar(conv.b[1]);
            WriteComChar(conv.b[2]); WriteComChar(conv.b[3]);

            // --- Gửi IM (LSB First) ---
            conv.f = M[r][c].im;
            Serial.printf(" | IM: %7.4f -> HEX GUI: %02X %02X %02X %02X\n", 
                          conv.f, conv.b[0], conv.b[1], conv.b[2], conv.b[3]);

            WriteComChar(conv.b[0]); WriteComChar(conv.b[1]);
            WriteComChar(conv.b[2]); WriteComChar(conv.b[3]);
            
            delayMicroseconds(200); // Delay nhỏ an toàn
        }
    }
    Serial.println("--- Da gui xong ---");
}

// =================================================================
// HÀM NHẬN ECHO (HIỂN THỊ HEX)
// =================================================================
void wait_for_echo_H() {
    Serial.println("\n🔄 DANG DOI ECHO MA TRAN H TU FPGA (Kiem tra HEX)...");
    
    // Ma trận H 4x4 số phức = 16 phần tử * 8 byte = 128 byte
    const int TOTAL_BYTES = 128;
    uint8_t buffer[TOTAL_BYTES];
    int received_count = 0;
    
    unsigned long start_time = millis();

    // 1. Nhận dữ liệu (Timeout 5s)
    while (received_count < TOTAL_BYTES && (millis() - start_time < 5000)) {
        if (Serial2.available()) {
            buffer[received_count] = Serial2.read();
            received_count++;
        }
    }

    // 2. Xử lý kết quả
    if (received_count < TOTAL_BYTES) {
        Serial.printf("❌ LOI: Timeout! Chi nhan duoc %d / %d byte.\n", received_count, TOTAL_BYTES);
        // In những gì nhận được (nếu có)
        if (received_count > 0) {
            Serial.println("   Dữ liệu nhận được (chưa đủ):");
            for(int k=0; k<received_count; k++) Serial.printf("%02X ", buffer[k]);
            Serial.println();
        }
        return;
    }

    Serial.println("✅ DA NHAN DU 128 BYTE. So sanh HEX:");

    // 3. In ra dạng HEX + Float để kiểm tra
    int ptr = 0;
    for (int i = 0; i < 16; i++) {
        // Lấy 4 byte Re
        uint8_t r0 = buffer[ptr++]; uint8_t r1 = buffer[ptr++]; 
        uint8_t r2 = buffer[ptr++]; uint8_t r3 = buffer[ptr++];
        
        union { float f; uint8_t b[4]; } fre;
        fre.b[0] = r0; fre.b[1] = r1; fre.b[2] = r2; fre.b[3] = r3;

        Serial.printf("  H[%d] RE HEX: %02X %02X %02X %02X (Float: %7.4f)", 
                      i, r0, r1, r2, r3, fre.f);

        // Lấy 4 byte Im
        uint8_t i0 = buffer[ptr++]; uint8_t i1 = buffer[ptr++]; 
        uint8_t i2 = buffer[ptr++]; uint8_t i3 = buffer[ptr++];
        
        union { float f; uint8_t b[4]; } fim;
        fim.b[0] = i0; fim.b[1] = i1; fim.b[2] = i2; fim.b[3] = i3;

        Serial.printf(" | IM HEX: %02X %02X %02X %02X (Float: %7.4f)\n", 
                      i0, i1, i2, i3, fim.f);
    }
}

// =================================================================
// MAIN SETUP
// =================================================================
void setup() {
    Serial.begin(9600);
    Serial2.begin(BAUD_RATE, SERIAL_8N2, RX_PIN, TX_PIN);
    
    Serial.println("\n\n=== HE THONG KHOI DONG ===");

    // === PHẦN SỬA ĐỔI: NHẬP DỮ LIỆU TỪ SERIAL MONITOR ===
    Serial.println(">>> Vui long nhap ma so tao du lieu (VD: 12) vao o input va nhan Gui/Enter <<<");
    
    // Vòng lặp chờ người dùng nhập số
    while (Serial.available() == 0) {
        delay(100); // Chờ đợi...
    }

    long user_seed = Serial.parseInt(); // Đọc số người dùng nhập (ví dụ: 12)
    
    // Đọc bỏ các ký tự thừa (như xuống dòng) còn sót trong buffer
    while(Serial.available()) Serial.read(); 

    Serial.printf("--> Da nhan ma so: %ld. Bat dau tao du lieu co dinh...\n", user_seed);
    
    // Thiết lập seed cho bộ sinh số ngẫu nhiên
    // Với cùng 1 seed (ví dụ 12), hàm rand() sẽ luôn ra cùng 1 chuỗi số.
    randomSeed(user_seed); 

    // Cấp phát bộ nhớ
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    for (int i=0; i<nR; i++) { 
        H[i] = (complex_t*)malloc(nT*sizeof(complex_t)); 
        Y[i] = (complex_t*)malloc(T*sizeof(complex_t)); 
    }

    // Tạo H dựa trên seed đã nhập
    for (int r=0; r<nR; r++) {
        for (int c=0; c<nT; c++) {
            H[r][c].re = randn(); 
            H[r][c].im = randn();
        }
    }
    
    // Tạo Y dựa trên seed đã nhập (thay vì cố định 0.1/0.2 như cũ, ta cũng random theo seed cho thực tế hơn)
    // Hoặc nếu bạn muốn Y vẫn cố định 0.1, 0.2 thì giữ nguyên code cũ. 
    // Ở đây tôi để random theo seed để "nhập 12" thì Y cũng thay đổi theo 12.
    for(int r=0; r<nR; r++) {
        for(int s=0; s<T; s++) { 
             Y[r][s].re = randn(); 
             Y[r][s].im = randn(); 
        }
    }

    // --- BẮT ĐẦU GIAO TIẾP ---
    
    // 1. Gửi H (Kèm lệnh 0xAA)
    send_matrix(H, nR, nT, "Ma Tran H", 0xAA);

    // 2. Chờ Echo HEX ngay lập tức
    wait_for_echo_H();

    // 3. Gửi Y (Kèm lệnh 0xBB)
    delay(1000); 
    send_matrix(Y, nR, T, "Ma Tran Y", 0xBB);
    
    Serial.println("\n=== HOAN TAT CHUONG TRINH ===");
}

void loop() { delay(1000); }
// ver nhan H uart_top_2 owr prepe
