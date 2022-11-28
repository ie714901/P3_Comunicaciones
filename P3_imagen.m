%% FASE 2

preamble = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';

SFD= [1 0 1 0 1 0 1 1]';

DSA = de2bi(uint8('Pr??ctica 2 FASE II: 717781 y 714901'),8,'left-msb');%DSA size obtention

DSA = reshape(DSA',1,numel(DSA));%Reshapes DSA to a transposed vector of 1x its size 

load lena512.mat; 

img = uint8(lena512);

img = img(247:287,313:353); %cut the image (41 x 41)

imshow(img);

size_img=de2bi(size(img),16,'left-msb');%Image's size in 16 bits

header= [size_img(1,:) size_img(2,:)]';

payload = de2bi(img,8,'left-msb'); % Puede ser right-msb

payload = payload';

payload = payload(:);%Payload concatenation

bits2Tx = [preamble; SFD; DSA'; header; payload];%Concatenation of complete set of bits

%% Punto 5

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

%% PUNTO 6 

pnrz = pbase; % RC or SRRC
s1 = int8(bits2Tx); %store bits value in other variable
s1(s1 == 0) = -1; %switch all zeros to -1
s = zeros(1, numel(s1)*mp); %zero's vector of s1*mp
s(1:mp:end) = s1; %Impulse train
pulse_train = conv(pnrz, s); %convolution of pnrz and s

%% Signal normalization
pow = sum(pulse_train.*pulse_train)/numel(pulse_train);
pulse_train = pulse_train/sqrt(pow);
pow = sum(pulse_train.*pulse_train)/numel(pulse_train);

%% Time and Freq. Charts of pulse and pulse train
delay = (D*mp)/2;
num_samples = 20;
window = mp*num_samples+delay;
t = 0:Ts:window*Ts-Ts;
% figure; set(stem(t, pulse_train(1:window)),'Marker','none'); % By time
figure; set(stem(pulse_train(1:window)),'Marker','none'); % By samples
xlabel('Samples'); ylabel('Amplitude'); title('Generated Line Code 4B/5B MLT-3');

%% PUNTO 8
eyediagram(pulse_train,2*mp);%Eye Digram of Pulse Train to transmit
title('EyeDiagram SRRC')

%% PUNTO 9

soundsc( [zeros(1,Fs/2) pulse_train], Fs );%Transmision of pulse with silence at the beginning