`timescale 1ns / 1ps

module uart_tb();
	
  parameter CLK_DEC = 0;
  parameter CLK_TX_HP = 5;
  parameter CLK_RX_HP = CLK_TX_HP * (CLK_DEC*0.01 + 1);
  parameter DELAY = 0;

  reg clk_tx, clk_rx, rst, valid, valid_rst;
  reg [7:0] in [0:10];
  reg [7:0] transport;
  wire [7:0] rx_out;
  wire tx_out, rx_in, tx_ready, rx_ready;

  integer in_coef = 0;
  integer out_coef = 0;
  integer err_cnt = 0;

  initial begin
    in[0] = 8'h15;
    in[1] = 8'h4d;
    in[2] = 8'h03;
    in[3] = 8'ha4;
    in[4] = 8'h2e;
    in[5] = 8'hc8;
    in[6] = 8'hfa;
    in[7] = 8'h22;
    in[8] = 8'h14;
    in[9] = 8'h32;
    in[10] = 8'hea;
  end

  initial begin
    valid = 1;
    valid_rst = 1;
    #300000 valid_rst = 0;
    #500000 valid_rst = 1;
  end

  initial begin
    clk_tx = 0;
    forever #CLK_TX_HP clk_tx = ~clk_tx;
  end

  initial begin
    clk_rx = 0;
    forever #CLK_RX_HP clk_rx = ~clk_rx;
  end

  initial begin
    rst = 1;
    #10 rst = 0;
    #10 rst = 1;
  end

  always @(tx_ready, valid_rst) begin
    if (!valid_rst) valid = 0;
    else begin
      valid = 1;
      #30000 valid = 0;
      in_coef = in_coef + 1;
    end
  end

  always @(tx_out)
    begin
      transport <= #DELAY tx_out;
  end
  assign rx_in = transport;

  uart_tx my_tx(.rst(rst),
                .clk(clk_tx),
                .tx_data(in[in_coef]),
                .tx(tx_out),
                .tx_ready(tx_ready),
                .tx_valid(valid));

  uart_rx my_rx(.rst(rst),
                .clk(clk_rx),
                .rx(rx_in),
                .rx_data(rx_out),
                .rx_ready(rx_ready));

  always @(rx_out) begin
    if (rx_out != in[out_coef]) begin
      $error("rx_out: expected = %h, real = %h", in[out_coef], rx_out);
      err_cnt = err_cnt + 1;
    end
    out_coef = out_coef + 1;
  end

  initial begin
    #1500000 $display("Output errors: %d", err_cnt);
    $stop();
  end

endmodule