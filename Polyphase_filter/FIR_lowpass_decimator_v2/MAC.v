module MAC #(parameter SIZE = 43, parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 16)(
  input  wire clk,
  input  wire nrst,
  input  wire en,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [SAMPLE_SIZE-1:0] s_in,
  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout
);

  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mult;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;

  assign dout = acc;
  assign mult = ($signed(s_in) * $signed(c_in)) >>> 3; //32.30

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else if (en) begin 
      acc <= $signed(acc) + $signed(mult); //32.30
    end
  end


endmodule