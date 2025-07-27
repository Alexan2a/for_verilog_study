module exp_smoothing_filter #(
  parameter L = 7,
  parameter IN_WH = 32,
  parameter IN_FR = 30,
  parameter VAL_WH = 32,
  parameter VAL_FR = 30,
  parameter BETA_SHIFT = 4
)(
  input  wire clk,
  input  wire nrst,
  input  wire en,
  input  wire [IN_WH -1:0] in,
  output wire [VAL_WH-1:0] out
);

  //////////////////////////////////////////////////////////
  //                                                      //
  //   next_value = curr_value + beta*(in - curr_value)   //
  //                                                      //
  //////////////////////////////////////////////////////////

  //expecting IN_SIZE to be >= VAL_SIZE;
  localparam IN_INT = IN_WH - IN_FR;
  localparam VAL_INT = VAL_WH - VAL_FR;
  localparam SUM_INT = (IN_INT > VAL_INT) ? IN_INT+1 : VAL_INT+1;
  localparam SUM_FR = (IN_FR > VAL_FR) ? IN_FR : VAL_FR;
  localparam SUM_WH = SUM_INT + SUM_FR;

  wire [VAL_WH-1:0]   curr_value;
  wire [VAL_WH-1:0]   next_value;
  wire [SUM_WH-1:0]   in_conv;
  wire [SUM_WH-1:0]   value_conv;
  wire [SUM_WH-1:0]   sum;
  wire [VAL_WH  :0]   shift;
  reg  [VAL_WH-1:0]   buff [0:2*L];
  
  assign in_conv = {{(SUM_INT-IN_INT){in[IN_WH-1]}}, in, {(SUM_FR-IN_FR){1'b0}}};
  assign value_conv = {{(SUM_INT-VAL_INT){curr_value[VAL_WH-1]}}, curr_value, {(SUM_FR-VAL_FR){1'b0}}};

  assign sum = $signed(in_conv) - $signed(value_conv);
  assign shift = ($signed(sum[SUM_WH-1-:SUM_INT+VAL_FR]) >>> (BETA_SHIFT-1)) + 1;
  assign next_value = $signed(shift[VAL_WH:1]) + $signed(curr_value);

  integer i;

  //just previous rxx taps, cycled update for each
  //like    <-- [ rxx1(n-1) rxx2(n-1) ... rxx15(n-1) ] <-- rxx1(n)
  //        <-- [ rxx2(n-1) rxx3(n-1) ... rxx1(n) ]    <-- rxx2(n)
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for(i = 0; i < 2*L+1; i = i + 1) begin
        buff[i] <= {VAL_WH{1'b0}};
      end
    end else if (en) begin
      for(i = 0; i < 2*L; i = i + 1) begin
        buff[i] <= buff[i+1];
      end
      buff[2*L] <= next_value;
    end
  end

  assign curr_value = buff[0];
  assign out = curr_value;
  
endmodule