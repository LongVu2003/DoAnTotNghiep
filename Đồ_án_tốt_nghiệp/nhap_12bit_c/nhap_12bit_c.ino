/*
 * CHƯƠNG TRINH ESP32: BỘ PHÁT SM-OSTBC 4x4 (Encoder)
 *
 * 1. Sửa đổi để NHẬP 12-BIT từ Serial Monitor.
 * 2. Tạo ma trận phát C_tx[4][2] (thay cho X ngẫu nhiên).
 * 3. Tính Y = H*C_tx + N.
 * 4. Gửi H[4][4] và Y[4][2] qua UART (Serial2)
 * với định dạng MSB-first (sửa lỗi Endian).
 * 5. Nhận và kiểm tra (echo) phản hồi từ FPGA.
 */

// ==================== CẤU TRÚC SỐ PHỨC (float) ====================
// *** SỬA LỖI: Di chuyển typedef LÊN TRÊN CÙNG ***
// Định nghĩa này PHẢI có trước các #include
// để trình auto-prototype của Arduino IDE hiểu được 'complex_t'
typedef struct {
    float re;
    float im;
} complex_t;


#include <Arduino.h> // Thư viện cơ bản của Arduino
#include <math.h>    // Cho sqrtf, logf, cosf, M_PI
#include <stdlib.h>  // Cho malloc, free, rand, srand
#include <cstddef>   // *** SỬA LỖI: Thêm vào cho 'size_t' ***


// =================== CẤU HÌNH UART (PHẦN CỨNG) ===================
#define RX_PIN 16 // Nối với chân TX của FPGA
#define TX_PIN 17 // Nối với chân RX của FPGA

// =Parameters from sm_ostbc.c
#define nT 4 // Tx antennas
#define nR 4 // Rx antennas
#define T 2  // Symbol periods per block
#define nd 2 // QAM symbols per block
#define TM 16 // 16-QAM
#define SM 16 // #SC codewords

// ==================== CÁC HẰNG SỐ MÃ HÓA (Đã port từ C-sim) ====================

// 16-QAM constellation (real/imag parts)
const float v[4] = {-3.0f, -1.0f, 1.0f, 3.0f};

// Alamouti dispersion matrices (2x2)
// A[p][row][col]
const complex_t A[2][2][2] = {
    {{{1,0},{0,0}}, {{0,0},{1,0}}},  // A(:,:,1) = [[1 0];[0 1]]
    {{{0,0},{-1,0}}, {{1,0},{0,0}}}  // A(:,:,2) = [[0 -1];[1 0]]
};
const complex_t B[2][2][2] = {
    {{{1,0},{0,0}}, {{0,0},{-1,0}}}, // B(:,:,1) = [[1 0];[0 -1]]
    {{{0,0},{1,0}}, {{1,0},{0,0}}}   // B(:,:,2) = [[0 1];[1 0]]
};

// 16 SC codewords S(:,:,k) – 4x2, already divided by 2
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

// ==================== HÀM HELPER (Toán tử số phức) ====================
complex_t cadd(complex_t a, complex_t b) { complex_t c = {a.re+b.re, a.im+b.im}; return c; }
complex_t csub(complex_t a, complex_t b) { complex_t c = {a.re-b.re, a.im-b.im}; return c; }
complex_t cmul(complex_t a, complex_t b) { complex_t c = {a.re*b.re - a.im*b.im, a.re*b.im + a.im*b.re}; return c; }
complex_t conjg(complex_t a) { complex_t c = {a.re, -a.im}; return c; }
float       cabs2(complex_t a) { return a.re*a.re + a.im*a.im; }

// ==================== SINH SỐ NGẪU NHIÊN GAUSSIAN (Giữ nguyên) ====================
float randn() {
    float u1 = (float)rand() / RAND_MAX;
    float u2 = (float)rand() / RAND_MAX;
    return sqrtf(-2.0f * logf(u1)) * cosf(2 * M_PI * u2);
}

////////////////////////////////////////////////////////
// PHẦN 1: GIAO TIẾP COM (ĐÃ PORT VÀ SỬA LỖI)
////////////////////////////////////////////////////////
size_t WriteCom(char* buf, int len)
{
    return Serial2.write((uint8_t*)buf, len);
}

void WriteComChar(char b)
{
    Serial2.write((uint8_t)b);
}

// ==================== HÀM GỬI MA TRẬN (ĐÃ SỬA LỖI ENDIANNESS) ====================
void send_matrix(complex_t **M, int rows, int cols, const char *label) {
    Serial.printf("\n🔸 Gui ma tran %s (%dx%d):\n", label, rows, cols);
    
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            
            // SỬA LỖI ENDIAN: Gửi 4 byte của float theo thứ tự MSB-first
            union {
                float f;
                uint8_t b[4];
            } float_converter;

            // 1. Gửi Phần Thực (re) - MSB first
            float_converter.f = M[r][c].re;
            WriteComChar(float_converter.b[3]); // Gửi MSB (Byte 3)
            WriteComChar(float_converter.b[2]); // Gửi (Byte 2)
            WriteComChar(float_converter.b[1]); // Gửi (Byte 1)
            WriteComChar(float_converter.b[0]); // Gửi LSB (Byte 0)

            // 2. Gửi Phần Ảo (im) - MSB first
            float_converter.f = M[r][c].im;
            WriteComChar(float_converter.b[3]); // Gửi MSB (Byte 3)
            WriteComChar(float_converter.b[2]); // Gửi (Byte 2)
            WriteComChar(float_converter.b[1]); // Gửi (Byte 1)
            WriteComChar(float_converter.b[0]); // Gửi LSB (Byte 0)
            
            // In ra USB để gỡ lỗi
            Serial.printf("%s[%d][%d] = (%f, %f)\n", label, r, c, M[r][c].re, M[r][c].im);
            
            // Delay 1ms (giống code gốc)
            delay(1);
        }
    }
}


