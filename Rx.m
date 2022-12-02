%% Fase 3 - Importar audio
filename = 'prueba1.opus'; %filename
[y,Fs_audio]=audioread(filename); %Save cropped audiofile in 10 sec.
plot(y);
title('Rx.opus');

%% Fase 1 - Recibir audio
Fs=96000; Nb=16;Chs=1; 
recObj = audiorecorder(Fs, Nb, Chs); 
get(recObj); 
disp('Start speaking.') 
recordblocking(recObj, 20); 
disp('End of Recording.'); 
% Store data in double-pre cision array. 
myRecording = getaudiodata(recObj); 
% Plot the waveform. 
plot(myRecording); 
% Power Spectrum Densitiy: 
pwelch(myRecording,500,300,500,'one-side','power',Fs) 

%% Elimine de la señal recibida, la parte que corresponde al silencio          
Rx_signal = myRecording;
%Rx_signal = y;   
threshold = 0.1;                            % Detecting the channel energization 
start = find(abs(Rx_signal)> threshold,3,'first'); % Initial 
stop  = find(abs(Rx_signal)> threshold,1,'last');  % End 
Rx_signal = Rx_signal (start:stop);
figure();
plot(Rx_signal); title('Señal Rx sin silencio al principio');

%% Pulso base para CL cuadrado
%mp = 10;
mp = 3;
Fs = 96000;
pbase = rectwin(mp); % Complete pulse

%% Pulso base para CL srrc
Fs      =   96000;            % Samples per second
Ts      =   1/Fs;              % 
beta    =   0.2;               % Roll-off factor
B       =   20000;             % Bandwidth available
Rb      =   2*B/(1+beta);      % Bit rate (= Baud rate)
mp      =   ceil(Fs/Rb);       % samples per pulse
Rb      =   Fs/mp;             % Recompute bit rate
Tp      =   1/Rb;              % Symbol period
B       =   (Rb*(1+beta)/2);   % Bandwidth consumed
D       =   6;                 % Time duration in terms of Tp
type    =   'srrc';            % Shape pulse: Square Root Rise Cosine
E       =   Tp;                % Energy
[pbase ~] = rcpulse(beta, D, Tp, Ts, type, E);    % Pulse Generation

%% Match Filter
Match_Filter = fliplr(pbase);  %Mirror the rectangular pulse base
Rx_signal_filtered = conv(Rx_signal, Match_Filter); %Convolution of filtered signal and mirrored rectangular pulse base + noise
plot(Rx_signal_filtered); title('Rx con Match Filter');

%% Diagrama de ojo
eyediagram(Rx_signal_filtered(1:1000), 3*mp); %Eye Diagram

%% Densidad espectral de potencia
pwelch(Rx_signal_filtered,500,300,500,Fs,'power'); %Spectral density 

%% Sincronización Early-Late Cuadrado
symSync = comm.SymbolSynchronizer('TimingErrorDetector','Early-Late (non-data-aided)','SamplesPerSymbol',mp);
rxSym = symSync(-Rx_signal_filtered);
release(symSync); % Liberar el objeto
scatterplot(rxSym); title('Scatterplot of Syncronized Signal');

%%Delete the extra bit given by the syncronization
rec_line_code = rxSym(2:end);

%% Sincronización Early-Late srrc
delay = (D*mp)/2;
symSync = comm.SymbolSynchronizer('TimingErrorDetector','Early-Late (non-data-aided)','SamplesPerSymbol',mp);
rxSym = symSync(-Rx_signal_filtered(delay:end));
release(symSync); % Liberar el objeto
scatterplot(rxSym); title('Scatterplot of Syncronized Signal');

%%Delete the extra bit given by the syncronization
rec_line_code = rxSym(3:end);

%% Convertir a bits
sym = sign(rec_line_code);
bits_Rx = (sym + 1) / 2; %Each bit take the value of 1 or 0
bits_Rx = bits_Rx'; %transpose
bits_Rx = bits_Rx(:);

%% Creación del objeto
preamble = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';
preamble_detect = comm.PreambleDetector(preamble,'Input','Bit');
SFD = [1 0 1 0 1 0 1 1]';
% Preamble detection. The index shows where the frame ends
idx = preamble_detect(bits_Rx(1:128))  % 128 bits window
% Once found the index, discard "junk bits", as follow
bits_Rx= bits_Rx(idx+1-numel(preamble):end);

%% Recuperación EJERCICIO 7
SFD_bits = bits_Rx(57:56+numel(SFD));

%Destination and Source Address
DSA_bits = bits_Rx(56+numel(SFD)+1:56+numel(SFD)+288);

header = bits_Rx(56+8+288+1:56+8+288+32); %header
w = bi2de(header(1:16)','left-msb'); %image's width
h = bi2de(header(17:32)','left-msb'); %image's height
data_bits = bits_Rx(384+1:384+w*h*8); %data

bits_reshape = reshape(data_bits, 8, w*h); %Matrix of 8 * w * h
bits_reshape = bits_reshape'; %Transpose 
decVal = bi2de(bits_reshape, 'left-msb'); %convert from binary to decimal
lena_reshape = reshape(decVal, w, h); %reshape the image
figure();
imshow(uint8(lena_reshape)); %show the reconstructed image
title('Lena Reshape');

error_xPNRZ = sum(xor(bits2Tx, bits_Rx(1:56+8+288+32+w*h*8))); %error
BER_xPNRZ = (error_xPNRZ/numel(bits2Tx))*100; %BER value

%% Construir y escribir archivo de audio
SFD_bits = bits_Rx(57:56+numel(SFD));

%Destination and Source Address
DSA_bits = bits_Rx(56+numel(SFD)+1:56+numel(SFD)+288);

header = bits_Rx(56+8+288+1:56+8+288+32); %header
data_bits = bits_Rx(372+1:372+501704); %data

audioValues = vec2mat(data_bits,8); % Obtain Bytes
audioValues = bi2de(audioValues); % Bin2Dec conversion
rxAudioId = fopen('rx_audio.opus','w'); %File ID
fwrite(rxAudioId,audioValues); % Write the file

play(rxAudioId); % Play back the recording. 
