module clock_divider (input wire in_clk, rst,
                      input wire [13:0] coef,
                      output reg  out_clk);

  reg [13:0] counter;

  always @(posedge in_clk or negedge rst) begin

    if (!rst) begin
      counter <= 14'd0;
    end else if (counter >= (coef - 1)) begin
      counter <= 14'd0;
    end else counter <= counter + 14'd1;

    out_clk <= (counter < coef/2) ? 1'b1 : 1'b0;

  end

endmodule
