% Grabar audio recibido
Fs=96000; Nb=16;Chs=1; 
recObj = audiorecorder(Fs, Nb, Chs); 
get(recObj); 
disp('Start speaking.') 
recordblocking(recObj, 150); 
disp('End of Recording.'); 
% Store data in double-precision array. 
myRecording = getaudiodata(recObj); 
% Plot the waveform. 
plot(myRecording); 
% Power Spectrum Densitiy: 
pwelch(myRecording,500,300,500,'one-side','power',Fs) 

% Elimine de la señal recibida, la parte que corresponde al silencio          
Rx_signal = myRecording;
%Rx_signal = y;   
threshold = 0.1;                            % Detecting the channel energization 
start = find(abs(Rx_signal)> threshold,3,'first'); % Initial 
stop  = find(abs(Rx_signal)> threshold,1,'last');  % End 
Rx_signal = Rx_signal (start:stop);
figure();
plot(Rx_signal); title('Señal Rx sin silencio al principio');

% Pulso base para CL cuadrado
mp = 3;
Fs = 96000;
pbase = rectwin(mp); % Complete pulse

% Match Filter
Match_Filter = fliplr(pbase);  %Mirror the rectangular pulse base
Rx_signal_filtered = conv(Rx_signal, Match_Filter); %Convolution of filtered signal and mirrored rectangular pulse base + noise
figure();
plot(Rx_signal_filtered); title('Rx con Match Filter');

% Diagrama de ojo
eyediagram(Rx_signal_filtered(Fs/8:Fs/4), 2*mp); %Eye Diagram 
title('Diagrama de ojo de señal Rx con pulso SRRC')

% Densidad espectral de potencia
figure();
pwelch(Rx_signal_filtered,500,300,500,Fs,'power'); %Spectral density 

% Sincronización Early-Late Cuadrado
symSync = comm.SymbolSynchronizer('TimingErrorDetector','Early-Late (non-data-aided)','SamplesPerSymbol',mp);
rxSym = symSync(-Rx_signal_filtered);
release(symSync); % Liberar el objeto
scatterplot(rxSym); title('Scatterplot of Syncronized Signal');
%Delete the extra bit given by the syncronization
rec_line_code = rxSym(2:end);

% Convertir a bits
sym = sign(rec_line_code);
bits_Rx = (sym + 1) / 2; %Each bit take the value of 1 or 0
bits_Rx = bits_Rx'; %transpose
bits_Rx = bits_Rx(:);

% Creación del objeto
preamble = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';
preamble_detect = comm.PreambleDetector(preamble,'Input','Bit');
preamble_size = numel(preamble);
SFD = [1 0 1 0 1 0 1 1]';
% Preamble detection. The index shows where the frame ends
idx_img = preamble_detect(bits_Rx(1:128))  % 128 bits window
% Once found the index, discard "junk bits", as follow
bits_Rx = bits_Rx(idx_img+1-numel(preamble):end);

% SFD
SFD_bits = bits_Rx(preamble_size+1:preamble_size+numel(SFD));
SFD_size = numel(SFD);

%Destination and Source Address imagen
DSA_bits = bits_Rx(preamble_size+SFD_size+1:preamble_size+SFD_size+184);
DSA_size = numel(DSA_bits);
DSA_val = reshape(DSA_bits, 8, DSA_size/8)'; 
DSA_val = bi2de(DSA_val, 'left-msb'); 
DSA_val = char(DSA_val)' %print DSA in console

% Header imagen
header_img = bits_Rx(preamble_size+SFD_size+DSA_size+1:preamble_size+SFD_size+DSA_size+32); %header
header_size_img = numel(header_img);
w = bi2de(header_img(1:16)','left-msb'); %image's width
h = bi2de(header_img(17:header_size_img)','left-msb'); %image's height
final_img = preamble_size+SFD_size+DSA_size+32+w*h*8;
data_bits_img = bits_Rx(preamble_size+SFD_size+DSA_size+header_size_img+1 ...
    :preamble_size+SFD_size+DSA_size+header_size_img+w*h*8); %data

% Idx audio
idx_audio = preamble_detect(bits_Rx(final_img+1:final_img+128))
bits_Rx_audio = bits_Rx(idx_audio+1-numel(preamble):end);

%Reconstrucción imagen
bits_reshape = reshape(data_bits_img, 8, w*h); %Matrix of 8 * w * h
bits_reshape = bits_reshape'; %Transpose 
decVal = bi2de(bits_reshape, 'left-msb'); %convert from binary to decimal
lena_reshape = reshape(decVal, w, h); %reshape the image
figure();
imshow(uint8(lena_reshape)); %show the reconstructed image
title('Lena Reshape');

% Construir y escribir archivo de audio
SFD_bits_audio = bits_Rx(final_img+preamble_size+1:final_img+preamble_size+SFD_size);

%Destination and Source Address audio
DSA_bits_audio = bits_Rx(final_img+preamble_size+SFD_size+1:final_img+preamble_size+SFD_size+168);
DSA_size_audio = numel(DSA_bits_audio);
DSA_val_audio = reshape(DSA_bits_audio, 8, DSA_size_audio/8)'; 
DSA_val_audio = bi2de(DSA_val_audio, 'left-msb'); 
DSA_val_audio = char(DSA_val_audio)' %print DSA in console

% Header audio
header_audio = bits_Rx(final_img+preamble_size+SFD_size+DSA_size_audio+1:final_img+preamble_size+SFD_size+DSA_size_audio+32); %header
header_data = bit2int(header_audio,32);
data_bits_audio = bits_Rx(final_img+preamble_size+SFD_size+DSA_size_audio+32+1:final_img+preamble_size+SFD_size+DSA_size_audio+32+header_data); %data

% Construir y escribir archivo de audio
audioValues = vec2mat(data_bits_audio,8); % Obtain Bytes
audioValues = bi2de(audioValues); % Bin2Dec conversion
rxAudioId = fopen('rx_audio.opus','w'); %File ID;
fwrite(rxAudioId,audioValues); % Write the file
fclose(rxAudioId);