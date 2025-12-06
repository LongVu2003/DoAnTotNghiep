% Program to simulate performance of SM-OSTBC in 4x4 MIMO system 
% 16-QAM Modulation.
% SO-SD detector
% (C)2024 Le Minh Tuan, FEE1 - PTIT
% Date: March 2024

%*********************************************************
clear all;
% close all;
clc;

nT=4;                       % No of TxAnt
nR=4;                       % No of RxAnt
nA=4;                       % Number of active antenna
T=2;                        %No of symbol periods per block
nd=2;                       % Number of QAM symbol per Alamouti Code block

TM=16;                      %16-QAM Modulation
ml=log2(TM);                %Number of bits per 16-QAM symbol
SM=16;                      %Number of SC codewords
m=log2(SM);                 %Number of bits per SC codeword

SNRdB=[15];           % Signal-to-noise power ratio (in dB): 10*log10(Ps/Pn)
SNR=10.^(SNRdB/10);         % Convert to SNR (Ps/Pn)
S_SNR=sqrt(SNR);

%Total number of received signal blocks to be written in files
IterNo=[1000];

%-------Store integer values for 16-QAM modulation -----
v=[-3 -1 1 3];

%------Store bit sequence for 16-QAM symbol mapping ---
Bv=[0 0;0 1;1 1;1 0];

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
   
Es = 10; % Symbol energy of 16-QAM  
S_SNR=S_SNR./sqrt(2*Es);  %Normalized S_SNR with symbol energy


% [SMConst,SM]=SM_Codeword_Gen_SubsetnA_ver5(nT,TM,'psk',nA,4);
% 
% bin1=dec2bin(0:SM-1);
% bin2=dec2bin(0:TM-1);

txt=['b-p'];

Tx_SCcodeword=['SM_OSTBC_Tx_SC_Codewords_' int2str(nT) 'Tx' int2str(T) 'Symbol_Periods.dat'];
fidSC = fopen(Tx_SCcodeword,'w');

Tx_SCTxData=['SM_OSTBC_Tx_SC_Data_' int2str(nT) 'Tx' int2str(T) 'Symbol_Periods.dat'];
fidSCTxData = fopen(Tx_SCTxData,'w');

Tx_OSTBC=['SM_OSTBC_Tx_OSTBCs_' int2str(T) 'Tx' int2str(T) 'Symbol_Periods.dat'];
fidOSTBC = fopen(Tx_OSTBC,'w');

Tx_SMOSTBC=['SM_OSTBC_Tx_SMOSTBCs_' int2str(nT) 'Tx' int2str(T) 'Symbol_Periods.dat'];
fidSMOSTBC = fopen(Tx_SMOSTBC,'w');

Tx_OSTBCTxData=['SM_OSTBC_Tx_OSTBC_Data_' int2str(nT) 'Tx' int2str(T) 'Symbol_Periods.dat'];
fidOSTBCTxData = fopen(Tx_OSTBCTxData,'w');

Rx_Noise=['SM_OSTBC_Rx_Noise_'  int2str(SNRdB) 'dBSNR_'  int2str(nR) 'Rx' int2str(T) 'Symbol_Periods.dat'];
fidNoise = fopen(Rx_Noise,'w');

Channel=['SM_OSTBC_RayleighChannel_' int2str(nR) 'Rx' int2str(nT) 'Tx.dat'];
fidCH = fopen(Channel,'w');

Rx_Signal=['SM_OSTBC_RxSignal_' int2str(SNRdB) 'dBSNR_' int2str(nR) 'Rx' int2str(T) 'Symbol_Periods.dat'];
fidRxSig = fopen(Rx_Signal,'w');



% Pre-generate data for simulation
Len=5000;   % Length of OSTBC blocks, channel matrix and noise

%--Generate SC codeword indices for data mapping
Sid=randi(SM,1,Len);

%--Generate noise matrices, each element has zero min and unit variance ----
Noise=(randn(nR,T,Len)+1i*randn(nR,T,Len))./sqrt(2);

%--Generate Rayleigh fading channel matrices, each element has zero min and unit variance ----
H=(randn(nR,nT,Len)+1i*randn(nR,nT,Len))/sqrt(2);

%--Generate data indices for real part of nd 16-QAM symbols
I_data=randi(sqrt(TM), nd,Len);

%--Generate data indices for real part of nd 16-QAM symbols
Q_data=randi(sqrt(TM), nd,Len);

Sindx=[1:SM];
% NTMConst=repmat(TMConst,nR,SM);

Index2=[1:4:2*T*T*SM;4:4:2*T*T*SM];

