module AGC #(
  parameter ALPHA_SHIFT = 5
)(
  input  wire clk,
  input  wire nrst,
  input  wire en,
  input  wire [16:0] in_real,
  input  wire [16:0] in_imag,
  output wire [16:0] out_real,
  output wire [16:0] out_imag
);

  wire [15:0] R = 16'd6553;

  reg en_del;
  reg gain_en;

  reg  [16:0] max_out;
  reg  [17:0] curr_gain;
  reg  [34:0] mult_real;
  reg  [34:0] mult_imag;

  wire [16:0] abs_real;
  wire [16:0] abs_imag;
  wire [17:0] sum;
  wire [17:0] alpha_shift;
  wire [17:0] next_gain;
  wire [20:0] mult_real_rnd;
  wire [20:0] mult_imag_rnd;

  always @(posedge clk) begin
    if (en) begin
      mult_real <= $signed(in_real)*$signed(curr_gain);
      mult_imag <= $signed(in_imag)*$signed(curr_gain);
    end
  end
  
  assign mult_real_rnd = mult_real[34:14] + 1;
  assign mult_imag_rnd = mult_imag[34:14] + 1;

  localparam OVF = 2**(16);

  assign out_real = (mult_real_rnd[20] == 1 && ~&mult_real_rnd[19:17]) ? OVF   :
                    (mult_real_rnd[20] == 0 &&  |mult_real_rnd[19:17]) ? OVF-1 :
                     mult_real_rnd[17 : 1];

  assign out_imag = (mult_imag_rnd[20] == 1 && ~&mult_imag_rnd[19:17]) ? OVF   :
                    (mult_imag_rnd[20] == 0 &&  |mult_imag_rnd[19:17]) ? OVF-1 :
                     mult_imag_rnd[17 : 1];

  assign abs_real = ($signed(out_real) > 0) ? out_real : -out_real;  
  assign abs_imag = ($signed(out_imag) > 0) ? out_imag : -out_imag;
  
  always @(posedge clk) begin
    max_out <= ($signed(abs_real) > $signed(abs_imag)) ? abs_real : abs_imag;
  end

  always @(posedge clk) begin
    en_del <= en;
    gain_en <= en_del;
  end
  
  assign sum = $signed({R[15],R}) - $signed(max_out);
  assign alpha_shift = $signed(sum) >>> 5;

  assign next_gain =  $signed(curr_gain) +  $signed(alpha_shift);

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      curr_gain <= 2 ** 15-204;
    end else if (gain_en) begin
      curr_gain <= next_gain ;    
    end
  end
   
endmodule