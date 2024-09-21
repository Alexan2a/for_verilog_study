module RAM #(parameter N=8, parameter M=32)(
  input  wire                 clk,
  input  wire [N-1:0]         Data_in,
  input  wire                 WE,
  input  wire [$clog2(M)-1:0] Addr,
  output wire [N-1:0]         Data_out
);

  reg startup = 0;
  reg [N-1:0] ram[0:M-1];
  reg [N-1:0] d_out;

  assign Data_out = d_out;

  always @(posedge clk) begin
    if (!startup) begin
        ram[0] <= 8'b00000000;
	      ram[1] <= 8'b00010001;
	      ram[2] <= 8'b11101011;
	      ram[3] <= 8'b00110011;
      	ram[4] <= 8'b01000100;
      	ram[5] <= 8'b01010101;
      	ram[6] <= 8'b01110110;
      	ram[7] <= 8'b01110111;
      	ram[8] <= 8'b10101011;
        ram[29] <= 8'b00110001;
      	ram[30] <= 8'b01110010;
      	ram[31] <= 8'b11110011;
      startup <= 1;
    end
    if (!WE) d_out <= ram[Addr];
    else ram[Addr] <= Data_in;
  end

endmodule