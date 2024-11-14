module i2c_master (
  input  wire       clk,
  input  wire       rst,
  input  wire       en,

  input  wire [6:0] addr,
  input  wire       rw,
  input  wire [4:0] mem_addr,
  input  wire [7:0] data_wr,
  output wire [7:0] data_rd,

  output wire       ack_err,
  output wire       busy,

  input  wire       sda_i,
  output wire       sda_o,
  output wire       sda_t,
  input  wire       scl_i,
  output wire       scl_o,
  output wire       scl_t
);

  localparam IDLE     = 0;
  localparam DATA1    = 1;
  localparam DATA2    = 2;
  localparam DATAEND1 = 3;
  localparam DATAEND2 = 4;
  localparam START1   = 5;
  localparam START2   = 6;
  localparam DELAY    = 7;
  localparam STOP1    = 8;
  localparam STOP2    = 9;

  reg        ack_err_r;
  reg        rw_r;
  reg [7:0]  data_wr_r;
  reg [7:0]  data_rd_r;

  reg [12:0] tx_r;
  reg [7:0]  rx_r;

  reg [5:0]  bit_cnt;

  reg [3:0]  state;
  reg [3:0]  next_state;

  assign data_rd = data_rd_r;
  assign ack_err = ack_err_r;

  assign busy = (state == IDLE) ? 1'b0 : 1'b1;
  
  // start and stop bits, else scl = clk 
  assign scl_t = (state == START2)  ? 1'b0 :
                 (state == DATA1)   ? 1'b0 :
                 (state == DATA2)   ? 1'b0 :
                 (state == DATAEND1)? 1'b0 : 
                 (state == DATAEND2)? 1'b0 : 
                 (state == DELAY)   ? 1'b0 : 
                 (state == STOP1)   ? 1'b0 : 
                  1'b1;

  assign scl_o = (state == START2)  ? 1'b0 :
                 (state == DATA1)   ? clk :
                 (state == DATA2)   ? clk :
                 (state == DATAEND1)? clk : 
                 (state == DATAEND2)? clk : 
                 (state == DELAY)   ? clk : 
                 (state == STOP1)   ? clk : 
                  1'b1;

  // start and stop bits, sda transmission when DATA or DATA_WR states 
   assign sda_t = (state == START1 || state == START2 || state == STOP1 || state == STOP2 || state == DATA1 || (state == DATA2 && rw_r) || (state == DATAEND2 && !rw_r) || state == DELAY) ? 1'b0 : 1'b1;

   assign sda_o = (state == START1 || state == START2 || state == STOP1 || state == STOP2 || (state == DATAEND2 && !rw_r)) ? 1'b0 :
                  (state == DATA1 || (state == DATA2 && rw_r))? tx_r[0] :
                  1'b1;

  // if nack acc_err 1, else 0
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      ack_err_r <= 1'b0;
    end else begin
      if (state == DATAEND1) begin
        if (sda_i == 0) ack_err_r <= 1'b0;
        else ack_err_r <= 1'b1; 
      end else if (state == DATAEND2 && rw_r) begin
        if (sda_i == 0) ack_err_r <= 1'b0; 
        else ack_err_r <= 1'b1;   
      end 
    end
  end

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      data_rd_r <= 8'b0;
    end else begin
      if (state == DATAEND2 && !rw_r) begin
        data_rd_r <= rx_r;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst) begin
      data_wr_r <= 8'b0;
      rw_r <= 1'b0;
    end else if (!busy && en) begin
      rw_r <= rw;
      data_wr_r <= data_wr;
    end
  end

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      bit_cnt <= 4'b0;
    end else begin
      if (scl_i) begin
        if (state == DATA2 && bit_cnt == 7) bit_cnt <= 4'b0;
        else if (state == DELAY && bit_cnt == 1) bit_cnt <= 4'b0;
        else if (state == DATA1 || state == DATA2 || state == DELAY) bit_cnt <= bit_cnt + 1; 
        else bit_cnt <= 4'b0;
      end
    end
  end

  //sets data to tx before start of transmittion, after first word
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      tx_r <= 13'b0;
    end else begin
      if (state == DATA1 || (state == DATA2 && rw_r)) begin
        if (scl_i) tx_r <= tx_r >> 1;
      end else if (!busy && en) begin
        tx_r <= {addr, mem_addr, rw};
      end else if (state == DATAEND1 && rw_r && !ack_err) begin
        tx_r <= {5'b0, data_wr_r};
      end
    end
  end
  
  //shift when state is DATA_RD
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      rx_r <= 8'b0;
    end else begin
      if (state == DATA2 && !rw_r) begin
        if (scl_i) rx_r <= {sda_i, rx_r[7:1]};
      end 
    end
  end

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  //FSM next state process
  always @(*) begin
    case(state)
      IDLE: begin
        if (en) next_state = START1;
        else next_state = state;
      end
      START1: begin
        next_state = START2;
      end
      START2: begin
        next_state = DATA1;
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
        if (sda_i == 0) begin
          next_state = (rw_r == 1'b1) ? DATA2 : DELAY;
        end else begin
          next_state = STOP1;
        end
      end
      DATAEND2: begin
        next_state = STOP1;
      end
      DELAY: begin
        if (bit_cnt == 1) begin
          next_state = DATA2;
        end else begin
          next_state = state;
        end
      end
      STOP1: begin
        next_state = STOP2;
      end
      STOP2: begin
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule