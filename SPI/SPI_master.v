module spi_master(
  input  wire        rst,
  input  wire        clk,
  input  wire        MISO,
  input  wire [14:0] Data_in,
  input  wire        tx_valid,
  input  wire        CS_Sel,
  output wire        CS0,
  output wire        CS1,
  output wire        MOSI,
  output reg         rx_ready,
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
  reg        CS;
  reg  [4:0] inc_cnt;
  reg        MOSI_en;

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

  assign MOSI =  data_reg[0] & MOSI_en;

  always @(posedge clk) begin
    case(state)
      RESET: begin
        data_reg <= 15'b0;
        mode_reg <= 2'b0;
        inc_cnt <= 5'b00000;
        cnt <= 5'b00000;
	      state <= IDLE;
        MOSI_en <= 1;
        CS <= 1;
      end
  
      DATA: begin
        if(cnt == 0) begin
          if (mode_reg[0]) inc_cnt <= data_reg[11:7];
        end else data_reg <= {MISO, data_reg[14:1]};
        
        if (cnt == 1) begin
          if (!mode_reg[0] || (mode_reg[0] && (inc_cnt == 5'b00001 || inc_cnt == 5'b00000 || data_reg[6:2] == 5'b11111))) CS <= 1;
        end
        
        if (cnt == 18) begin
          cnt <= 0;
          if (!mode_reg[0] || CS) state <= IDLE;
          else begin
            state <= DATA_INC;
            inc_cnt <= inc_cnt - 2;
          end
          rx_ready <= !mode_reg[1];
	        Data_out <= data_reg[14:7];
        end else cnt <= cnt + 1;
      end

      DATA_INC: begin
        MOSI_en <= 0;
        data_reg <= {MISO, data_reg[14:1]};
        if (cnt == 0 && (data_reg[14] == 1 || !inc_cnt)) CS <= 1;
        if (cnt == 8) begin
          if (CS || !inc_cnt) begin
           state <= IDLE;
          end else inc_cnt <= inc_cnt - 1;
          cnt <= 0;
          rx_ready <= !mode_reg[1];
	        Data_out <= data_reg[14:7];
        end else begin 
          cnt <= cnt + 1;
          rx_ready <= 0;
        end
      end 

      IDLE: begin
        if (tx_valid) begin
          CS <= 0;
          rx_ready <= 0;
          data_reg <= Data_in;
          mode_reg <= Data_in[1:0];
          MOSI_en <= 1;
          state <= DATA;
        end
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end

endmodule