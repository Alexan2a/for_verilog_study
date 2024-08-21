module spi_master(
  input  wire         rst,
  input  wire         clk,
  input  wire         MISO,
  input  wire  [13:0] Data_in,
  input  wire         tx_valid,
  input  wire         CS_Sel,
  output wire         CS0,
  output wire         CS1,
  output reg          MOSI,
  output reg          rx_ready,
  output reg    [7:0] Data_out
);

  localparam RESET = 2'b00;
  localparam TRANSMITION = 2'b01;
  localparam IDLE = 2'b10;


  reg [13:0] data_reg;
  reg  [4:0] cnt;
  reg  [2:0] state;
  reg        CS;

 // assign MOSI = data_reg[0];

  demux_2_to_1 CS_ctrl(
    .Sel(CS_Sel),
    .D(CS),
    .S0(CS0),
    .S1(CS1)
  );

  always @(negedge rst) begin
    if (!rst) begin
      state <= RESET;
    end
  end

  always @(posedge clk) begin
    case(state)
      RESET: begin
        data_reg <= 0;
        cnt <= 5'b00000;
	state <= IDLE;
        CS <= 1;
      end
      TRANSMITION: begin
        data_reg <= {MISO, data_reg[13:1]};
        MOSI <= data_reg[0];
        if (cnt == 17) begin
          cnt <= 0;
          rx_ready <= 1;
	  Data_out <= data_reg[13:6];
          state <= IDLE;
          CS <= 1;
        end else cnt <= cnt + 1;
      end
      IDLE: begin
        if (tx_valid) begin
          CS <= 0;
          rx_ready <= 0;
          data_reg <= Data_in;
          state <= TRANSMITION;
        end
      end
      default: begin
      end
    endcase
  end

endmodule
