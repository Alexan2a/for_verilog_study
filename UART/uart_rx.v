module uart_rx (
  input wire rx, clk, rst,
  output wire [7:0] rx_data,
  output reg rx_ready
);

  reg [3:0]  counter;
  reg [9:0]  rx_shift;
  reg [7:0]  rx_reg;
  reg        rx_delayed;
  reg        rx_en;
  reg        rx_d;
  reg        rx_start;
  reg        rx_busy;
  reg        clk_rst;
  reg [13:0] div868;

  clock_divider div(
    .rst(clk_rst),
    .coef(div868),
    .in_clk(clk),
    .out_clk(clk1)
  );

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      rx_start <= 1;
      clk_rst <= 1;
    end else begin
      rx_d <= rx;
      if (rx_busy) rx_start <= 0;
      else if (!rx_busy && rx_d == 1 && rx == 0) begin
        clk_rst <= 0;
        rx_start <= 1;
      end else clk_rst <= 1;
    end
  end

  always @(posedge clk1 or negedge rst) begin

    if (!rst) begin
      rx_ready <= 0;
      rx_busy <= 0;
      div868 <= 14'd868;
      counter <= 0;
    end else begin

      if (rx_start && rx == 0) begin
        rx_busy <= 1;
      end

      rx_delayed <= rx;
      if (rx_en) rx_shift <= {rx_delayed, rx_shift[9:1]};

      if (counter == 0) begin
        if (rx_en) begin
          rx_reg <= rx_shift[8:1];
          rx_ready <= 1;
        end else rx_ready <= 0;
        rx_en <= rx_busy;
      end

      if (counter == 8) rx_busy <= 0;

      if (counter == 9 || !rx_busy) counter <= 0;
      else counter <= counter + 1;

    end
  end

  assign rx_data = rx_reg;

endmodule