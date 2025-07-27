module AGC #(
  parameter ALPHA_SHIFT = 5,
  parameter SAMPLE_WH = 16,
  parameter SAMPLE_FR = 15,
  parameter GAIN_WH = 16,
  parameter GAIN_FR = 8
)(
  input  wire clk,
  input  wire nrst,
  input  wire en,
  input  wire gain_en,
  input  wire [SAMPLE_WH-1:0] in_real,
  input  wire [SAMPLE_WH-1:0] in_imag,
  output reg  [SAMPLE_WH-1:0] out_real,
  output reg  [SAMPLE_WH-1:0] out_imag
);

  localparam SAMPLE_INT = (SAMPLE_WH-SAMPLE_FR);
  localparam GAIN_INT = (GAIN_WH-GAIN_FR);
  localparam R_VALUE = 0.2 * 2 ** (SAMPLE_FR);
 // wire [15:0] R = 16'd6553;

  wire [SAMPLE_WH:0] R = R_VALUE;

  reg  [SAMPLE_WH-1:0] max_out;
  reg  [GAIN_INT+SAMPLE_FR+ALPHA_SHIFT-1:0] curr_gain;
  reg  [SAMPLE_WH+GAIN_WH-1:0] mult_real;
  reg  [SAMPLE_WH+GAIN_WH-1:0] mult_imag;

  wire [GAIN_WH-1:0] gain_conv;
  wire [SAMPLE_WH-1:0] abs_real;
  wire [SAMPLE_WH-1:0] abs_imag;
  wire [SAMPLE_WH:0] sum;
  wire [SAMPLE_WH+ALPHA_SHIFT:0] alpha_shift;
  wire [GAIN_INT+SAMPLE_FR+ALPHA_SHIFT-1:0] next_gain;
  wire [GAIN_INT+SAMPLE_WH:0] mult_real_rnd;
  wire [GAIN_INT+SAMPLE_WH:0] mult_imag_rnd;

  always @(posedge clk) begin
    if (en) begin
      mult_real <= $signed(in_real)*$signed(gain_conv);
      mult_imag <= $signed(in_imag)*$signed(gain_conv);
    end
  end
  
  assign mult_real_rnd = mult_real[SAMPLE_WH+GAIN_WH-1 -: GAIN_INT+SAMPLE_WH+1] + 1;
  assign mult_imag_rnd = mult_imag[SAMPLE_WH+GAIN_WH-1 -: GAIN_INT+SAMPLE_WH+1] + 1;

  localparam OVF = 2**(SAMPLE_WH-1);
  localparam BITS_TO_CUT = GAIN_INT-SAMPLE_INT;

  always @(posedge clk) begin
    out_real <= (mult_real_rnd[GAIN_INT+SAMPLE_WH] == 1 & ~&mult_real_rnd[GAIN_INT+SAMPLE_WH-1 -: BITS_TO_CUT]) ? OVF   :
                (mult_real_rnd[GAIN_INT+SAMPLE_WH] == 0 &  |mult_real_rnd[GAIN_INT+SAMPLE_WH-1 -: BITS_TO_CUT]) ? OVF-1 :
                 mult_real_rnd[SAMPLE_WH : 1];

    out_imag <= (mult_imag_rnd[GAIN_INT+SAMPLE_WH] == 1 & ~&mult_imag_rnd[GAIN_INT+SAMPLE_WH-1 -: BITS_TO_CUT]) ? OVF   :
                (mult_imag_rnd[GAIN_INT+SAMPLE_WH] == 0 &  |mult_imag_rnd[GAIN_INT+SAMPLE_WH-1 -: BITS_TO_CUT]) ? OVF-1 :
                 mult_imag_rnd[SAMPLE_WH : 1];
  end

  assign abs_real = (out_real[SAMPLE_WH-1]) ? -out_real : out_real;  
  assign abs_imag = (out_imag[SAMPLE_WH-1]) ? -out_imag : out_imag;
  
  always @(posedge clk) begin
    max_out <= ($signed(abs_real) > $signed(abs_imag)) ? abs_real : abs_imag;
  end
  
  assign sum = $signed(R) - $signed({max_out[SAMPLE_WH-1], max_out});
  assign alpha_shift = $signed(sum) >>> ALPHA_SHIFT;

  assign next_gain =  $signed(curr_gain) +  $signed(alpha_shift);

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      curr_gain <= 2 ** (SAMPLE_FR+ALPHA_SHIFT)-204;
    end else if (gain_en) begin
      curr_gain <= next_gain ;    
    end
  end

  assign gain_conv = $signed(curr_gain[GAIN_INT+SAMPLE_FR+ALPHA_SHIFT-1 -: GAIN_WH+1] + 1) >>> 1;

endmodule