module i2c_slave_contr #(parameter ADDR=0) (
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
  localparam DATA1    = 1;
  localparam DATAEND1 = 2;
  localparam DATA2    = 3;
  localparam HOLD     = 5;
  localparam DATAEND2 = 6;
  localparam DELAY    = 7;

  reg [4:0] mem_addr_r;
  reg       WE_r;
  reg [7:0] data_out_r;

  wire [6:0] addr_r;
  reg  [3:0] bit_cnt;
  reg        rw_r;

  reg [12:0]rx_r;
  reg [7:0] tx_r;

  reg [2:0] state;
  reg [2:0] next_state;

  reg       start_detect;
  reg       start_det;
  wire      start_clk;

  reg       stop_detect;
  reg       stop_resetter;
  wire      stop_rst;

  wire      state_rst;

  assign mem_addr = mem_addr_r;
  assign WE = WE_r;
  assign data_out = data_out_r;

  assign scl_t = 1'b1;
  assign scl_o = 1'b0;

  //set address of device
  assign addr_r = ADDR;

  //catch STOP sign
  assign stop_rst = !rst | stop_resetter;

  always @ (posedge stop_rst or posedge sda_i) begin   
    if (stop_rst)
      stop_detect <= 1'b0;
    else
      stop_detect <= scl_i;
  end

  always @ (negedge rst or posedge scl_i) begin   
    if (!rst)
      stop_resetter <= 1'b0;
    else
      stop_resetter <= stop_detect;
  end

//catch START sign
  assign start_clk = rst && sda_i;
  
  always @(posedge start_clk or negedge scl_i ) begin
    if (scl_i) begin
      start_det <= 1'b1;
    end else start_det <= 1'b0;
  end 

  always @(negedge sda_i or posedge scl_i) begin
    if (start_det) begin
      start_detect <= 1'b1;
    end else if (scl_i) start_detect <= 1'b0;
    else start_detect <= 1'b0;
   end 
 
  assign sda_t = (state == DATAEND1 && rx_r[12:6] == addr_r) ? 1'b0 :
                 (state == DATAEND2 && rw_r) ? 1'b0 :
                 (state == DATA2 && !rw_r) ? 1'b0 : 
                  1'b1;

  assign sda_o = (state == DATAEND1 && rx_r[12:6] == addr_r) ? 1'b0 :
                 (state == DATAEND2 && rw_r) ? 1'b0 :
                 (state == DATA2 && !rw_r) ? tx_r[0] :
                  1'b1;

  //sets registers to recieved data
  always @(posedge scl_i, negedge rst) begin
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
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      bit_cnt <= 4'b0;
    end else begin
        if (state == DATA2 && bit_cnt == 7) bit_cnt <= 4'b0;
        else if (state == DELAY && bit_cnt == 1) bit_cnt <= 4'b0;
        else if (state == DATA1 || state == DATA2 || state == DELAY) bit_cnt <= bit_cnt + 1;
        else bit_cnt <= 4'b0;
    end
  end

  //rx_r shift (sda input) when state is DATA or DATA_RD
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      rx_r <= 13'b0;
    end else begin
      if ((state == DATA2 && rw_r) || state == DATA1) begin
        rx_r <= {sda_i, rx_r[12:1]};
      end 
    end
  end

  //tx_r shift (sda output) when state is DATA_WR
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      tx_r <= 13'b0;
    end else begin
      if (state == DELAY && bit_cnt == 1) begin
        tx_r <= data_in;
      end if (state == DATA2 && !rw_r) begin
        tx_r <= tx_r >> 1;
      end
    end
  end

  //set WE and data_out to write to memory if mode is "write"
  always @(posedge scl_i, negedge rst) begin
    if (!rst) begin
      WE_r <= 1'b0;
      data_out_r <= 8'b0;
    end else begin
      if (state == DATAEND2) begin
        if (rw_r) begin
          WE_r <= 1'b1;
          data_out_r <= rx_r[12:5];
        end
      end else if (WE_r) WE_r <= 1'b0;
    end
  end

  assign state_rst = (state == HOLD) ? (rst & !stop_detect) : rst;

  always @(posedge scl_i, negedge state_rst) begin
    if (!state_rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  //FSM next_state process
  always @(*) begin
    case(state)
      IDLE: begin
        if (start_detect) next_state = DATA1;
        else next_state = IDLE;
      end
      DATA1: begin
        if (bit_cnt == 12) begin
          next_state = DATAEND1;
        end else begin
          next_state = state;
        end
      end
      DATA2: begin
        if (bit_cnt == 7) begin
          next_state = DATAEND2;
        end else begin
          next_state = state;
        end
      end
      DATAEND1: begin
        if (rx_r[12:6] == addr_r) begin
          next_state = (rx_r[0] == 1'b1) ? DATA2 : DELAY;
        end else begin 
          next_state = IDLE;
        end
      end
      DATAEND2: begin
        next_state = HOLD;
      end
      DELAY: begin
        if (bit_cnt == 1) begin
          next_state = DATA2;
        end else begin
          next_state = state;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule