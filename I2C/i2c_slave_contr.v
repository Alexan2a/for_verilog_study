module i2c_slave_contr #(parameter ADDR=0) (
  input  wire       clk,
  input  wire       rst,

  input  wire       scl_i,
  output wire       scl_o,
  output wire       scl_t,
  input  wire       sda_i,
  output wire       sda_o,
  output wire       sda_t,

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

  reg       scl_prev;
  reg       stop2;
  reg       stop1;
  reg       start;

  reg [12:0]rx_r;
  reg [7:0] tx_r;

  reg [3:0] state;
  reg [3:0] next_state;

  assign mem_addr = mem_addr_r;
  assign WE = WE_r;
  assign data_out = data_out_r;

  assign scl_t = 1'b1;
  assign scl_o = 1'b0;
  //set address of device
  always @(negedge rst) begin
    if (!rst) begin
      addr_r <= ADDR;
    end 
  end
 
//catch START sign
  always @(negedge sda_i or negedge scl_i ) begin
      if (~scl_i) start <=0;
      else start <= 1'b1;
   end 
  //catch STOP signs
  //assign stop2 = stop_bit_1 && scl_i;
  always @(*) begin
    if (!scl_i) stop2 = 1'b0;
    else stop2 = stop1;
  end

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      stop1 <= 1'b0;
    end else begin
      if (!scl_i) stop1 <= 1'b0;
      else if (!sda_i) stop1 <= 1'b1;
      else stop1 <= 1'b0;
    end
  end

  assign sda_t = (state == DATAEND1 && rx_r[12:6] == addr_r) ? 1'b0 :
                 (state == DATAEND2 && rw_r) ? 1'b0 :
                 (state == DATA_RD) ? 1'b0 : 
                  1'b1;

  assign sda_o = (state == DATAEND1 && rx_r[12:6] == addr_r) ? 1'b0 :
                 (state == DATAEND2 && rw_r) ? 1'b0 :
                 (state == DATA_RD) ? tx_r[0] :
                  1'b1;

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
      if (scl_i) begin
        if (state == DATA_WR && bit_cnt == 7) bit_cnt <= 4'b0;
        else if (state == DATA_RD && bit_cnt == 9) bit_cnt <= 4'b0;
        else if (state == DATA || state == DATA_WR || state == DATA_RD || state == DELAY) bit_cnt <= bit_cnt + 1;
        else bit_cnt <= 4'b0;
      end
    end
  end

  //rx_r shift (sda input) when state is DATA or DATA_RD
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      rx_r <= 13'b0;
    end else begin
      if (state == DATA_WR || state == DATA) begin
        rx_r <= {sda_i, rx_r[12:1]};
      end 
    end
  end

  //tx_r shift (sda output) when state is DATA_WR
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      tx_r <= 13'b0;
    end else begin
      if (state == DELAY) begin
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
      if (state == HOLD && stop2) begin
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
        if (start)next_state = START;
        else next_state = IDLE;
      end
      START: begin
        next_state = DATA;
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
        if (stop2) next_state = IDLE;
        else next_state = state;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule