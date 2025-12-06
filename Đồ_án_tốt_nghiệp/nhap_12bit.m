% Program to simulate a SINGLE block of SM-OSTBC
% 1. Input 12 bits from user
% 2. Map to SC codeword + 2 16-QAM symbols (Transmitter)
% 3. Simulate channel (H) and noise (Z)
% 4. Calculate received signal (Y)
% 5. Run SO-ML detector to find the bits (Receiver)
% 6. Compare input and detected bits

clc;
clear;
close all;

%*********************************************************
% CÁC HẰNG SỐ TỪ CODE MÔ PHỎNG GỐC
%*********************************************************

nT=4;                       % No of TxAnt
nR=4;                       % No of RxAnt
T=2;                        %No of symbol periods per block
nd=2;                       % Number of QAM symbol per Alamouti Code block

TM=16;                      %16-QAM Modulation
ml=log2(TM);                %Number of bits per 16-QAM symbol
SM=16;                      %Number of SC codewords
m=log2(SM);                 %Number of bits per SC codeword

%----- Cài đặt SNR (Lấy từ code gốc của bạn) -----
SNRdB_val = 15; % Giả sử SNR là 15dB
SNR = 10.^(SNRdB_val/10);
Es = 10; % Symbol energy of 16-QAM  
S_SNR = sqrt(SNR) ./ sqrt(2*Es);

%-------Store integer values for 16-QAM modulation -----
v = [-3 -1 1 3];

%------Store bit sequence for 16-QAM symbol mapping (Gray code) ---
bitMap = containers.Map;
bitMap('00') = 1; % v(1) = -3
bitMap('01') = 2; % v(2) = -1
bitMap('11') = 3; % v(3) =  1
bitMap('10') = 4; % v(4) =  3
% Bv dùng để kiểm tra lỗi bit
Bv=[0 0;0 1;1 1;1 0]; % Mapping cho các chỉ số 1, 2, 3, 4

%-----Store dispersion matrices for Alamouti OSTBC----
A(:,:,1)=[1 0;0 1];
A(:,:,2)=[0 -1;1 0];
B(:,:,1)=[1 0;0 -1];
B(:,:,2)=[0 1;1 0];

%-----Store 16 SC codewords --------
S(:,:,1)=(1/2)*[1  1;-1  1;1  1;-1  1]; 
S(:,:,2)=(1/2)*[1  1;-1  1;1  1i;1i  1]; 
S(:,:,3)=(1/2)*[1  1;-1  1;1  -1;1  1];
S(:,:,4)=(1/2)*[1  1;-1  1;1  -1i;-1i  1];
S(:,:,5)=(1/2)*[1  1;-1  1;-1  1;-1  -1]; 
S(:,:,6)=(1/2)*[1  1;-1  1;-1  1i;1i  -1]; 
S(:,:,7)=(1/2)*[1  1;-1  1;-1  -1;1  -1];
S(:,:,8)=(1/2)*[1  1;-1  1;-1  -1i;-1i  -1];
S(:,:,9)=(1/2)*[1  1;-1  1;1i  1;-1  1i]; 
S(:,:,10)=(1/2)*[1  1;-1  1;1i  1i;1i  1i]; 
S(:,:,11)=(1/2)*[1  1;-1  1;1i  -1;1  1i];
S(:,:,12)=(1/2)*[1  1;-1  1;1i  -1i;-1i  1i];
S(:,:,13)=(1/2)*[1  1;-1  1;-1i  1;-1  -1i]; 
S(:,:,14)=(1/2)*[1  1;-1  1;-1i  1i;1i  -1i]; 
S(:,:,15)=(1/2)*[1  1;-1  1;-1i  -1;1  -1i];
S(:,:,16)=(1/2)*[1  1;-1  1;-1i  -1i;-1i  -1i];

%------Store bit sequence for SC codeword mapping ---
Bs=[0 0 0 0;0 0 0 1;0 0 1 0;0 0 1 1;0 1 0 0;0 1 0 1;0 1 1 0;0 1 1 1;...
    1 0 0 0;1 0 0 1;1 0 1 0;1 0 1 1;1 1 0 0;1 1 0 1;1 1 1 0;1 1 1 1;];

% Biến phụ từ code gốc
Sindx=[1:SM];
Index2=[1:4:2*T*T*SM;4:4:2*T*T*SM];


%*********************************************************
% BẮT ĐẦU MÔ PHỎNG
%*********************************************************

% --- 1. NHẬP LIỆU VÀ KIỂM TRA ---
while true
    prompt = 'Nhập 12 bit (ví dụ: 010111001010) hoặc "q" để thoát: ';
    bit_string = input(prompt, 's');
    
    if strcmpi(bit_string, 'q')
        disp('Đã thoát chương trình.');
        return; % Thoát khỏi script
    end
    
    if length(bit_string) ~= 12 || ~all(bit_string == '0' | bit_string == '1')
        disp('Lỗi: Vui lòng nhập chính xác 12 bit (chỉ chứa 0 hoặc 1).');
        continue;
    end
    
    % Nếu hợp lệ, thoát khỏi vòng lặp
    break;
end

% --- 2. BÊN PHÁT (TRANSMITTER) ---
fprintf('\n--- 2. BÊN PHÁT (TRANSMITTER) ---\n');

% Phân chia 12 bit
sc_bits   = bit_string(1:4);
qam1_bits = bit_string(5:8);
qam2_bits = bit_string(9:12);

% Xử lý SC Codeword (Bits 1-4)
sc_index = bin2dec(sc_bits) + 1; % Chỉ số ma trận (1-16)
St = S(:,:, sc_index); % Ma trận SC đã chọn
fprintf('Đã chọn SC Codeword index: %d (bits: %s)\n', sc_index, sc_bits);

% Xử lý 16-QAM Symbol 1 (Bits 5-8)
qam1_I_bits = qam1_bits(1:2);
qam1_Q_bits = qam1_bits(3:4);
idx_I1 = bitMap(qam1_I_bits);
idx_Q1 = bitMap(qam1_Q_bits);
val_I1 = v(idx_I1);
val_Q1 = v(idx_Q1);
symbol_1 = val_I1 + 1i * val_Q1;

% Xử lý 16-QAM Symbol 2 (Bits 9-12)
qam2_I_bits = qam2_bits(1:2);
qam2_Q_bits = qam2_bits(3:4);
idx_I2 = bitMap(qam2_I_bits);
idx_Q2 = bitMap(qam2_Q_bits);
val_I2 = v(idx_I2);
val_Q2 = v(idx_Q2);
symbol_2 = val_I2 + 1i * val_Q2;

fprintf('Đã chọn Symbol 1: %s (bits: %s)\n', num2str(symbol_1), qam1_bits);
fprintf('Đã chọn Symbol 2: %s (bits: %s)\n', num2str(symbol_2), qam2_bits);

% Lưu lại các giá trị gốc để kiểm tra lỗi
% Chuyển 'val' (giá trị) thành 'idx' (chỉ số)
original_I_data = [idx_I1; idx_I2];
original_Q_data = [idx_Q1; idx_Q2];

% Tạo ma trận OSTBC (X)
X = A(:,:,1)*val_I1 + 1i*B(:,:,1)*val_Q1 + A(:,:,2)*val_I2 + 1i*B(:,:,2)*val_Q2;

% Tính ma trận SM-OSTBC (C)
C = St * X;

% --- 3. MÔ PHỎNG KÊNH TRUYỀN VÀ NHIỄU ---
fprintf('\n--- 3. MÔ PHỎNG KÊNH TRUYỀN (SNR = %d dB) ---\n', SNRdB_val);

% Tạo kênh Rayleigh
H = (randn(nR, nT) + 1i*randn(nR, nT)) / sqrt(2);
fprintf('Đã tạo kênh H (matrix %d x %d)\n', nR, nT);

% Tạo nhiễu
Noise = (randn(nR, T) + 1i*randn(nR, T)) ./ sqrt(2);
Z = Noise ./ S_SNR; % Chuẩn hóa nhiễu theo SNR
fprintf('Đã tạo nhiễu Z (matrix %d x %d)\n', nR, T);

% --- 4. TÍN HIỆU NHẬN ĐƯỢC ---
Y = H * C + Z;
fprintf('Đã tính tín hiệu nhận được Y = H*C + Z\n');

% --- 5. BÊN THU (RECEIVER) - ĐÂY LÀ PHẦN BẠN YÊU CẦU ---
fprintf('\n--- 5. BÊN THU (SO-ML DETECTOR) ---\n');

%-------Signal Detection using SO-ML detector--------
% (Code được sao chép từ file mô phỏng gốc của bạn)

%Compute equivalent channels for all 16 SC codewords
Hq=(H*S(:,1:T*SM));
%Compute Dh for all 16 SC codewords
Hn=(sum(Hq.*conj(Hq),1));
Dh=(sum(reshape(Hn,T,SM)));

%Compute xI_q, xQ_q for all 16 SC codewords
YH=Y'*Hq;

AYH(:,:,1)=A(:,:,1)*YH;
AYH(:,:,2)=A(:,:,2)*YH;

BYH(:,:,1)=B(:,:,1)*YH;
BYH(:,:,2)=B(:,:,2)*YH;

