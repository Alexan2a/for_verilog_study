module exp_smoothing_filter #(
  parameter L = 7,
  parameter IN_SIZE = 17,
  parameter VAL_SIZE = 16,
  parameter BETA_SHIFT = 4
)(
  input  wire clk,
  input  wire nrst,
  input  wire en,
  input  wire [IN_SIZE-1:0] in,
  output wire [VAL_SIZE-1:0] out
);

//////////////////////////////////////////////////////////
//                                                      //
//   next_value = curr_value + beta*(in - curr_value)   //
//                                                      //
//////////////////////////////////////////////////////////


  localparam SUM_SIZE = (IN_SIZE > VAL_SIZE) ? IN_SIZE+1 : VAL_SIZE+1;

  wire [VAL_SIZE-1:0]   curr_value;
  wire [VAL_SIZE-1:0]   next_value;
  wire [SUM_SIZE-2:0]   in_conv;
  wire [SUM_SIZE-2:0]   value_conv;
  wire [SUM_SIZE-1:0]   sum;
  wire [VAL_SIZE:0]     pre_shift;
  wire [VAL_SIZE-1:0]   shift;
  
  //not well parametrized, be carefull
  assign in_conv = in;
  assign value_conv = {{(IN_SIZE-VAL_SIZE){curr_value[VAL_SIZE-1]}}, curr_value};

  assign sum = $signed(in_conv) - $signed(value_conv);
  assign pre_shift = ($signed(sum) >>> (BETA_SHIFT-1)) + 1;
  assign shift = $signed(pre_shift) >>> 1;
  assign next_value = $signed(shift) + $signed(curr_value);

  reg [VAL_SIZE-1:0] buff [0:2*L];
  integer i;

  //just previous rxx taps, cycled update for each
  //like    <-- [ rxx1(n-1) rxx2(n-1) ... rxx15(n-1) ] <-- rxx1(n)
  //        <-- [ rxx2(n-1) rxx3(n-1) ... rxx1(n) ]   <-- rxx2(n)
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for(i = 0; i < 2*L+1; i = i + 1) begin
        buff[i] <= 0;
      end
    end else if (en) begin
      for(i = 0; i < 2*L; i = i + 1) begin
        buff[i] <= buff[i+1];
      end
      buff[2*L] <= next_value;
    end
  end

  assign curr_value = buff[0];
  assign out = buff[0];
  
endmodule