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
  inout  tri1       sda,
  inout  tri1       scl
);

  localparam IDLE     = 0;
  localparam DATA     = 1;
  localparam DATA_RD  = 2;
  localparam DATA_WR  = 3;
  localparam DATAEND1 = 4;
  localparam DATAEND2 = 5;
  localparam START1   = 6;
  localparam START2   = 7;
  localparam DELAY    = 8;
  localparam STOP1    = 9;
  localparam STOP2    = 10;

  reg        ack_err_r;
  reg        rw_r;
  reg [7:0]  data_wr_r;
  reg [7:0]  data_rd_r;

  reg [12:0] tx_r;
  reg [7:0]  rx_r;

  reg [5:0]  bit_cnt;

  reg [3:0]  state;
  reg [3:0]  next_state;

  reg  sda_r;
  reg  scl_r;
  wire scl_t;

  assign data_rd = data_rd_r;
  assign ack_err = ack_err_r;

  assign busy = (state == IDLE) ? 1'b0 : 1'b1;
  
  assign sda = (sda_r) ? 1'bz : 1'b0;
  assign scl = (scl_t) ? 1'bz : scl_r;
  

  assign scl_t = (state == START2)  ? 1'b0 :
                 (state == DATA)    ? 1'b0 :
                 (state == DATA_RD) ? 1'b0 :
                 (state == DATA_WR) ? 1'b0 :
                 (state == DATAEND1) ? 1'b0 : 
                 (state == DATAEND2) ? 1'b0 : 
                 (state == DELAY) ? 1'b0 : 
                 (state == STOP1)   ? 1'b0 : 
                  1'b1;

  // start and stop bits, sda transmission when DATA or DATA_WR states 
  always @(*) begin
    if (state == START1 || state == START2 || state == STOP1 || state == STOP2) begin
      sda_r = 1'b0;
    end else if (state == DATA || state == DATA_WR) begin
      sda_r = tx_r[0];
    end else
      sda_r = 1'b1;
  end

  // start and stop bits, else scl = clk 
  always @(*) begin
    if (state == START2 || state == STOP1) begin
      scl_r = 1'b0;
    end else if (state != IDLE) begin
      scl_r = clk;
    end
  end

  // if nack acc_err 1, else 0
  always @(*) begin
    if (!rst) begin
      ack_err_r <= 1'b0;
    end else begin
      if (state == DATAEND1) begin
        if (sda == 0) ack_err_r <= 1'b0;
        else ack_err_r <= 1'b1; 
      end else if (state == DATAEND2 && rw_r) begin
        if (sda == 0) ack_err_r <= 1'b0; 
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
      if (!scl) bit_cnt <= (state == DATA || state == DATA_WR || state == DATA_RD  || state == DELAY) ? bit_cnt + 1 : 4'b0;
    end
  end

  //sets data to tx before start of transmittion, after first word
  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      tx_r <= 13'b0;
    end else begin
      if (state == DATA || state == DATA_WR) begin
        if (!scl) tx_r <= tx_r >> 1;
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
      if (state == DATA_RD) begin
        rx_r <= {sda, rx_r[7:1]};
      end 
    end
  end

  always @(posedge clk, negedge rst) begin
    if (!rst) begin
      state <= 4'b0;
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
        sda_r = 1'b1;
        scl_r = 1'b1;
      end
      START1: begin
        next_state = START2;
        sda_r = 1'b0;
        scl_r = 1'b0;
      end
      START2: begin
        next_state = DATA;
        sda_r = 1'b0;
        scl_r = clk;
      end
      DATA: begin
        if (bit_cnt == 12) begin
          next_state = DATAEND1;
        end else begin
          next_state = state;
        end
        sda_r = tx_r[0];
        scl_r = clk;
      end
      DATA_RD: begin
        if (bit_cnt == 9) begin
          next_state = DATAEND2;
        end else begin
          next_state = state;
        end
        sda_r = 1'b1;
        scl_r = clk;
      end
      DATA_WR: begin
        if (bit_cnt == 7) begin
          next_state = DATAEND2;
        end else begin
          next_state = state;
        end
        sda_r = tx_r[0];
        scl_r = clk;
      end
      DATAEND1: begin
        if (sda == 0) begin
          next_state = (rw_r == 1'b1) ? DATA_WR : DELAY;
        end else begin
          next_state = STOP1;
        end
        sda_r = 1'b1;
        scl_r = clk;
        if (sda == 0) ack_err_r <= 1'b0;
        else ack_err_r <= 1'b1; 
      end
      DATAEND2: begin
        next_state = STOP1;
        sda_r = 1'b1;
        scl_r = clk;
        if (sda == 0) ack_err_r <= 1'b0;
        else ack_err_r <= 1'b1; 
      end
      DELAY: begin
        if (bit_cnt == 1) begin
          next_state = DATA_RD;
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