%Compute the trace of real(A*Y'*Hq)
xI_q=sum(real(AYH(Index2)));
%Divide by Dh to get xI_q
xI_q=reshape(xI_q,SM,2)'./Dh(ones(nd,1),:);

%Compute the trace of imag(B*Y'*HH)
xQ_q=sum(imag(BYH(Index2)));
%Divide by Dh to get xI_q
xQ_q=-reshape(xQ_q,SM,2)'./Dh(ones(nd,1),:);

%Compute Rq for all 16 SC codewords
Rq=sum(xI_q.*xI_q)+sum(xQ_q.*xQ_q);

%Detect 16-QAM symbols corresponding to each SC codewords
for k1=1:nd
    Ttemp=xI_q(k1,:);

    dI_q=v(ones(SM,1),:).'-Ttemp(ones(sqrt(TM),1),:);
    dI_q=dI_q.*dI_q;
    [dtemp2(:,2*k1-1) mIQ(:,2*k1-1)]=min(dI_q);

    Ttemp=xQ_q(k1,:);
    dQ_q=v(ones(SM,1),:).'-Ttemp(ones(sqrt(TM),1),:);
    dQ_q=dQ_q.*dQ_q;
    [dtemp2(:,2*k1) mIQ(:,2*k1)]=min(dQ_q);
end
             
% ---Compute d_q ---
d_q=(sum(dtemp2,2)-Rq').*Dh';

%---find d_q min and the corresponding index
[dmin qmin]=min(d_q);

%--Determine transmitted 16-QAM symbols
m_min=mIQ(qmin,:)'; % Đây là 4 chỉ số (idx) QAM được phát hiện

% --- 6. KIỂM TRA KẾT QUẢ ---
fprintf('\n--- 6. SO SÁNH KẾT QUẢ ---\n');

% Dò tìm SC Codeword
detected_sc_bits = Bs(qmin, :);
fprintf('SC Codeword gốc (index %d): %s\n', sc_index, sc_bits);
fprintf('SC Codeword dò được (index %d): %s\n', qmin, num2str(detected_sc_bits, '%d'));

ne1=length(find(Bs(qmin,:)~=Bs(sc_index,:)));
if ne1 == 0
    fprintf('   => SC Codeword: ĐÚNG\n');
else
    fprintf('   => SC Codeword: SAI (%d bit lỗi)\n', ne1);
end

% Dò tìm 16-QAM
% Lấy bit từ các chỉ số gốc
original_bits_qam = [Bv(original_I_data(1),:) Bv(original_Q_data(1),:) Bv(original_I_data(2),:) Bv(original_Q_data(2),:)];
% Lấy bit từ các chỉ số dò được
detected_bits_qam = [Bv(m_min(1),:) Bv(m_min(3),:) Bv(m_min(2),:) Bv(m_min(4),:)]; % Sắp xếp lại [I1 Q1 I2 Q2]

fprintf('\nQAM Bits gốc  : %s%s%s%s %s%s%s%s\n', ...
    qam1_I_bits, qam1_Q_bits, qam2_I_bits, qam2_Q_bits);
fprintf('QAM Bits dò được: %d%d%d%d %d%d%d%d\n', detected_bits_qam);

% m_min chứa [idx_I1_detected; idx_Q1_detected; idx_I2_detected; idx_Q2_detected]
% Chú ý: Code gốc của bạn lưu [I1 I2], [Q1 Q2] riêng, nên m_min có thể là [idx_I1, idx_I2, idx_Q1, idx_Q2]
% Dựa trên code gốc: m_min=mIQ(qmin,:)' có kích thước 4x1, 
% chứa: [idx_I1_det; idx_I2_det; idx_Q1_det; idx_Q2_det]
% CẬP NHẬT: Sửa lại theo code gốc của bạn (m_min(1:2:3) và m_min(2:2:4))
original_bits_for_check = [Bv(original_I_data,:) Bv(original_Q_data,:)];
detected_indices_for_check = [m_min(1:2:3) m_min(2:2:4)];
detected_bits_for_check = [Bv(detected_indices_for_check(:,1),:) Bv(detected_indices_for_check(:,2),:)];

ne2=length(find(detected_bits_for_check~=original_bits_for_check));

if ne2 == 0
    fprintf('   => 16-QAM Symbols: ĐÚNG\n');
else
    fprintf('   => 16-QAM Symbols: SAI (%d bit lỗi)\n', ne2);
end

% Kết luận chung
if (ne1 + ne2) == 0
    fprintf('\n===> TỔNG KẾT: Dò tìm THÀNH CÔNG (0 bit lỗi)\n');
else
    fprintf('\n===> TỔNG KẾT: Dò tìm THẤT BẠI (%d bit lỗi)\n', ne1+ne2);
end