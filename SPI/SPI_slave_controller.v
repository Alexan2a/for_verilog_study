module spi_slave_ctrl(
  input  wire        rst,
  input  wire        clk,
  input  wire        MOSI,
  input  wire        CS,
  input  wire  [7:0] Data_in,
  output reg         MISO,
  output reg   [7:0] Data_out,
  output reg   [4:0] Addr,
  output reg         Mode
);

  localparam RESET = 3'b000;
  localparam INF_BITS = 3'b001;
  localparam DATA_IN = 3'b010;
  localparam DATA_OUT = 3'b011;
  localparam IDLE = 3'b100;


  reg [13:0] data_reg;
  reg  [3:0] cnt;
  reg  [2:0] state;

  always @(negedge rst) begin
    if (!rst) begin
      state <= RESET;
    end
  end

  always @(posedge clk) begin
    case(state)
      RESET: begin
        data_reg <= 0;
        cnt <= 4'b0000;
        MISO <= 0;
        state <= IDLE;
      end
      INF_BITS: begin
        data_reg <= {MOSI, data_reg[13:1]};
        MISO <= 0;
        if (cnt == 6) begin
          cnt <= 0;
          if (!data_reg[8]) begin
            Addr <= data_reg[13:9];
            Mode <= data_reg[8];
            state <= DATA_IN;
	        end else begin
            state <= DATA_OUT;
          end
        end else cnt <= cnt + 1;
      end
      DATA_IN: begin
	      if (cnt == 1) data_reg[7:0] <= Data_in;
        else data_reg <= {MOSI, data_reg[13:1]};
        MISO <= data_reg[1];
	      if (cnt == 11) begin
          cnt <= 0;
          if (CS) state <= IDLE;
          else state <= INF_BITS;
        end else cnt <= cnt + 1;
      end
      DATA_OUT: begin
        data_reg <= {MOSI, data_reg[13:1]};
        MISO <= 0;
	      if (cnt == 7) begin
	        Data_out <= data_reg[13:6];
          Addr <= data_reg[5:1];
          Mode <= data_reg[0];
        end
        if (cnt == 8)   Mode <= 0;
        if (cnt == 11) begin
          cnt <= 0;
          if (CS) state <= IDLE;
          else state <= INF_BITS;
        end else cnt <= cnt + 1;
      end
      IDLE: begin
        if (!CS) state <= INF_BITS;
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end

endmodule


