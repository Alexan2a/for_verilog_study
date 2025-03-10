module clock_divider #(parameter C = 52)(
  input  wire        in_clk, 
  input  wire        rst,
  output reg         out_clk
);

  reg [$clog2(C)-1:0] counter;

  always @(posedge in_clk or negedge rst) begin

    if (!rst) begin
      counter <= 0'd0;
    end else if (counter >= (C - 1)) begin
      counter <= 0'd0;
    end else counter <= counter + 0'd1;

    out_clk <= (counter == C-1);

  end

endmodule