module uart_rx (input wire rx, clk, rst, rx_valid, output wire[7:0] rx_data, output reg rx_ready, rx_err);

  reg [3:0] counter;
  reg [3:0] sample_counter;
  reg [9:0] rx_shift;
  reg [7:0] rx_reg;
  reg       rx_delayed;
  reg       rx_start2;
  reg       rx_start1;
  reg       rx_start;
  reg       rx_en;
  reg       clk2;

  reg[13:0] div868 = 14'd868;

  clock_divider div(.rst(rst),
                    .coef(div868),
                    .in_clk(clk),
                    .out_clk(clk1));

  always @(negedge clk1) begin
    if (counter == 9) begin
      rx_start1 = ~rx;
    end
  end

  always @(posedge clk1 or negedge rst or posedge rx_start ) begin

    if (!rst) begin
      counter <= 9;
      sample_counter <= 9;
      rx_err <= 0;
      rx_start2 <= 0;
      rx_start1 <= 0;
      rx_en <= 0;
    end else begin

      if (counter == 9) begin
         rx_start2 = ~rx;
      end else rx_start2 = 0;

      if (counter == 0) begin
        sample_counter <= 0;
      end

      if (sample_counter == 9) begin
        if (rx_en) begin
          if (rx_shift[9] == 1'b1) begin
            rx_reg <= rx_shift[8:1];
          end else rx_err <= 1;
	end
        rx_en <= rx_start;
      end

      if (counter != 9) counter <= counter + 1;
      else if (rx_start) counter <= 0;
      if (sample_counter != 9) sample_counter <= sample_counter + 1;

      if (rx_en) rx_shift <= {rx_delayed, rx_shift[9:1]};

      rx_delayed <= rx;
      
    end
  end

  always @(*) rx_start = rx_start1 && rx_start2;

endmodule