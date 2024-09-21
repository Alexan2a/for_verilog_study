module spi_slave_ctrl(
  input  wire       rst,
  input  wire       clk,
  input  wire       MOSI,
  input  wire       CS,
  input  wire [7:0] Data_in,
  output wire       MISO,
  output reg  [7:0] Data_out,
  output wire [4:0] Addr,
  output reg        WE
);

  localparam RESET = 3'b000;
  localparam INF_BITS = 3'b001;
  localparam DATA_IN = 3'b010;
  localparam DATA_IN_INC = 3'b011;
  localparam DATA_OUT = 3'b100;
  localparam IDLE = 3'b101;


  reg [7:0] data_reg;
  reg [4:0] addr_reg;
  reg [1:0] mode_reg;
  reg [3:0] cnt;
  reg [2:0] state;
  reg       MISO_en;

  always @(negedge rst) begin
    if (!rst) begin
      state <= RESET;
    end
  end

  assign Addr = addr_reg;
  assign MISO = data_reg[0] & MISO_en;

  always @(posedge clk) begin
    case(state)

      RESET: begin
        data_reg <= 0;
        mode_reg <= 0;
        WE <= 0;
        cnt <= 4'b0000;
        MISO_en <= 0;
        state <= IDLE;
      end

      INF_BITS: begin
        MISO_en <= 0;

        if (cnt == 0 || cnt == 1)  mode_reg <= {MOSI, mode_reg[1]};
	      else addr_reg <= {MOSI, addr_reg[4:1]};

        if (cnt == 6) begin
          cnt <= 0;
          if (!mode_reg[1]) begin
            if(mode_reg[0]) begin 
              state <= DATA_IN_INC;
              MISO_en <= 1;
            end else state <= DATA_IN;
	        end else state <= DATA_OUT;
        end else cnt <= cnt + 1;
      end

      DATA_IN: begin
        WE <= 0;
        MISO_en <= 1;

        if (cnt == 1) begin
          data_reg <= Data_in;
          if (mode_reg[0]) addr_reg <= addr_reg + 1;
        end else data_reg <= {MOSI, data_reg[7:1]};

        if (cnt == 9) begin
          cnt <= 0;
          state <= IDLE;
        end else cnt <= cnt + 1;
      end

      DATA_IN_INC: begin
        WE <= 0;
        MISO_en <= 1;

        if (cnt == 0) begin //end of memory check
          data_reg[0] <= (addr_reg == 5'b11111) ? 1 : 0;
        end else if (cnt == 1) begin
          data_reg <= Data_in;
          addr_reg <= addr_reg + 1;
        end else data_reg <= {MOSI, data_reg[7:1]};

        if (cnt == 8) begin
          cnt <= 0;
          if (CS) state <= IDLE;
        end else cnt <= cnt + 1;
      end

      DATA_OUT: begin
        data_reg <= {MOSI, data_reg[7:1]};
        MISO_en <= 0;

	      if (cnt == 8) begin
	        Data_out <= data_reg[7:0];
          WE <= 1;
        end

        if (cnt == 9) begin
          cnt <= 0;
          WE <= 0;
          state <= IDLE;
        end else cnt <= cnt + 1;

      end
      IDLE: begin
        MISO_en <= 0;
        if (!CS) state <= INF_BITS;
      end
      default: begin 
        state <= IDLE;
      end
    endcase
  end

endmodule

