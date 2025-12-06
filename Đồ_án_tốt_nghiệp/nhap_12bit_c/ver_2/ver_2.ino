
typedef struct {
    float re;
    float im;
} complex_t;

#include <Arduino.h>
#include <math.h>
#include <stdlib.h>
#include <cstddef>

// KẾT NỐI: ESP32 RX(16)-TX(FPGA), TX(17)-RX(FPGA), Chung GND
#define RX_PIN 16 
#define TX_PIN 17 

#define nT 4 
#define nR 4 
#define T 2   
#define nd 2  
#define TM 16 
#define SM 16 
#define SCALE_Q22 4194304.0f // 2^22

// --- DỮ LIỆU MÃ HÓA ---
const float v[4] = {-3.0f, -1.0f, 1.0f, 3.0f};
const complex_t A[2][2][2] = { {{{1,0},{0,0}}, {{0,0},{1,0}}}, {{{0,0},{-1,0}}, {{1,0},{0,0}}} };
const complex_t B[2][2][2] = { {{{1,0},{0,0}}, {{0,0},{-1,0}}}, {{{0,0},{1,0}}, {{1,0},{0,0}}} };
const complex_t S[SM][nT][T] = {
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.0,0.5}}, {{0.0,0.5},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{-0.5,0}}, {{0.5,0},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.0,-0.5}}, {{0.0,-0.5},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.0,0.5}}, {{0.0,-0.5},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{-0.5,0}}, {{0.5,0},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.0,-0.5}}, {{0.0,-0.5},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.5,0}}, {{-0.5,0},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.0,0.5}}, {{0.0,0.5},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{-0.5,0}}, {{0.5,0},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.0,-0.5}}, {{0.0,-0.5},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.5,0}}, {{-0.5,0},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.0,0.5}}, {{0.0,0.5},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{-0.5,0}}, {{0.5,0},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.0,-0.5}}, {{0.0,-0.5},{0.0,-0.5}}}
};

// --- HÀM TOÁN HỌC ---
complex_t cadd(complex_t a, complex_t b) { complex_t c = {a.re+b.re, a.im+b.im}; return c; }
complex_t cmul(complex_t a, complex_t b) { complex_t c = {a.re*b.re - a.im*b.im, a.re*b.im + a.im*b.re}; return c; }
float randn() {
    float u1 = (float)rand() / RAND_MAX;
    float u2 = (float)rand() / RAND_MAX;
    return sqrtf(-2.0f * logf(u1)) * cosf(2 * M_PI * u2);
}

void WriteComChar(char b) {
    Serial2.write((uint8_t)b);
}

// In ma trận ra màn hình
void print_matrix_float(complex_t **M, int rows, int cols, const char *label) {
    Serial.printf("\n--- KIEM TRA %s (%dx%d) ---\n", label, rows, cols);
    for (int r = 0; r < rows; r++) {
        Serial.printf("Row %d: ", r);
        for (int c = 0; c < cols; c++) {
            Serial.printf("(%7.4f, %7.4f)  ", M[r][c].re, M[r][c].im);
        }
        Serial.println(); 
    }
    Serial.println("-----------------------------------");
}

// Gửi Matrix (Little Endian)
void send_matrix(complex_t **M, int rows, int cols, const char *label, bool negate_imag) {
    Serial.printf("\n🔸 Sending %s (%dx%d) [Little Endian]...\n", label, rows, cols);
    
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            
            // 1. Phần Thực
            int32_t val_real = (int32_t)(M[r][c].re * SCALE_Q22);
            WriteComChar((val_real)       & 0xFF); // LSB
            WriteComChar((val_real >> 8)  & 0xFF);
            WriteComChar((val_real >> 16) & 0xFF);
            WriteComChar((val_real >> 24) & 0xFF); // MSB

            // 2. Phần Ảo
            float im_val = M[r][c].im;
            if (negate_imag) im_val = -im_val; // Đảo dấu nếu cần

            int32_t val_imag = (int32_t)(im_val * SCALE_Q22);
            WriteComChar((val_imag)       & 0xFF); // LSB
            WriteComChar((val_imag >> 8)  & 0xFF);
            WriteComChar((val_imag >> 16) & 0xFF);
            WriteComChar((val_imag >> 24) & 0xFF); // MSB
            
            delay(1); 
        }
    }
}

