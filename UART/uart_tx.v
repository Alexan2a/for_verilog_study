module uart_tx (input wire rst, clk, tx_valid,
                input wire [7:0] tx_data,
	        output reg tx, tx_ready);

  wire       clk1;
  reg        tx_shift_en;
  reg [3:0]  counter;
  reg [7:0]  tx_reg;
  reg [9:0]  tx_shift;
  reg [13:0] div868 = 14'd868;

  clock_divider div(.rst(rst),
                    .coef(div868),
                    .in_clk(clk),
                    .out_clk(clk1));

  always @(posedge clk1 or negedge rst) begin

    if(!rst) begin
      tx_shift <= 10'd2047;
      tx_ready <= 1'b1;
      tx_shift_en <= 1'b1;
      counter <= 4'd9;
      tx <= 1;
    end else begin

      if (counter == 4'd0) begin
        if (!tx_ready) tx_shift <= {1'b1, tx_reg, 1'b0};
        else tx_shift_en <= 1'b0;
      end else begin
        if (tx_shift_en) tx_shift <= {1'b1, tx_shift[9:1]};
      end

      if (counter == 4'd9) begin
        if (tx_valid && tx_ready) begin
          counter <= 0;
          tx_reg <= tx_data;
          tx_ready <= 1'b0;
          tx_shift_en <= 1'b1;
        end
      end else counter = counter + 1;

      if (counter == 4'd8) tx_ready <= 1'b1;
							
      tx <= tx_shift[0];

    end
  end

endmodule