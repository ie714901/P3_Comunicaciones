%% Transmisión Práctica 3 SRRC

preamble_imagen = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';

SFD_imagen= [1 0 1 0 1 0 1 1]';

DSA_imagen = de2bi(uint8('Hola buenas tardes 1998'),8,'left-msb');%DSA size obtention

DSA_imagen = reshape(DSA_imagen',1,numel(DSA_imagen));%Reshapes DSA to a transposed vector of 1x its size 

load lena512.mat; 

img = uint8(lena512);

% img = img(247:287,313:353); %cut the image (41 x 41)

imshow(img);

size_img=de2bi(size(img),16,'left-msb');%Image's size in 16 bits

header_imagen = [size_img(1,:) size_img(2,:)]';

payload_imagen = de2bi(img,8,'left-msb'); % Puede ser right-msb

payload_imagen = payload_imagen';

payload_imagen = payload_imagen(:);%Payload concatenation

bits2Tx_imagen = [preamble_imagen; SFD_imagen; DSA_imagen'; header_imagen; payload_imagen];%Concatenation of complete set of bits


% Transmisión Audio

preamble_audio = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';

SFD_audio = [1 0 1 0 1 0 1 1]';

DSA_audio = de2bi(uint8('Hola buenos dias 1996'),8,'left-msb');%DSA size obtention

DSA_audio = reshape(DSA_audio',1,numel(DSA_audio));%Reshapes DSA to a transposed vector of 1x its size 

filename = 'juego.opus';

info = audioinfo(filename);

song = fopen(filename,'r');% Read only

songV = fread(song);

fclose(song);

b = de2bi(songV,8); %Double to binary number
 
b = b'; bits_audio = b(:); % Arrange to a single vector

size_audio = de2bi(numel(bits_audio),32,'left-msb');

payload_audio = bits_audio;

%header = [size_audio(1,:) 1]';
header_audio = [size_audio(:)];

% payload_audio = de2bi(songV,8,'left-msb'); % Puede ser right-msb
% 
% payload_audio = payload_audio';
% 
% payload_audio = payload_audio(:);%Payload concatenation

bits2Tx_audio = [preamble_audio; SFD_audio; DSA_audio'; header_audio; payload_audio];%Concatenation of complete set of bits


% bits2Tx IMAGE AND AUDIO

bits2Tx = [preamble_imagen; SFD_imagen; DSA_imagen'; header_imagen; payload_imagen; preamble_audio; SFD_audio; DSA_audio'; header_audio; payload_audio];

% % Pulse SRRC

Fs = 96000;

Ts = 1/Fs;

beta = 0.2;%Roll-off

B = 20000; %Bandwidth

Rb = 2*B / (1 + beta);%Data Rate 

mp = ceil(Fs/Rb);%Rounds up mp to the next highest integer

Rb = Fs/mp;

Tp = 1/Rb; %Transmision period of symbol

B = (Rb*(1+beta)/2);%Occupied BW

D = 6;%Pulse Duration

type = 'srrc';

E = Tp;%Energy

[pbase ~] = rcpulse(beta,D,Tp,Ts,type,E);%Gets pulse

% % IMAGE AND AUDIO PULSE TRAIN SRRC 

pnrz = pbase; % RC or SRRC
s1 = int8(bits2Tx); %store bits value in other variable
s1(s1 == 0) = -1; %switch all zeros to -1
s = zeros(1, numel(s1)*mp); %zero's vector of s1*mp
s(1:mp:end) = s1; %Impulse train
pulse_train = conv(pnrz, s); %convolution of pnrz and s


% % NORMALIZATION

pow = sum(pulse_train.*pulse_train)/numel(pulse_train);
pulse_train = pulse_train/sqrt(pow);
pow = sum(pulse_train.*pulse_train)/numel(pulse_train);

% % EYE DIAGRAM

eyediagram(pulse_train(5000:20000),2*mp);%Eye Diagram of Pulse Train to transmit
title('EyeDiagram Image SRRC')



% % TRANSMIT 

soundsc( [zeros(1,Fs/2) pulse_train], Fs );%Transmision of pulse with silence at the beginning