void setup() {
    Serial.begin(9600);
    Serial.setTimeout(2000); 
    Serial.println("\n--- ESP32 (FPGA OLD CODE COMPATIBLE) ---");

    Serial2.begin(9600, SERIAL_8N2, RX_PIN, TX_PIN);
    Serial.println("UART2 Connected.");

    randomSeed(analogRead(36)); 

    // 1. NHẬP LIỆU
    Serial.println("\n==============================================");
    Serial.println("Nhap 12 bit (VD: 110011001100):");
    Serial.println("==============================================");
    
    String bit_string = "";
    while(Serial.available()) Serial.read(); 
    while (true) {
        if (Serial.available() > 0) {
            bit_string = Serial.readStringUntil('\n');
            bit_string.trim();
            if (bit_string.length() == 12) break;
        }
        delay(50);
    }
    Serial.printf("✅ INPUT: %s\n", bit_string.c_str());

    // 2. CẤP PHÁT
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **C_tx = (complex_t **)malloc(nT * sizeof(complex_t*));
    for (int i = 0; i < nR; i++) { H[i] = (complex_t *)malloc(nT * sizeof(complex_t)); Y[i] = (complex_t *)malloc(T * sizeof(complex_t)); }
    for (int i = 0; i < nT; i++) { C_tx[i] = (complex_t *)malloc(T * sizeof(complex_t)); }

    // 3. MÃ HÓA
    int Sc_idx = (int)strtol(bit_string.substring(0, 4).c_str(), NULL, 2);
    int I_idx[2] = {(int)strtol(bit_string.substring(4, 6).c_str(), NULL, 2), (int)strtol(bit_string.substring(8, 10).c_str(), NULL, 2)};
    int Q_idx[2] = {(int)strtol(bit_string.substring(6, 8).c_str(), NULL, 2), (int)strtol(bit_string.substring(10, 12).c_str(), NULL, 2)};
    float xI[2] = {v[I_idx[0]], v[I_idx[1]]};
    float xQ[2] = {v[Q_idx[0]], v[Q_idx[1]]};

    complex_t X_ostbc[2][2] = {{{0}}}; 
    for (int p=0; p<nd; p++) 
        for(int r=0; r<2; r++) 
            for (int c=0; c<2; c++) {
                complex_t term1 = cmul((complex_t){xI[p],0}, A[p][r][c]);
                complex_t term2 = cmul((complex_t){0,xQ[p]}, B[p][r][c]);
                X_ostbc[r][c] = cadd(X_ostbc[r][c], cadd(term1, term2));
            }

    for (int ant=0; ant<nT; ant++) { 
        for (int ts=0; ts<T; ts++) { 
            complex_t sum = {0,0};
            for (int k=0; k<T; k++) sum = cadd(sum, cmul(S[Sc_idx][ant][k], X_ostbc[k][ts]));
            C_tx[ant][ts] = sum;
        }
    }

    // 4. MÔ PHỎNG KÊNH
    // Hardcode H là Ma trận đơn vị để Test logic (Xóa nhiễu)
    // Hoặc dùng random() nếu đã tự tin
    
    // --- MODE: RANDOM CHANNEL (Sử dụng bình thường) ---
    for (int r=0; r<nR; r++) for (int c=0; c<nT; c++) { 
        H[r][c].re = randn()/1.414f; 
        H[r][c].im = randn()/1.414f; 
    }
    float noise_var = 0.05; 
    for (int r=0; r<nR; r++) {
        for (int s=0; s<T; s++) { 
            Y[r][s] = (complex_t){sqrtf(noise_var/2)*randn(), sqrtf(noise_var/2)*randn()};
            for (int t=0; t<nT; t++) Y[r][s] = cadd(Y[r][s], cmul(H[r][t], C_tx[t][s]));
        }
    }

    // 5. IN & GỬI DỮ LIỆU
    print_matrix_float(H, nR, nT, "Ma tran H");
    print_matrix_float(Y, nR, T,  "Ma tran Y");

    // Gửi H
    send_matrix(H, nR, nT, "H", false); 
    
    // Gửi Y (CHÚ Ý: negate_imag = FALSE)
    // Vì FPGA code cũ đã có dấu trừ (-Y_in), nên ESP gửi số dương.
    send_matrix(Y, nR, T, "Y", false);   

    Serial.println("\n✅ Waiting for FPGA result...");

    // Giải phóng
    for (int i=0; i<nR; i++) { free(H[i]); free(Y[i]); }
    for (int i=0; i<nT; i++) { free(C_tx[i]); }
    free(H); free(Y); free(C_tx);

    // 6. NHẬN KẾT QUẢ
    int bytes_received = 0;
    uint8_t rx_buffer[10];
    unsigned long start_time = millis(); 

    while (bytes_received < 2 && (millis() - start_time < 5000)) {
        if (Serial2.available() > 0) {
            rx_buffer[bytes_received++] = Serial2.read();
        }
    }

    if (bytes_received >= 2) {
        uint16_t result_val = (rx_buffer[0] << 8) | rx_buffer[1];
        Serial.printf("\n📥 KET QUA FPGA chua thay doi: 0x%04X (Bin: ", result_val);
        result_val = result_val & 0x0FFF;

        Serial.printf("\n📥 KET QUA FPGA: 0x%03X (Bin: ", result_val);
        for(int i=11; i>=0; i--) Serial.print((result_val >> i) & 1);
        Serial.println(")");

        long input_val = strtol(bit_string.c_str(), NULL, 2);
        Serial.printf("📤 INPUT GOC   : 0x%03X\n", input_val);
        
        if (input_val == result_val) Serial.println("✅ MATCH!");
        else Serial.println("❌ MISMATCH!");
        
    } else {
        Serial.println("❌ TIMEOUT: Khong nhan duoc phan hoi.");
    }
    Serial2.end();
}

