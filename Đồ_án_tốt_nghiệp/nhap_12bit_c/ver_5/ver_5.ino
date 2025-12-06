/*
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
// HÀM NHẬN ECHO (HIỂN THỊ HEX) - ĐỂ DEBUG H
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
        Serial.printf("❌ LOI: Timeout Echo H! Chi nhan duoc %d / %d byte.\n", received_count, TOTAL_BYTES);
        return;
    }

    Serial.println("✅ DA NHAN DU 128 BYTE ECHO H.");
    // (Lược bỏ phần in chi tiết Echo H để tập trung vào phần mới, nếu cần bạn có thể giữ lại code in cũ)
}

// =================================================================
// [MỚI] HÀM NHẬN KẾT QUẢ 12-BIT
// =================================================================
void wait_for_12bit_result() {
    Serial.println("\n🔄 DANG DOI KET QUA 12-BIT TU FPGA...");
    
    // FPGA sẽ gửi 2 byte: [Byte Cao] rồi đến [Byte Thấp]
    // Byte Cao chứa 4 bit cao của 12 bit (0000_xxxx)
    
    unsigned long start_time = millis();
    
    // Chờ nhận đủ 2 byte (Timeout 10s vì FPGA cần thời gian xử lý stream)
    while (Serial2.available() < 2) {
        if (millis() - start_time > 10000) { 
             Serial.println("❌ TIMEOUT: Khong nhan duoc ket qua 12-bit (FPGA co the chua gui).");
             return;
        }
    }

    // Đọc 2 byte
    uint8_t byte_high = Serial2.read();
    uint8_t byte_low  = Serial2.read();

    // Ghép lại thành giá trị 12-bit
    // Ép kiểu uint16_t để tránh tràn số khi dịch bit
    uint16_t result_12bit = ((uint16_t)byte_high << 8) | byte_low;

    Serial.println("✅ DA NHAN DUOC KET QUA 12-BIT!");
    Serial.printf("   - Byte High (raw): 0x%02X\n", byte_high);
    Serial.printf("   - Byte Low  (raw): 0x%02X\n", byte_low);
    Serial.printf("   => GIA TRI GOP (HEX): 0x%03X\n", result_12bit);
    Serial.printf("   => GIA TRI GOP (DEC): %d\n", result_12bit);
}

// =================================================================
// MAIN SETUP
// =================================================================
void setup() {
    Serial.begin(9600);
    Serial2.begin(BAUD_RATE, SERIAL_8N2, RX_PIN, TX_PIN);
    
    Serial.println("\n\n=== HE THONG KHOI DONG ===");

    // === NHẬP DỮ LIỆU TỪ SERIAL MONITOR ===
    Serial.println(">>> Vui long nhap ma so tao du lieu (VD: 12) vao o input va nhan Gui/Enter <<<");
    
    while (Serial.available() == 0) { delay(100); }
    long user_seed = Serial.parseInt(); 
    while(Serial.available()) Serial.read(); 

    Serial.printf("--> Da nhan ma so: %ld. Bat dau tao du lieu...\n", user_seed);
    randomSeed(user_seed); 

    // Cấp phát bộ nhớ
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    for (int i=0; i<nR; i++) { 
        H[i] = (complex_t*)malloc(nT*sizeof(complex_t)); 
        Y[i] = (complex_t*)malloc(T*sizeof(complex_t)); 
    }

    // Tạo H
    for (int r=0; r<nR; r++) {
        for (int c=0; c<nT; c++) {
            H[r][c].re = randn(); H[r][c].im = randn();
        }
    }
    
    // Tạo Y
    for(int r=0; r<nR; r++) {
        for(int s=0; s<T; s++) { 
             Y[r][s].re = randn(); Y[r][s].im = randn(); 
        }
    }

    // --- BẮT ĐẦU GIAO TIẾP ---
    
    // 1. Gửi H (Kèm lệnh 0xAA)
    send_matrix(H, nR, nT, "Ma Tran H", 0xAA);

    // 2. Chờ Echo HEX của H (để kiểm tra FPGA nhận đúng không)
    wait_for_echo_H();

    // 3. Gửi Y (Kèm lệnh 0xBB)
    delay(1000); 
    send_matrix(Y, nR, T, "Ma Tran Y", 0xBB);
    
    // 4. [MỚI] Chờ nhận kết quả 12-bit cuối cùng
    // FPGA sẽ xử lý Y xong -> Bắn sang Decoder -> Rồi mới gửi 12 bit này
    wait_for_12bit_result();
    
    Serial.println("\n=== HOAN TAT CHUONG TRINH ===");
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
#define UART_CONFIG SERIAL_8N1 

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
// HÀM NHẬN ECHO (HIỂN THỊ HEX) - ĐỂ DEBUG H
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
        Serial.printf("❌ LOI: Timeout Echo H! Chi nhan duoc %d / %d byte.\n", received_count, TOTAL_BYTES);
        // In những gì nhận được (nếu có) để debug
        if (received_count > 0) {
            Serial.println("   Du lieu nhan duoc (chua du):");
            for(int k=0; k<received_count; k++) Serial.printf("%02X ", buffer[k]);
            Serial.println();
        }
        return;
    }

    Serial.println("✅ DA NHAN DU 128 BYTE ECHO H. So sanh HEX:");
    
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
// [MỚI] HÀM NHẬN KẾT QUẢ 12-BIT
// =================================================================
void wait_for_12bit_result() {
    Serial.println("\n🔄 DANG DOI KET QUA 12-BIT TU FPGA...");
    
    // FPGA sẽ gửi 2 byte: [Byte Cao] rồi đến [Byte Thấp]
    // Byte Cao chứa 4 bit cao của 12 bit (0000_xxxx)
    
    unsigned long start_time = millis();
    
    // Chờ nhận đủ 2 byte (Timeout 10s vì FPGA cần thời gian xử lý stream)
    while (Serial2.available() < 2) {
        if (millis() - start_time > 10000) { 
             Serial.println("❌ TIMEOUT: Khong nhan duoc ket qua 12-bit (FPGA co the chua gui).");
             return;
        }
    }

    // Đọc 2 byte
    uint8_t byte_high = Serial2.read();
    uint8_t byte_low  = Serial2.read();

    // Ghép lại thành giá trị 12-bit
    // Ép kiểu uint16_t để tránh tràn số khi dịch bit
    uint16_t result_12bit = ((uint16_t)byte_high << 8) | byte_low;

    Serial.println("✅ DA NHAN DUOC KET QUA 12-BIT!");
    Serial.printf("   - Byte High (raw): 0x%02X\n", byte_high);
    Serial.printf("   - Byte Low  (raw): 0x%02X\n", byte_low);
    Serial.printf("   => GIA TRI GOP (HEX): 0x%03X\n", result_12bit);
    Serial.printf("   => GIA TRI GOP (DEC): %d\n", result_12bit);
}

// =================================================================
// MAIN SETUP
// =================================================================
void setup() {
    Serial.begin(9600);
    //Serial2.begin(BAUD_RATE, SERIAL_8N2, RX_PIN, TX_PIN);
    //them
    Serial2.setRxBufferSize(256);
    Serial2.begin(BAUD_RATE, SERIAL_8N1, RX_PIN, TX_PIN);
    Serial.println("\n\n=== HE THONG KHOI DONG ===");
    //them
    // === NHẬP DỮ LIỆU TỪ SERIAL MONITOR ===
    Serial.println(">>> Vui long nhap ma so tao du lieu (VD: 12) vao o input va nhan Gui/Enter <<<");
    
    while (Serial.available() == 0) { delay(100); }
    long user_seed = Serial.parseInt(); 
    while(Serial.available()) Serial.read(); 

    Serial.printf("--> Da nhan ma so: %ld. Bat dau tao du lieu...\n", user_seed);
    randomSeed(user_seed); 

    // Cấp phát bộ nhớ
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    for (int i=0; i<nR; i++) { 
        H[i] = (complex_t*)malloc(nT*sizeof(complex_t)); 
        Y[i] = (complex_t*)malloc(T*sizeof(complex_t)); 
    }

    // Tạo H
    for (int r=0; r<nR; r++) {
        for (int c=0; c<nT; c++) {
            H[r][c].re = randn(); H[r][c].im = randn();
        }
    }
    
    // Tạo Y
    for(int r=0; r<nR; r++) {
        for(int s=0; s<T; s++) { 
             Y[r][s].re = randn(); Y[r][s].im = randn(); 
        }
    }

    // --- BẮT ĐẦU GIAO TIẾP ---
    
    // 1. Gửi H (Kèm lệnh 0xAA)
    send_matrix(H, nR, nT, "Ma Tran H", 0xAA);

    // 2. Chờ Echo HEX của H (để kiểm tra FPGA nhận đúng không)
    wait_for_echo_H();

    // 3. Gửi Y (Kèm lệnh 0xBB)
    delay(1000); 
    send_matrix(Y, nR, T, "Ma Tran Y", 0xBB);
    
    // 4. [MỚI] Chờ nhận kết quả 12-bit cuối cùng
    // FPGA sẽ xử lý Y xong -> Bắn sang Decoder -> Rồi mới gửi 12 bit này
    wait_for_12bit_result();
    
    Serial.println("\n=== HOAN TAT CHUONG TRINH ===");
}


void loop() { delay(1000); }