////////////////////////////////////////////////////////
// PHẦN 3: HÀM MAIN (Đã chuyển thành setup() của Arduino)
////////////////////////////////////////////////////////
/*
void setup()
{
    // === Khởi tạo Serial Monitor (USB) để xem debug ===
    Serial.begin(9600); // Dùng baud rate cao cho Serial Monitor
    Serial.println("\n--- CHUONG TRINH KHOI DONG (SM-OSTBC ENCODER) ---");

    // === Khởi tạo Serial2 (gửi đến FPGA) ===
    Serial2.begin(9600, SERIAL_8N2, RX_PIN, TX_PIN);
    Serial.println("Da mo cong Serial2 (UART2) de gui den FPGA.");

    // === Khởi tạo bộ sinh số ngẫu nhiên ===
    // GIỮ LẠI: Vẫn cần cho randn() (Kênh và Nhiễu)
    randomSeed(analogRead(36)); 

    int total_bytes_sent = 0;

    // ========================================================
    // *** THAY ĐỔI BẮT ĐẦU: YÊU CẦU NHẬP 12 BIT ***
    // ========================================================

    Serial.println("\nVui long nhap 12 bit (vi du: 010111001010)");
    Serial.println("vao Serial Monitor va nhan Enter:");
    
    String bit_string = "";
    while (true) {
        if (Serial.available() > 0) {
            bit_string = Serial.readStringUntil('\n');
            bit_string.trim(); // Xóa ký tự \r hoặc \n nếu có
            
            // 1. Kiểm tra độ dài
            if (bit_string.length() != 12) {
                Serial.printf("LOI: Da nhan %d bit, yeu cau 12 bit. Thu lai: \n", bit_string.length());
                continue;
            }
            
            // 2. Kiểm tra nội dung (chỉ 0 hoặc 1)
            bool valid = true;
            for (int i = 0; i < 12; i++) {
                if (bit_string.charAt(i) != '0' && bit_string.charAt(i) != '1') {
                    Serial.println("LOI: Chuoi phai chi chua '0' hoac '1'. Thu lai:");
                    valid = false;
                    break;
                }
            }
            
            if (valid) {
                Serial.printf("Da nhan 12 bit hop le: %s\n", bit_string.c_str());
                break; // Thoát khỏi vòng lặp while(true)
            }
        }
        delay(100); // Chờ input
    }
    // ========================================================
    // *** THAY ĐỔI KẾT THÚC ***
    // ========================================================


    // === Cấp phát ma trận (H và Y) ===
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    // Cấp phát ma trận C_tx (ma trận phát 4x2)
    complex_t **C_tx = (complex_t **)malloc(nT * sizeof(complex_t*));

    for (int i = 0; i < nR; i++) { // nR = 4
        H[i] = (complex_t *)malloc(nT * sizeof(complex_t));
        Y[i] = (complex_t *)malloc(T * sizeof(complex_t)); // T = 2
    }
    for (int i = 0; i < nT; i++) { // nT = 4
        C_tx[i] = (complex_t *)malloc(T * sizeof(complex_t)); // T = 2
    }


    // ========================================================
    // PHẦN 1: BỘ MÃ HÓA (ENCODER) SM-OSTBC
    // ========================================================
    Serial.println("Dang ma hoa 12-bit -> C_tx[4][2]...");

    // ========================================================
    // *** THAY ĐỔI BẮT ĐẦU: PHÂN TÍCH 12 BIT TỪ INPUT ***
    // ========================================================
    // 1.1. Phân tích 12 bit từ chuỗi 'bit_string'
    
    // Tách chuỗi 12-bit thành các phần nhỏ
    // (stdlib.h đã được #include trong code gốc của bạn)
    String sc_str = bit_string.substring(0, 4);   // Bits 1-4
    String i1_str = bit_string.substring(4, 6);   // Bits 5-6 (I, symbol 1)
    String q1_str = bit_string.substring(6, 8);   // Bits 7-8 (Q, symbol 1)
    String i2_str = bit_string.substring(8, 10);  // Bits 9-10 (I, symbol 2)
    String q2_str = bit_string.substring(10, 12); // Bits 11-12 (Q, symbol 2)

    // Chuyển chuỗi bit (base 2) sang số nguyên (base 10)
    int Sc_idx = (int)strtol(sc_str.c_str(), NULL, 2); // 4 bits -> 0-15
    
    int I_idx[nd];
    int Q_idx[nd];
    
    I_idx[0] = (int)strtol(i1_str.c_str(), NULL, 2); // 2 bits -> 0-3
    Q_idx[0] = (int)strtol(q1_str.c_str(), NULL, 2); // 2 bits -> 0-3
    I_idx[1] = (int)strtol(i2_str.c_str(), NULL, 2); // 2 bits -> 0-3
    Q_idx[1] = (int)strtol(q2_str.c_str(), NULL, 2); // 2 bits -> 0-3

    // Lấy giá trị float tương ứng từ các chỉ số
    float xI[nd], xQ[nd];
    xI[0] = v[I_idx[0]];
    xQ[0] = v[Q_idx[0]];
    xI[1] = v[I_idx[1]];
    xQ[1] = v[Q_idx[1]];
    // ========================================================
    // *** THAY ĐỔI KẾT THÚC (PHẦN rand() ĐÃ BỊ XÓA) ***
    // ========================================================

    Serial.printf("  Input 12 bits -> Sc_idx: %d, I: {%d, %d}, Q: {%d, %d}\n",
                  Sc_idx, I_idx[0], I_idx[1], Q_idx[0], Q_idx[1]);

    // 1.2. Build OSTBC X_ostbc (2x2)
    complex_t X_ostbc[2][2] = {{{0}}}; // Khởi tạo 0
    for (int p=0; p<nd; p++) {
        for(int r=0; r<2; r++) {
            for (int c=0; c<2; c++) {
                // (complex_t){xI[p], 0}
                complex_t tmpA = cmul((complex_t){xI[p], 0}, A[p][r][c]);
                complex_t tmpB = cmul((complex_t){0, xQ[p]}, B[p][r][c]);
                X_ostbc[r][c] = cadd(X_ostbc[r][c], cadd(tmpA, tmpB));
            }
        }
    }

    // 1.3. Tính ma trận phát C_tx = S[Sc_idx] * X_ostbc (4x2)
    // (Đây là "ma trận X" 4x2 mà bạn muốn)
    for (int ant=0; ant<nT; ant++) { // nT = 4
        for (int ts=0; ts<T; ts++) { // T = 2
            complex_t sum = {0,0};
            for (int k=0; k<T; k++) { // T = 2
                sum = cadd(sum, cmul(S[Sc_idx][ant][k], X_ostbc[k][ts]));
            }
            C_tx[ant][ts] = sum;
        }
    }
    Serial.println("  -> Da tao ma tran C_tx[4][2] (Ma tran phat).");


    // ========================================================
    // PHẦN 2: MÔ PHỎNG KÊNH VÀ TÍN HIỆU NHẬN
    // ========================================================

    // 2.1. TẠO MA TRẬN KÊNH H (4x4)
    Serial.println("Dang tao ma tran H[4][4]...");
    for (int r = 0; r < nR; r++) {
        for (int c = 0; c < nT; c++) {
            H[r][c].re = randn() / sqrtf(2.0f);
            H[r][c].im = randn() / sqrtf(2.0f);
        }
    }

    // 2.2. TẠO NHIỄU GAUSSIAN N (4x2)
    float noise_var = 0.05; // Giữ nguyên noise_var
    complex_t N[4][2];
    for (int r = 0; r < nR; r++) {
        for (int s = 0; s < T; s++) { // T = 2
            N[r][s].re = sqrtf(noise_var / 2) * randn();
            N[r][s].im = sqrtf(noise_var / 2) * randn();
        }
    }

    // 2.3. TÍNH Y = H * C_tx + N (4x2)
    Serial.println("Dang tinh ma tran Y = H*C_tx + N...");
    for (int r = 0; r < nR; r++) {
        for (int s = 0; s < T; s++) { // T = 2
            Y[r][s].re = 0;
            Y[r][s].im = 0;
            // Tính H * C_tx
            for (int t = 0; t < nT; t++) { // nT = 4
                float re_part = H[r][t].re * C_tx[t][s].re - H[r][t].im * C_tx[t][s].im;
                float im_part = H[r][t].re * C_tx[t][s].im + H[r][t].im * C_tx[t][s].re;
                Y[r][s].re += re_part;
                Y[r][s].im += im_part;
            }
            // cộng nhiễu N
            Y[r][s].re += N[r][s].re;
            Y[r][s].im += N[r][s].im;
        }
    }

    // ========================================================
    // PHẦN 3: GỬI DỮ LIỆU QUA UART
    // ========================================================
    Serial.println("\n🔹 Bat dau gui du lieu qua UART (Serial2)...");
    
    // Gửi ma trận H
    send_matrix(H, nR, nT, "H");
    total_bytes_sent += (nR * nT * 8); // 4*4*8 = 128 bytes

    // Gửi ma trận Y
    send_matrix(Y, nR, T, "Y"); // T = 2
    total_bytes_sent += (nR * T * 8); // 4*2*8 = 64 bytes

    Serial.println("\n✅ Hoan tat gui ma tran H va Y.");
    Serial.printf("Tong so byte da gui: %d\n", total_bytes_sent); // 128 + 64 = 192 bytes

    // ========================================================
    // PHẦN 4: GIẢI PHÓNG BỘ NHỚ
    // ========================================================
    for (int i = 0; i < nR; i++) {
        free(H[i]);
        free(Y[i]);
    }
    for (int i = 0; i < nT; i++) {
        free(C_tx[i]);
    }
    free(H);
    free(Y);
    free(C_tx);

    // ========================================================
    // PHẦN 5: NHẬN PHẢN HỒI (ECHO) TỪ FPGA
    // ========================================================
    Serial.println("\n🔄 Dang cho phan hoi (echo) tu FPGA...");
    
    int bytes_received = 0;
    unsigned long start_time = millis(); // Bắt đầu đếm giờ
    const unsigned long TIMEOUT_MS = 5000; // Chờ 5 giây

    Serial.println("Nhan duoc (HEX):");

    while (bytes_received < total_bytes_sent && (millis() - start_time < TIMEOUT_MS))
    {
        if (Serial2.available() > 0)
        {
            uint8_t echo_byte = Serial2.read();
            Serial.printf("%02X ", echo_byte);
            bytes_received++;

            if (bytes_received % 16 == 0)
            {
                Serial.println();
            }
        }
    }

    // ===== Đánh giá kết quả Echo =====
    Serial.println("\n--- Ket thuc phan hoi ---");
    if (bytes_received == total_bytes_sent)
    {
        Serial.println("✅ OK: Da nhan du (echo) so byte.");
    }
    else
    {
        Serial.printf("❌ LOI: Chi nhan duoc %d / %d byte (Timeout?).\n", bytes_received, total_bytes_sent);
    }

    // ===== Đóng cổng COM =====
    Serial2.end();
    Serial.println("Da dong cong Serial2. ESP se vao che do ranh.");
}
*/
void setup()
{
    // === Khởi tạo Serial Monitor (USB) ===
    Serial.begin(9600);
    // Tăng timeout đọc chuỗi lên 2 giây để tránh bị cắt giữa chừng
    Serial.setTimeout(2000); 
    
    Serial.println("\n--- CHUONG TRINH KHOI DONG (SM-OSTBC ENCODER) ---");

    // === Khởi tạo Serial2 (gửi đến FPGA) ===
    // RX=16, TX=17
    Serial2.begin(9600, SERIAL_8N2, RX_PIN, TX_PIN);
    Serial.println("Da mo cong Serial2 (UART2) de gui den FPGA.");

    // === Khởi tạo Random ===
    randomSeed(analogRead(36)); 
    int total_bytes_sent = 0;

    // ========================================================
    // *** PHẦN NHẬP 12 BIT ĐÃ CẢI TIẾN ***
    // ========================================================

    Serial.println("\n==============================================");
    Serial.println("Vui long nhap 12 bit (vi du: 010111001010)");
    Serial.println("Luu y: Chinh Serial Monitor thanh 'Newline'");
    Serial.println("==============================================");
    
    String bit_string = "";
    
    // Xóa sạch bộ đệm Serial trước khi bắt đầu để tránh rác
    while(Serial.available()) Serial.read();

    while (true) {
        if (Serial.available() > 0) {
            // Đọc chuỗi cho đến khi gặp xuống dòng
            bit_string = Serial.readStringUntil('\n');
            bit_string.trim(); // Xóa khoảng trắng, \r, \n ở đầu cuối
            
            // Nếu chuỗi rỗng (do lỡ tay ấn Enter), bỏ qua
            if (bit_string.length() == 0) continue;

            // 1. Kiểm tra độ dài
            if (bit_string.length() != 12) {
                Serial.printf("LOI: Nhan duoc [%s] (Do dai: %d).\n", bit_string.c_str(), bit_string.length());
                Serial.println("-> Yeu cau dung 12 bit. Vui long nhap lai:");
                
                // Xóa bộ đệm nếu còn rác
                while(Serial.available()) Serial.read();
                continue;
            }
            
            // 2. Kiểm tra nội dung (chỉ 0 hoặc 1)
            bool valid = true;
            for (int i = 0; i < 12; i++) {
                if (bit_string.charAt(i) != '0' && bit_string.charAt(i) != '1') {
                    Serial.printf("LOI: Ky tu tai vi tri %d la '%c' khong hop le.\n", i, bit_string.charAt(i));
                    Serial.println("-> Chi chap nhan '0' hoac '1'. Nhap lai:");
                    valid = false;
                    break;
                }
            }
            
            if (valid) {
                Serial.printf("✅ Da nhan 12 bit hop le: %s\n", bit_string.c_str());
                break; // Thoát vòng lặp
            }
        }
        delay(50); // Chờ input
    }

    // ========================================================
    // CÁC PHẦN SAU GIỮ NGUYÊN
    // ========================================================

    // === Cấp phát ma trận (H và Y) ===
    complex_t **H = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **Y = (complex_t **)malloc(nR * sizeof(complex_t*));
    complex_t **C_tx = (complex_t **)malloc(nT * sizeof(complex_t*));

    for (int i = 0; i < nR; i++) { 
        H[i] = (complex_t *)malloc(nT * sizeof(complex_t));
        Y[i] = (complex_t *)malloc(T * sizeof(complex_t)); 
    }
    for (int i = 0; i < nT; i++) { 
        C_tx[i] = (complex_t *)malloc(T * sizeof(complex_t)); 
    }

    // ... (Phần logic mã hóa giữ nguyên như code cũ của bạn) ...
    // ... Bạn copy phần còn lại từ code cũ vào đây ...
    // Để code gọn, tôi chỉ viết lại phần Input logic ở trên.
    // Dưới đây là phần nối tiếp logic mã hóa để bạn dễ copy:
    
    Serial.println("Dang ma hoa 12-bit -> C_tx[4][2]...");

    String sc_str = bit_string.substring(0, 4);    // Bits 1-4
    String i1_str = bit_string.substring(4, 6);    // Bits 5-6 
    String q1_str = bit_string.substring(6, 8);    // Bits 7-8 
    String i2_str = bit_string.substring(8, 10);   // Bits 9-10
    String q2_str = bit_string.substring(10, 12);  // Bits 11-12

    int Sc_idx = (int)strtol(sc_str.c_str(), NULL, 2); 
    
    int I_idx[nd];
    int Q_idx[nd];
    
    I_idx[0] = (int)strtol(i1_str.c_str(), NULL, 2); 
    Q_idx[0] = (int)strtol(q1_str.c_str(), NULL, 2); 
    I_idx[1] = (int)strtol(i2_str.c_str(), NULL, 2); 
    Q_idx[1] = (int)strtol(q2_str.c_str(), NULL, 2); 

    float xI[nd], xQ[nd];
    xI[0] = v[I_idx[0]];
    xQ[0] = v[Q_idx[0]];
    xI[1] = v[I_idx[1]];
    xQ[1] = v[Q_idx[1]];

    Serial.printf("  Input 12 bits -> Sc_idx: %d, I: {%d, %d}, Q: {%d, %d}\n",
                  Sc_idx, I_idx[0], I_idx[1], Q_idx[0], Q_idx[1]);

    // 1.2. Build OSTBC X_ostbc (2x2)
    complex_t X_ostbc[2][2] = {{{0}}}; 
    for (int p=0; p<nd; p++) {
        for(int r=0; r<2; r++) {
            for (int c=0; c<2; c++) {
                complex_t tmpA = cmul((complex_t){xI[p], 0}, A[p][r][c]);
                complex_t tmpB = cmul((complex_t){0, xQ[p]}, B[p][r][c]);
                X_ostbc[r][c] = cadd(X_ostbc[r][c], cadd(tmpA, tmpB));
            }
        }
    }

    // 1.3. Tính C_tx
    for (int ant=0; ant<nT; ant++) { 
        for (int ts=0; ts<T; ts++) { 
            complex_t sum = {0,0};
            for (int k=0; k<T; k++) { 
                sum = cadd(sum, cmul(S[Sc_idx][ant][k], X_ostbc[k][ts]));
            }
            C_tx[ant][ts] = sum;
        }
    }
    Serial.println("  -> Da tao ma tran C_tx[4][2] (Ma tran phat).");

    // --- PHẦN TẠO KÊNH VÀ GỬI UART ---
    // (Giữ nguyên logic tạo H, N, Y và gửi UART như code gốc của bạn)
    // Tôi copy lại đoạn tạo H để code chạy được ngay:
    
    Serial.println("Dang tao ma tran H[4][4]...");
    for (int r = 0; r < nR; r++) {
        for (int c = 0; c < nT; c++) {
            H[r][c].re = randn() / sqrtf(2.0f);
            H[r][c].im = randn() / sqrtf(2.0f);
        }
    }

    float noise_var = 0.05; 
    complex_t N[4][2];
    for (int r = 0; r < nR; r++) {
        for (int s = 0; s < T; s++) { 
            N[r][s].re = sqrtf(noise_var / 2) * randn();
            N[r][s].im = sqrtf(noise_var / 2) * randn();
        }
    }

    Serial.println("Dang tinh ma tran Y = H*C_tx + N...");
    for (int r = 0; r < nR; r++) {
        for (int s = 0; s < T; s++) { 
            Y[r][s].re = 0; Y[r][s].im = 0;
            for (int t = 0; t < nT; t++) { 
                float re_part = H[r][t].re * C_tx[t][s].re - H[r][t].im * C_tx[t][s].im;
                float im_part = H[r][t].re * C_tx[t][s].im + H[r][t].im * C_tx[t][s].re;
                Y[r][s].re += re_part;
                Y[r][s].im += im_part;
            }
            Y[r][s].re += N[r][s].re;
            Y[r][s].im += N[r][s].im;
        }
    }

    Serial.println("\n🔹 Bat dau gui du lieu qua UART (Serial2)...");
    send_matrix(H, nR, nT, "H");
    total_bytes_sent += (nR * nT * 8); 
    send_matrix(Y, nR, T, "Y"); 
    total_bytes_sent += (nR * T * 8); 

    Serial.println("\n✅ Hoan tat gui ma tran H va Y.");
    Serial.printf("Tong so byte da gui: %d\n", total_bytes_sent); 

    // Giai phong bo nho
    for (int i = 0; i < nR; i++) { free(H[i]); free(Y[i]); }
    for (int i = 0; i < nT; i++) { free(C_tx[i]); }
    free(H); free(Y); free(C_tx);

    // --- PHẦN NHẬN ECHO ---
    Serial.println("\n🔄 Dang cho phan hoi (echo) tu FPGA...");
    int bytes_received = 0;
    unsigned long start_time = millis(); 
    const unsigned long TIMEOUT_MS = 10000; // Tang len 10s cho chac

    Serial.println("Nhan duoc (HEX):");
    while (bytes_received < total_bytes_sent && (millis() - start_time < TIMEOUT_MS))
    {
        if (Serial2.available() > 0) {
            uint8_t echo_byte = Serial2.read();
            Serial.printf("%02X ", echo_byte);
            bytes_received++;
            if (bytes_received % 16 == 0) Serial.println();
        }
    }

    Serial.println("\n--- Ket thuc phan hoi ---");
    if (bytes_received == total_bytes_sent) {
        Serial.println("✅ OK: Da nhan du (echo) so byte.");
    } else {
        Serial.printf("❌ LOI: Chi nhan duoc %d / %d byte.\n", bytes_received, total_bytes_sent);
    }

    Serial2.end();
    Serial.println("Da dong cong Serial2.");
}
void loop()
{
    // Không làm gì cả
    delay(1000);
}