void loop() {
    delay(1000);
}



/*
 * CHƯƠNG TRINH ESP32: BỘ PHÁT SM-OSTBC 4x4 (HEX DEBUG MODE)
 * Tính năng mới: IN CHI TIẾT MÃ HEX CỦA TỪNG SỐ ĐƯỢC GỬI ĐI
 */
/*
#include <Arduino.h>
#include <math.h>
#include <stdlib.h>
#include <cstddef>

// ===================== 1. CẤU HÌNH =====================
#define RX_PIN 16 
#define TX_PIN 17 

#define nT 4 
#define nR 4 
#define T 2   
#define nd 2  
#define TM 16 
#define SM 16 
#define SCALE_Q22 4194304.0 // Double precision for scale

typedef struct {
    double re;
    double im;
} complex_t;

// ===================== 2. DỮ LIỆU MÃ HÓA =====================
const double v[4] = {-3.0, -1.0, 1.0, 3.0};
const complex_t A[2][2][2] = { {{{1,0},{0,0}}, {{0,0},{1,0}}}, {{{0,0},{-1,0}}, {{1,0},{0,0}}} };
const complex_t B[2][2][2] = { {{{1,0},{0,0}}, {{0,0},{-1,0}}}, {{{0,0},{1,0}}, {{1,0},{0,0}}} };

const complex_t S[SM][nT][T] = {
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.0,0.5}}, {{0.0,0.5},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{-0.5,0}}, {{0.5,0},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.5,0},{0.0,-0.5}}, {{0.0,-0.5},{0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.0,0.5}}, {{0.0,-0.5},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{-0.5,0}}, {{0.5,0},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{-0.5,0},{0.0,-0.5}}, {{0.0,-0.5},{-0.5,0}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.5,0}}, {{-0.5,0},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.0,0.5}}, {{0.0,0.5},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{-0.5,0}}, {{0.5,0},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,0.5},{0.0,-0.5}}, {{0.0,-0.5},{0.0,0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.5,0}}, {{-0.5,0},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.0,0.5}}, {{0.0,0.5},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{-0.5,0}}, {{0.5,0},{0.0,-0.5}}},
    {{{0.5,0},{0.5,0}}, {{-0.5,0},{0.5,0}}, {{0.0,-0.5},{0.0,-0.5}}, {{0.0,-0.5},{0.0,-0.5}}}
};

// ===================== 3. HÀM HỖ TRỢ =====================
complex_t cadd(complex_t a, complex_t b) { complex_t c = {a.re+b.re, a.im+b.im}; return c; }
complex_t cmul(complex_t a, complex_t b) { complex_t c = {a.re*b.re - a.im*b.im, a.re*b.im + a.im*b.re}; return c; }

double randn() {
    double u1 = (double)rand() / RAND_MAX;
    double u2 = (double)rand() / RAND_MAX;
    return sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI * u2);
}

void WriteComChar(char b) {
    Serial2.write((uint8_t)b);
}

// ===================== 4. HÀM GỬI DỮ LIỆU & IN HEX =====================
void send_matrix(complex_t **M, int rows, int cols, const char *label, bool negate_imag) {
    Serial.printf("\n🔸 Sending %s (%dx%d)...\n", label, rows, cols);
    Serial.println("Format in ra: [Ten][Hang][Cot] GiaTriThuc -> Hex (LSB...MSB)");

    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            
            // --- XỬ LÝ PHẦN THỰC ---
            int32_t val_real = lround(M[r][c].re * SCALE_Q22);
            
            uint8_t b0_r = (val_real)       & 0xFF; // LSB
            uint8_t b1_r = (val_real >> 8)  & 0xFF;
            uint8_t b2_r = (val_real >> 16) & 0xFF;
            uint8_t b3_r = (val_real >> 24) & 0xFF; // MSB

            // Gửi đi
            WriteComChar(b0_r); WriteComChar(b1_r); WriteComChar(b2_r); WriteComChar(b3_r);

            // --- IN MÃ HEX PHẦN THỰC ---
            // In theo thứ tự gửi: Byte 0 (LSB) -> Byte 3 (MSB)
            Serial.printf(" %s_R[%d][%d]: %9.6f -> Int:%10d -> Hex: %02X %02X %02X %02X\n", 
                          label, r, c, M[r][c].re, val_real, b0_r, b1_r, b2_r, b3_r);


            // --- XỬ LÝ PHẦN ẢO ---
            double im_val = M[r][c].im;
            if (negate_imag) im_val = -im_val; 

            int32_t val_imag = lround(im_val * SCALE_Q22);
            
            uint8_t b0_i = (val_imag)       & 0xFF;
            uint8_t b1_i = (val_imag >> 8)  & 0xFF;
            uint8_t b2_i = (val_imag >> 16) & 0xFF;
            uint8_t b3_i = (val_imag >> 24) & 0xFF;

            // Gửi đi
            WriteComChar(b0_i); WriteComChar(b1_i); WriteComChar(b2_i); WriteComChar(b3_i);

            // --- IN MÃ HEX PHẦN ẢO ---
            Serial.printf(" %s_I[%d][%d]: %9.6f -> Int:%10d -> Hex: %02X %02X %02X %02X\n", 
                          label, r, c, im_val, val_imag, b0_i, b1_i, b2_i, b3_i);
            
            delay(2); 
        }
    }
    Serial.println("✅ Xong ma tran.");
}

// ===================== 5. SETUP & MAIN =====================
void setup() {
    Serial.begin(9600);
    Serial.setTimeout(2000); 
    Serial.println("\n--- ESP32 HEX DEBUGGER ---");

    Serial2.begin(9600, SERIAL_8N2, RX_PIN, TX_PIN);
    Serial.println("UART2 Initialized.");

    randomSeed(analogRead(36)); 

    // --- 1. NHẬP LIỆU ---
    Serial.println("\n==============================================");
    Serial.println("Nhap 12 bit (VD: 110011001100):");
    Serial.println("==============================================");
    
    String bit_string = "";
    while(Serial.available()) Serial.read(); 
    while (true) {
        if (Serial.available() > 0) {
            bit_string = Serial.readStringUntil('\n');
            bit_string.trim();
            if (bit_string.length() == 12) break;
        }
        delay(50);
    }
    Serial.printf("✅ INPUT: %s\n", bit_string.c_str());

    // --- 2. CẤP PHÁT BỘ NHỚ ---
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **C_tx = (complex_t **)malloc(nT * sizeof(complex_t*));
    for (int i = 0; i < nR; i++) { H[i] = (complex_t *)malloc(nT * sizeof(complex_t)); Y[i] = (complex_t *)malloc(T * sizeof(complex_t)); }
    for (int i = 0; i < nT; i++) { C_tx[i] = (complex_t *)malloc(T * sizeof(complex_t)); }

    // --- 3. MÃ HÓA (ENCODING) ---
    int Sc_idx = (int)strtol(bit_string.substring(0, 4).c_str(), NULL, 2);
    int I_idx[2] = {(int)strtol(bit_string.substring(4, 6).c_str(), NULL, 2), (int)strtol(bit_string.substring(8, 10).c_str(), NULL, 2)};
    int Q_idx[2] = {(int)strtol(bit_string.substring(6, 8).c_str(), NULL, 2), (int)strtol(bit_string.substring(10, 12).c_str(), NULL, 2)};
    double xI[2] = {v[I_idx[0]], v[I_idx[1]]};
    double xQ[2] = {v[Q_idx[0]], v[Q_idx[1]]};

    complex_t X_ostbc[2][2] = {{{0}}}; 
    for (int p=0; p<nd; p++) for(int r=0; r<2; r++) for (int c=0; c<2; c++) {
        X_ostbc[r][c] = cadd(X_ostbc[r][c], cadd(cmul((complex_t){xI[p],0}, A[p][r][c]), cmul((complex_t){0,xQ[p]}, B[p][r][c])));
    }
    for (int ant=0; ant<nT; ant++) for (int ts=0; ts<T; ts++) { 
        complex_t sum = {0,0};
        for (int k=0; k<T; k++) sum = cadd(sum, cmul(S[Sc_idx][ant][k], X_ostbc[k][ts]));
        C_tx[ant][ts] = sum;
    }

    // --- 4. MÔ PHỎNG KÊNH (RANDOM CHANNEL) ---
    for (int r=0; r<nR; r++) for (int c=0; c<nT; c++) { 
        H[r][c].re = randn()/1.414; H[r][c].im = randn()/1.414; 
    }
    double noise_var = 0.05; 
    for (int r=0; r<nR; r++) for (int s=0; s<T; s++) { 
        Y[r][s] = (complex_t){sqrt(noise_var/2.0)*randn(), sqrt(noise_var/2.0)*randn()};
        for (int t=0; t<nT; t++) Y[r][s] = cadd(Y[r][s], cmul(H[r][t], C_tx[t][s]));
    }

    // --- 5. GỬI DỮ LIỆU & IN DEBUG HEX ---
    // Gửi H: negate_imag = false
    send_matrix(H, nR, nT, "H", false); 
    
    // Gửi Y: negate_imag = false (FPGA tự trừ)
    send_matrix(Y, nR, T, "Y", false);   

    Serial.println("\n✅ Waiting for FPGA result...");

    // Giải phóng bộ nhớ
    for (int i=0; i<nR; i++) { free(H[i]); free(Y[i]); }
    for (int i=0; i<nT; i++) { free(C_tx[i]); }
    free(H); free(Y); free(C_tx);

    // --- 6. NHẬN KẾT QUẢ TỪ FPGA ---
    int bytes_received = 0;
    uint8_t rx_buffer[10];
    unsigned long start_time = millis(); 

    while (bytes_received < 2 && (millis() - start_time < 5000)) {
        if (Serial2.available() > 0) {
            uint8_t in_byte = Serial2.read();
            rx_buffer[bytes_received] = in_byte;
            // In debug từng byte nhận được
            Serial.printf(" [RX] Byte %d: 0x%02X\n", bytes_received, in_byte);
            bytes_received++;
        }
    }

    if (bytes_received >= 2) {
        uint16_t result_val = (rx_buffer[0] << 8) | rx_buffer[1];
        result_val = result_val & 0x0FFF;

        Serial.printf("\n📥 KET QUA FPGA: 0x%03X (Bin: ", result_val);
        for(int i=11; i>=0; i--) Serial.print((result_val >> i) & 1);
        Serial.println(")");

        long input_val = strtol(bit_string.c_str(), NULL, 2);
        Serial.printf("📤 INPUT GOC   : 0x%03X\n", input_val);
        
        if (input_val == result_val) Serial.println("✅ MATCH!");
        else Serial.println("❌ MISMATCH!");
        
    } else {
        Serial.println("❌ TIMEOUT: Khong nhan duoc phan hoi.");
    }
    Serial2.end();
}

void loop() {
    delay(1000);
}
*/
