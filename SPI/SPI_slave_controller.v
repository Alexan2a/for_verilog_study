module spi_slave_ctrl(
  input  wire        rst,
  input  wire        clk,
  input  wire        MOSI,
  input  wire        CS,
  input  wire  [7:0] Data_in,
  output wire        MISO,
  output reg   [7:0] Data_out,
  output wire  [4:0] Addr,
  output wire        WE
);

  localparam RESET = 3'b000;
  localparam INF_BITS = 3'b001;
  localparam DATA_RD = 3'b010;
  localparam DATA_RD_INC = 3'b011;
  localparam DATA_WR = 3'b100;
  localparam IDLE = 3'b101;


  reg [7:0] data_reg;
  reg [4:0] addr_reg;
  reg [1:0] mode_reg;
  reg [3:0] cnt;
  reg [2:0] state;
  reg [2:0] next_state;
  wire      slave_clk;

  assign slave_clk = (state == IDLE) ? 1'b1 : clk;   // disables clk when not needed
  assign Addr = addr_reg;
  assign MISO = (state == DATA_RD || state == DATA_RD_INC) ? data_reg[0] : 1'b0;   // disables MISO when not needed

  always @(negedge rst, posedge clk) begin
    if (!rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state logic
  always @(state, mode_reg, CS, cnt) begin
    case(state)

      INF_BITS: begin
        if (cnt == 6) begin
          next_state = (mode_reg == 0'b01) ? DATA_RD_INC :
                       (mode_reg == 0'b00) ? DATA_RD :
                       (mode_reg == 0'b10) ? DATA_WR :
                       state;
        end
      end

      DATA_RD: begin
         if (cnt == 9 && CS) next_state = IDLE;
         else next_state = state;
      end

      DATA_RD_INC: begin
        if (cnt == 9 && CS) next_state = IDLE;
        else next_state = state;
      end

      DATA_WR: begin
        if (cnt == 9 && CS) next_state = IDLE;
        else next_state = state;
      end

      IDLE: begin
        if (!CS) next_state = INF_BITS;
        else next_state = state;
      end
      default: begin
	      next_state = IDLE;   //i don't know what will be better here;
      end
    endcase
  end

  // inform registers process: shifts mode register (cnt is 0 or 1) and address register,
  //                           increments address register if state == DATA_RD_INC;
  always @(negedge rst, posedge slave_clk) begin     
    if (!rst) begin
      addr_reg <= 5'b00000;
      mode_reg <= 2'b00;
    end else if (state == DATA_RD_INC && cnt == 1) addr_reg <= addr_reg + 1;
    else if (state == INF_BITS) begin
      if (cnt == 0 || cnt == 1) mode_reg <= {MOSI, mode_reg[1]};
      else addr_reg <= {MOSI, addr_reg[4:1]};
    end
  end

  // data register process: sets RAM data to register when mode is read, 
  //                        sets [0] bit to 1 if the end of memory was reached,
  //                        otherwise shifts register, if state != IDLE or state != INF_BITS;
  always @(negedge rst, posedge slave_clk) begin
    if (!rst) data_reg <= 8'b00000000;
    else if ((state == DATA_RD || state == DATA_RD_INC) && cnt == 1) data_reg <= Data_in;
    else if (state == DATA_RD_INC && cnt == 9) begin
      data_reg <= (addr_reg == 5'b11111) ? {data_reg[7:1], 1} : {data_reg[7:1], 0};
    end else if (state == DATA_RD || state == DATA_RD_INC || state == DATA_WR) data_reg <= {MOSI, data_reg[7:1]};
  end

  // counter process: nulls cnt when state time ends, otherwise increments cnt
  always @(negedge rst, posedge slave_clk) begin 
    if (!rst) begin
      cnt <= 4'b0000;
    end else if (state != IDLE) begin
      cnt <= (state == INF_BITS    && cnt == 4'b0110) ? 4'b0000 :
             (state == DATA_RD     && cnt == 4'b1001) ? 4'b0000 :
             (state == DATA_WR     && cnt == 4'b1001) ? 4'b0000 :
             (state == DATA_RD_INC && cnt == 4'b1001) ? 4'b0000 :
              cnt + 1;       
    end
  end

  // sets data to write to RAM
  always @(posedge slave_clk) begin
    if (state == DATA_WR && cnt == 8) Data_out <= data_reg;
  end
  
  // write enable
  assign WE = (state == DATA_WR && cnt == 9) ? 1'b1 : 1'b0;

endmodule



