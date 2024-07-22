module uart_tb();
	
  reg clk, rst, valid;
  reg [7:0] in;
  wire [7:0] rx_out;
  wire tx_out, tx_ready, rx_ready;

  initial begin
    valid = 1;
    clk = 0;
    in = 0;
    #100000 valid = 1;
  end

  initial begin
    rst = 1;
    #10 rst = 0;
    #10 rst = 1;
  end

  always #5 clk = ~clk;
  always #600 in = in + 1;
  always @(tx_ready) begin
    #1000 valid = 1;
    #30000 valid = 0;
  end

  uart_tx my_tx(.rst(rst),
                .clk(clk),
                .tx_data(in),
                .tx(tx_out),
                .tx_ready(tx_ready),
                .tx_valid(valid));

  uart_rx my_rx(.rst(rst),
                .clk(clk),
                .rx(tx_out),
                .rx_data(rx_out),
                .rx_ready(rx_ready));


endmodule