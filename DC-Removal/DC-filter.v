module DC_filter(
	input  wire        clk, 
	input  wire        rst, 
	input  wire [15:0] in, 
	output wire [15:0] out
);

  reg [35:0] sum_prev, 
  reg [35:0] in_conv, 
  reg [35:0] sum, mult_conv,
  reg [35:0] res;
  reg [15:0] alpha = 16'd31130;
  reg [15:0] sum_prev_conv;
  reg [51:0] mult;

	//previous sum storage
  always @(posedge clk) begin
    if (rst)
      sum_prev <= 36'b0;
    else
      sum_prev <= sum; //36.30
  end
	//first sum
  always @(*) begin
    in_conv = { in[15], in[15], in[15], in[15], in[15], in, 15'b0}; //36.30
    mult_conv = mult[50 -: 36]; //36.30
    sum = $signed(in_conv) + $signed(mult_conv); //36.30
  end

	//multiplication by alpha
  always @(*) begin
    mult =  $signed(alpha) * $signed(sum_prev);//52.45
  end
	//second sum
  always @(*) begin
    res = $signed(sum) - $signed(sum_prev); //36.30
    res = $signed(res) >>> 15; //36.15
  end

  assign out = res[15:0];  //16.15
	
endmodule
