module MAC #(parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 17)(
  input  wire clk,
  input  wire mult_en,
  input  wire acc_en,
  input  wire nrst,

  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [SAMPLE_SIZE-1:0] s_in,

  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout
);

  reg [SAMPLE_SIZE+COEFF_SIZE-1:0] mult;
  reg [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;

  assign dout = acc; 

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      mult <= 0;
    end else if (mult_en) begin 
      mult <= $signed(s_in) * $signed(c_in); //33.30
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else if (acc_en) begin 
      acc <= $signed(acc) + $signed(mult); //33.30
    end
  end

endmodule