for n=1:length(SNR)
    ne1=0;
    ne2=0;
    ns=0;
    Smg=0;
    Nmg=0;
    for i=1:IterNo(n)
        %Check if more data need to be generated for simulation
        nn=mod(i,Len)+1;
        if nn==Len %More data need to be generated
            Sid=randi(SM,1,Len);
            Noise=(randn(nR,T,Len)+j*randn(nR,T,Len))./sqrt(2);
            H=(randn(nR,nT,Len)+j*randn(nR,nT,Len))/sqrt(2);
            
            %--Generate data indices for real part of nd 16-QAM symbols
            I_data=randi(sqrt(TM), nd,Len);
            
            %--Generate data indices for real part of nd 16-QAM symbols
            Q_data=randi(sqrt(TM), nd,Len);
        end
        %Select SC codeword to be transmitted 
        Sc=Sid(nn);
        St=S(:,:,Sid(nn));

        %Print the real and imaginary part of SC codewords
        fprintf(fidSC,'%3.6f\t%3.6f\n',real(St));
        fprintf(fidSC,'%3.6f\t%3.6f\n',imag(St));

        %Print SC codewords index and Tx Data
        fprintf(fidSCTxData,'%d\t%d\t%d\t%d\t%d\n',Sc,Bs(Sc,:));


        %Select the real and imaginary part of 16-QAM symbols
        xI=v(I_data(:,nn));
        xQ=v(Q_data(:,nn));

        %Print 16-QAM index and Tx Data
        fprintf(fidOSTBCTxData,'%d\t%d\t%d\t%d\n',[I_data(1,nn) Bv(I_data(1,nn),:)]);
        fprintf(fidOSTBCTxData,'\n%d\t%d\t%d\t%d\n',[I_data(2,nn) Bv(I_data(2,nn),:)]);
        fprintf(fidOSTBCTxData,'\n%d\t%d\t%d\t%d\n',[Q_data(1,nn) Bv(Q_data(1,nn),:)]);
        fprintf(fidOSTBCTxData,'\n%d\t%d\t%d\t%d\n',[Q_data(2,nn) Bv(Q_data(2,nn),:)]);
        fprintf(fidOSTBCTxData,'\n');


        %Generate OSTBC matrix using dispersion matrices
        X=A(:,:,1)*xI(1)+1i*B(:,:,1)*xQ(1)+A(:,:,2)*xI(2)+1i*B(:,:,2)*xQ(2);

        %Print the real and imaginary part of OSTBC
        fprintf(fidOSTBC,'%3.6f\t%3.6f\n',real(X));
        fprintf(fidOSTBC,'%3.6f\t%3.6f\n',imag(X));

        %Compute noise with given SNR
        Z=Noise(:,:,nn)./S_SNR(n);

        %Print the real and imaginary part of Noise
        fprintf(fidNoise,'%3.6f\t%3.6f\n',real(Z));
        fprintf(fidNoise,'%3.6f\t%3.6f\n',imag(Z));

        % Generate received signal at the receiver
        C=St*X;
        Y=H(:,:,nn)*C+Z;

        %Print the real and imaginary part of SM-OSTBC
        fprintf(fidSMOSTBC,'%3.6f\t%3.6f\n',real(C));
        fprintf(fidSMOSTBC,'%3.6f\t%3.6f\n',imag(C));

        %Print the real and imaginary part of Rayleight Channel
        fprintf(fidCH,'%3.6f\t%3.6f\n',real(H(:,:,nn)));
        fprintf(fidCH,'%3.6f\t%3.6f\n',imag(H(:,:,nn)));

        %Print the real and imaginary part of Rx Signal
        fprintf(fidRxSig,'%3.6f\t%3.6f\n',real(Y));
        fprintf(fidRxSig,'%3.6f\t%3.6f\n',imag(Y));
        
        %Calculate transmit power and noise power
        Smg=Smg+trace(C'*C);
        Nmg=Nmg+trace(Z'*Z);

        %-------Signal Detection using SO-ML detector--------

        %Compute equivalent channels for all 16 SC codewords
        Hq=(H(:,:,nn)*S(:,1:T*SM));
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
        m_min=mIQ(qmin,:)';
        
        %Compute number of bit errors for SC codewords
        ne1=ne1+length(find(Bs(qmin,:)~=Bs(Sc,:)));
        %Compute number of bit errors for 16-QAM symbols
        ne2=ne2+length(find([Bv(m_min(1:2:3),:) Bv(m_min(2:2:4),:)]~=[Bv(I_data(:,nn),:) Bv(Q_data(:,nn),:)]));%42s
    end
        %----Compute BER ----
     ber(n)=(sum(ne1)+sum(ne2))/(m+2*ml)/IterNo(n);
     
     %Compute SNR at each receive antenna of the receiver
     Smg=Smg/IterNo(n);
     Nmg=Nmg/IterNo(n)/nR;
     10*log10(Smg/Nmg)
end

% Plot BER vs SNR (in dB) in logarithm scale

fclose("all");

semilogy(SNRdB,ber,txt)
hold on
xlabel('SNR (dB)')
ylabel('BER')
legend('BER')
