module spi_master(
  input  wire        rst,
  input  wire        clk,
  input  wire        MISO,
  input  wire [14:0] Data_in,
  input  wire        data_in_valid,
  input  wire        CS_Sel,
  output wire        CS0,
  output wire        CS1,
  output wire        MOSI,
  output reg         data_out_valid,
  output reg   [7:0] Data_out
);

  localparam RESET = 2'b00;
  localparam DATA = 2'b01;
  localparam DATA_INC = 2'b10;
  localparam IDLE = 2'b11;


  reg [14:0] data_reg;
  reg  [1:0] mode_reg;
  reg  [4:0] cnt;
  reg  [1:0] state;
  reg  [1:0] next_state;
  reg        CS;
  reg  [4:0] inc_cnt;

  // sets CS0 or CS1 to CS depending on CS_Sel
  demux_2_to_1 CS_ctrl(
    .Sel(CS_Sel),
    .D(CS),
    .S0(CS0),
    .S1(CS1)
  );
  
   always @(negedge rst, posedge clk) begin
    if (!rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  assign MOSI = (state == DATA) ? data_reg[0] : 1'b0;

  // sets data_out_valid to 1 when read mode and data from slave recieved, sets to 0 if not
  always @(negedge rst, posedge clk) begin
    if (!rst) begin
      data_out_valid <= 0;
    end else begin
      data_out_valid <= (state == DATA && cnt == 17) ? !mode_reg[1] :
                  (state == DATA_INC && cnt == 9) ? 1'b1 :
                   1'b0;
    end
  end

  // sets Data_out to recieved data
  always @(negedge rst, posedge clk) begin
    if (!rst) begin
      Data_out <= 0;
    end else if (((state == DATA && cnt == 17) || (state == DATA_INC && cnt == 9)) && !mode_reg[1]) begin
      Data_out <= data_reg[14:7];
    end
  end

  // increment counter process: sets inc_cnt at the start of transmission, 
  //                            reduces inc_cnt depending on state;
  always @(negedge rst, posedge clk) begin
    if (!rst) begin
      inc_cnt <= 5'b00000;
    end else if (state == DATA && cnt == 0 && mode_reg[0]) inc_cnt <= data_reg[11:7];
    else if     (state == DATA && cnt == 17 && mode_reg[0]) inc_cnt <= inc_cnt - 2;
    else if     (state == DATA_INC && cnt == 9 ) inc_cnt <= inc_cnt - 1;
  end

  // data_register process: sets input data to register when mode state IDLE and it is valid, 
  //                        otherwise shifts register if state != IDLE;
  always @(negedge rst, posedge clk) begin 
    if (!rst) begin
      data_reg <= 0;
    end else if (state == IDLE && data_in_valid) data_reg <= Data_in;
    else if (state == DATA || state == DATA_INC) data_reg <= {MISO, data_reg[14:1]};
  end

  // counter process: nulls cnt when state time ends, otherwise increments cnt
  always @(negedge rst, posedge clk) begin 
    if (!rst) begin
      cnt <= 5'b0000;     // counter process
    end else if (state != IDLE) begin
      cnt <= (state == DATA    && cnt == 5'd17) ? 5'b0000 :
             (state == DATA_INC && cnt == 5'd9) ? 5'b0000 :
              cnt + 1;       
    end
  end

  // CS process: sets CS to 1 when it is not incremented read or write mode, 
  //                               the end of memory was reached in incremented read mode,
  //                               the proper count of data was read in incremented read mode,
  //                       sets CS to 0 when state is IDLE and there is valid data input;
  always @(negedge rst, posedge clk) begin 
    if (!rst) begin
      CS <= 1'b1;
    end else if (state == DATA && cnt == 1) begin
      CS <= (!mode_reg[0] || (mode_reg[0] && (inc_cnt == 5'b00001 || inc_cnt == 5'b00000 || data_reg[5:1] == 5'b11111))) ? 1'b1 : 1'b0;      
    end else if (state == DATA_INC && cnt == 0) begin
      CS <= (data_reg[14] == 1 || !inc_cnt) ? 1'b1 : 1'b0;
    end else if (state == IDLE) CS <= (data_in_valid) ? 1'b0 : 1'b1;
  end
  
  always @(negedge rst, posedge clk) begin 
    if (!rst) begin
      mode_reg <= 1'b1;
    end else if (state == IDLE && data_in_valid) begin
       mode_reg <= Data_in[1:0];
    end
  end

  // FSM next state logic
  always @(*) begin
    case(state)
      DATA: begin
        if (cnt == 17) begin
          if (CS) next_state = IDLE;
          else next_state = DATA_INC;
        end else next_state = state;
      end

      DATA_INC: begin
        if (cnt == 9 && CS) next_state = IDLE;
        else next_state = state;
      end

      IDLE: begin
        if (CS == 0) next_state = DATA;
        else next_state = state;
      end
      
      default: begin
        next_state = IDLE;
      end
    endcase
  end
endmodule