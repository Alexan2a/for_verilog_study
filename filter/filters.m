clear;
clc;

%задаем всякое 
Fc = 100e3;
Fs = 1.92e6;
Wt = 20e3;
Wn = Fc/(Fs/2);
ord = 2;
Wp = Wn;
Ws = (Fc+Wt)/(Fs/2);
Rp = 0.3;
Rs = 80;

%% БИХ-фильтры

[B,A] = butter(ord,Fc/(Fs/2));
figure ("Name","butter АЧХ, ФЧХ");
freqz(B,A)
figure ("Name","butter Нули и полюсы");
zplane(B,A)

[B,A] = cheby1(ord,Rp,Fc/(Fs/2));
figure ("Name","cheby1 АЧХ, ФЧХ");
freqz(B,A)
figure ("Name","cheby1 Нули и полюсы");
zplane(B,A)

[B,A] = ellip(ord,Rp,Rs,Fc/(Fs/2));
figure ("Name","ellip АЧХ, ФЧХ");
freqz(B,A)
figure ("Name","ellip Нули и полюсы");
zplane(B,A)

%как будто по ощущениям сheby1 и ellip получше справляются

%% это не важно, это так, чтобы не потерялось

[N,W1] = buttord(Wp,Ws,Rp,Rs);
fprintf("Butter: n = %d, Wn = %f\n",N,W1);
[N,W1] = cheb1ord(Wp,Ws,Rp,Rs);
fprintf("Cheby1: n = %d, Wn = %f\n",N,W1);
[N,W1] = cheb2ord(Wp,Ws,Rp,Rs);
fprintf("Cheby2: n = %d, Wn = %f\n",N,W1);
[N,W1] = ellipord(Wp,Ws,Rp,Rs);

fprintf("Ellip:  n = %d,  Wn = %f\n",N,W1);
%% КИХ-фильтры

filtSpecs1 = fdesign.lowpass(Fc,Fc+Wt,Rp,Rs,Fs);

lpFIReq = design(filtSpecs1,'equiripple',SystemObject=true);
lpFIRkai = design(filtSpecs1,'kaiserwin',SystemObject=true);

cost(lpFIReq)
cost(lpFIRkai)

%я пробовала тыкать с разными параметрами оконные фильтры, но у меня
%получался порядок больше, чем в этом equiripple. Может я что-то не так
%делала

filtSpecs2 = fdesign.lowpass('Fp,Fst,Ap,Ast',Fc/(Fs/2),(Fc+Wt+3.3e3)/(Fs/2),Rp,Rs);
lpFIReq256 = design(filtSpecs2,'equiripple',SystemObject=true);

cost(lpFIReq256)
order(lpFIReq256)

%раскомментить если нужно
%hvft = fvtool(lpFIReq,'Fs',Fs);    %equiripple
%hvft = fvtool(lpFIReq256,'Fs',Fs); %equiripple with 256 coeffs
%hvft = fvtool(lpFIRkai,'Fs',Fs);   %kaiser window

Nbits = 16;
coeff = lpFIReq256.Numerator;
coeff_round = round(2^(Nbits-1)*coeff);
coeff_fixpt = coeff_round/2^(Nbits-1);

figure ("Name","equiripple АЧХ, ФЧХ до квантования коэффициентов");
freqz(coeff,1)
figure ("Name","equiripple АЧХ, ФЧХ после квантования коэффициентов");
freqz(coeff_fixpt,1)
%тут грусть, в полосе подавления меньше 80дб, надо что-то еще пробовать,
%наверно