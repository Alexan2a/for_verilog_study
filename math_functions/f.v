
module f1 #(parameter N=5)(
  input wire [N:0] binary,
  output reg [4*(N/3+1):0] BinDec
);
  
  always @(binary) begin
    BinDec = BINtoBCD(binary);
  end
  integer i;
  function [4*(N/3+1):0] BINtoBCD;
    input [N:0] BIN;
    integer dec, i, j, m;
    begin
      for(i = 0; i <= 4*(N/3+1); i = i+1) BINtoBCD[i] = 0;
      if (BIN[N] == 0) 
        BINtoBCD[N:0] = BIN; 
      else begin 
        BINtoBCD[N:0] = ~BIN;   
        BINtoBCD = BINtoBCD + 1; 
        BINtoBCD[4*(N/3+1)] = 1;
      end              
      for(i = 0; i <= N-3; i = i+1)          
        for(j = 0; j <= i/3; j = j+1)             
          if (BINtoBCD[N+1-i+4*j -: 4] > 4)                      // if > 4
            BINtoBCD[N+1-i+4*j -: 4] = BINtoBCD[N+1-i+4*j -: 4] + 4'd3;
    end
  endfunction

endmodule

module f2 #(parameter N=5)(
  input wire [4*(N/3+1)-1:0] BinDec,
  output reg [N:0] binary
);

  always @(BinDec) begin
    binary = BCDtoBIN(BinDec);
  end

  function [N:0] BCDtoBIN;
    input [4*(N/3+1)-1:0] BCD;
    integer dec, i, m;
    begin
      dec = 0;
      for (i = 0; i <= N/3; i = i + 1) begin
        m = BCD[4*i +: 4];
        dec = dec + m * (10 ** i);
      end           
      BCDtoBIN = dec;
    end
  endfunction
endmodule

module f3 #(parameter N = 4)(
  input wire [16*N-1:0] in_vector,
  output reg [15:0] min, max, EP,
  output reg [34:0] disp
);

  reg [31:0] minmax;
  localparam A = $clog2(N);

  always @(in_vector) begin
    minmax = MinMax(in_vector);
    min = minmax[15:0];
    max = minmax[31:16];
    EP = Exp_payoff(in_vector);
    disp = Disp(in_vector, EP);
  end

  
  function [31:0] MinMax;
    input [16*N-1:0] vect;
    integer i, j;
    reg [15:0] BUF, min, max;
    begin
      min = 32767;
      max = -32768;
      for (i = 0; i < N; i = i + 1) begin
        if ( $signed(vect[16*i +: 16]) > $signed(max)) begin
          max = vect[16*i +: 16];
        end
        if ( $signed(vect[16*i +: 16]) < $signed(min)) begin
          min = vect[16*i +: 16];
        end
      end
      MinMax[15:0] = min;
      MinMax[31:16] = max;
    end
  endfunction

  function [15:0] Exp_payoff;
    input [16*N-1:0] vect;
    integer i;
    reg [15:0] n;
    reg [15 + A : 0] sum;
    reg [32 + A : 0] ACC;
    begin
      n = 2 ** 15 / N; //16.15
      sum = 0;
      for (i = 0; i < N; i = i + 1) begin
        sum = $signed(sum) + $signed({{A{vect[i*16]}}, vect[i*16 +: 16]}); //16+A.15
      end
      ACC = $signed(sum)*$signed(n); //32+A.30
      ACC = ACC / (2 ** 15); //32+A.15
      Exp_payoff = ACC[15:0];
    end
  endfunction
  
  function [34:0] Disp;
    input [16*N-1:0] vect;
    input [15:0] EP;
    integer i, n;
    reg [33+A:0] sum;
    reg [49+A:0] ACC;
    reg [34:0] out;
    reg [33:0] pow2;
    reg [16:0] BUF;
    begin
      n = 2 ** 15 / N; //16.15
      sum = 0;
      for (i = 0; i < N; i = i + 1) begin
        BUF = $signed(vect[i*16 +: 16]) - $signed(EP); //17.15
	pow2 = $signed(BUF)*$signed(BUF);              // 34.30
        sum = $signed(sum) + $signed({{A{pow2[33]}}, pow2}); //34+A.30
      end
      ACC = $signed(sum)*$signed(n); //50+A.45
      Disp = ACC[49:15]/(2**15); //35.15
    end
  endfunction
endmodule

module TB (
);
  parameter N = 7;
  
  reg [16*N-1 : 0] vect;
  wire [15:0] min, max, EP;
  wire [34:0] disp;
  reg [N:0] i_binary;
  reg [4*(N/3+1)-1:0] i_bcd;
  wire [N:0] o_binary;
  wire [4*(N/3+1):0] o_bcd;
  
  f1 #(N) my_func1(
    .binary(i_binary),
    .BinDec(o_bcd)
  );
  f2 #(N) my_func2(
    .BinDec(i_bcd),
    .binary(o_binary)
    );
   f3 #(N) my_func3(
        .in_vector(vect),
        .min(min),
        .max(max),
        .EP(EP),
        .disp(disp)
  );
  initial 
     begin
        i_binary = -112;
        i_bcd[3:0] = 5;
        i_bcd[7:4] = 3;
        i_bcd[11:8] = 1;
        vect[15:0] = 5032;
        vect[16*2-1:16] = -1767;
        vect[16*3-1:16*2] = -15;
        vect[16*4-1:16*3] = 18932;
        vect[16*5-1:16*4] = 1000;
        vect[16*6-1:16*5] = 0;
        vect[16*7-1:16*6] = -6057;
     end
  endmodule