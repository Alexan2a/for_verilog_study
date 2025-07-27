module MAC #(parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 17)(
  input  wire clk,
  input  wire en,
  input  wire nrst,
  input  wire acc_rst,

  input  wire [COEFF_SIZE -1:0] c_in,
  input  wire [SAMPLE_SIZE-1:0] s_in,

  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout
);

  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mult;
  reg [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;
  reg acc_en;
 
  assign dout = acc;

  assign mult = $signed(s_in) * $signed(c_in);

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else if (en) begin
      acc <= (acc_rst) ? mult : $signed(acc) + $signed(mult);
    end
  end
  
endmodule