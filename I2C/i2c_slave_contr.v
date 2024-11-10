module i2c_slave_contr #(parameter ADDR=0) (
  input  wire       clk,
  input  wire       rst,
  input  tri1       scl,
  inout  tri1       sda,
  input  wire [7:0] data_in,
  output wire       WE,
  output wire [4:0] mem_addr,
  output wire [7:0] data_out
);
  
  localparam IDLE     = 0;
  localparam DATA     = 1;
  localparam DATA_RD  = 2;
  localparam DATA_WR  = 3;
  localparam DATAEND1 = 4;
  localparam DATAEND2 = 5;
  localparam START    = 6;
  localparam DELAY    = 7;
  localparam HOLD     = 8;

  reg [4:0] mem_addr_r;
  reg       WE_r;
  reg [7:0] data_out_r;

  reg [6:0] addr_r;
  reg [3:0] bit_cnt;
  reg       rw_r;

  reg       stop_bit_1;
  wire      stop_bit_2;

  reg [12:0]rx_r;
  reg [7:0] tx_r;

  reg [3:0] state;
  reg [3:0] next_state;

  reg  sda_r;

  assign mem_addr = mem_addr_r;
  assign WE = WE_r;
  assign data_out = data_out_r;

  //set address of device
  always @(negedge rst) begin
    if (!rst) begin
      addr_r <= ADDR;
    end 
  end
 
  //catch STOP signs
  assign stop_bit_2 = stop_bit_1 && scl;

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      stop_bit_1 <= 1'b0;
    end
    stop_bit_1 <= scl && !sda;
  end


  assign sda = (sda_r) ? 1'bz : 1'b0;

  always @(*) begin
    sda_r = (state == DATAEND1 && rx_r[12:6] == addr_r) ? 1'b0 :
            (state == DATAEND2 && rw_r) ? 1'b0 :
            (state == DATA_RD) ? tx_r[0] :
             1'b1;
  end

  //sets registers to recieved data
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      mem_addr_r <= 5'b0;
      rw_r <= 1'b0;
    end else begin
      if (state == DATAEND1) begin
        rw_r <= rx_r[0];
        mem_addr_r <= rx_r[5:1];
      end 
    end
  end

  //bit_cnt increment when bits transmision (states DATA, DATA_WR, DATA_RD)
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      bit_cnt <= 4'b0;
    end else begin
      bit_cnt <= (state == DATA || state == DATA_WR || state == DATA_RD || state == DELAY) ? bit_cnt + 1 : 4'b0;
    end
  end

  //rx_r shift (sda input) when state is DATA or DATA_RD
  always @(posedge scl, negedge rst) begin
    if (!rst) begin
      rx_r <= 13'b0;
    end else begin
      if (state == DATA_WR || state == DATA) begin
        rx_r <= {sda, rx_r[12:1]};
      end 
    end
  end

  //tx_r shift (sda output) when state is DATA_WR
  always @(posedge scl, negedge rst) begin
    if (!rst) begin
      tx_r <= 13'b0;
    end else begin
      if (state == DELAY && bit_cnt == 1) begin
        tx_r <= data_in;
      end if (state == DATA_RD) begin
        tx_r <= tx_r >> 1;
      end
    end
  end

  //set WE and data_out to write to memory if mode is "write"
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      WE_r <= 1'b0;
      data_out_r <= 8'b0;
    end else begin
      if (state == HOLD && stop_bit_2) begin
        if (rw_r) begin
          WE_r <= 1'b1;
          data_out_r <= rx_r[12:5];
        end
      end else if (WE_r) WE_r <= 1'b0;
    end
  end

  //assigning new state value
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  //FSM next_state process
  always @(*) begin
    case(state)
      IDLE: begin
        if (!sda && scl) next_state = START;
        else next_state = IDLE;
      end
      START: begin
        if (!sda && !scl) next_state = DATA;
        else next_state = IDLE;
      end
      DATA: begin
        if (bit_cnt == 12) begin
          next_state = DATAEND1;
        end else begin
          next_state = state;
        end
      end
      DATA_RD: begin
        if (bit_cnt == 9) begin
          next_state = DATAEND2;
        end else begin
          next_state = state;
        end
      end
      DATA_WR: begin
        if (bit_cnt == 7) begin
          next_state = DATAEND2;
        end else begin
          next_state = state;
        end
      end
      DATAEND1: begin
        if (rx_r[12:6] == addr_r) begin
          next_state = (rx_r[0] == 1'b1) ? DATA_WR : DELAY;
        end else begin 
          next_state = IDLE;
        end
      end
      DATAEND2: begin
        next_state = HOLD;
      end
      DELAY: begin
        if (bit_cnt == 1) begin
          next_state = DATA_RD;
        end else begin
          next_state = state;
        end
      end
      HOLD: begin
        if (stop_bit_2) next_state = IDLE;
        else next_state = state;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule